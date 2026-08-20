import json
import logging

from fastapi import APIRouter, HTTPException
from sse_starlette.sse import EventSourceResponse

from app.models.schemas import (
    ChatRequest,
    ChatResponse,
    Message,
    MessageMetadata,
    MessageRole,
)
from app.services.agent_service import AgentService
from app.services.conversation_service import ConversationService
from app.services.prompt_service import PromptService

logger = logging.getLogger("app.chat")

router = APIRouter(prefix="/api/chat", tags=["chat"])
agent_service = AgentService()
conv_service = ConversationService()


def _prepare_chat(conversation_id: str):
    """校验对话并返回 (conv, system_prompt, history, summary)"""
    conv = conv_service.get_conversation(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="对话不存在")

    system_prompt = PromptService.get_prompt()
    history = conv_service.get_history(conversation_id)
    return conv, system_prompt, history, conv.summary


async def _process_chat(conversation_id: str, user_message: str) -> dict:
    """处理聊天逻辑：智能体自主决定是否搜索，单轮内生成唯一回复"""
    conv, system_prompt, history, summary = _prepare_chat(conversation_id)

    # 先持久化用户消息（history 已在上方获取，不含本条，不会重复）
    conv_service.add_message(
        conversation_id=conversation_id,
        role=MessageRole.USER,
        content=user_message,
    )

    try:
        final_response, search_performed, tokens = await agent_service.chat(
            system_prompt=system_prompt,
            history=history,
            user_message=user_message,
            summary=summary,
        )
    except Exception as e:
        # 失败补偿：回滚刚写入的孤立用户消息，避免留下半写对话
        removed = conv_service.remove_orphan_user_message(conversation_id)
        logger.error(
            "[chat] conversation_id=%s LLM 调用失败，已%s孤立用户消息: %s",
            conversation_id,
            "回滚" if removed else "未能回滚",
            e,
            exc_info=True,
        )
        raise HTTPException(status_code=502, detail="AI 服务暂时不可用，请重试") from e

    logger.info(
        "[chat] conversation_id=%s 回复完成 search=%s tokens=%s",
        conversation_id,
        search_performed,
        tokens,
    )
    if search_performed:
        conv_service.increment_search_count(conversation_id)

    assistant_metadata = MessageMetadata(
        model_used=conv.model,
        search_performed=search_performed,
        tokens_used=tokens,
    )
    conv_service.add_message(
        conversation_id=conversation_id,
        role=MessageRole.ASSISTANT,
        content=final_response,
        metadata=assistant_metadata,
    )

    return {
        "conversation_id": conversation_id,
        "message": Message(
            role=MessageRole.ASSISTANT,
            content=final_response,
            metadata=assistant_metadata,
        ),
        "search_performed": search_performed,
        "search_results": None,
    }


@router.post("/send", response_model=ChatResponse)
async def send_message(req: ChatRequest):
    """发送消息并获取回复（非流式）"""
    result = await _process_chat(req.conversation_id, req.message)
    return ChatResponse(**result)


@router.post("/stream")
async def stream_message(req: ChatRequest):
    """发送消息并获取流式回复（SSE）"""
    conv, system_prompt, history, summary = _prepare_chat(req.conversation_id)

    # 先持久化用户消息（history 已在上方获取，不含本条）
    conv_service.add_message(
        conversation_id=req.conversation_id,
        role=MessageRole.USER,
        content=req.message,
    )

    async def event_generator():
        full_response = ""
        search_performed = False

        try:
            async for evt in agent_service.chat_stream(
                system_prompt=system_prompt,
                history=history,
                user_message=req.message,
                summary=summary,
            ):
                if "content" in evt:
                    full_response += evt["content"]
                    yield {"data": json.dumps({"content": evt["content"], "done": False}, ensure_ascii=False)}
                elif "search_performed" in evt:
                    search_performed = evt["search_performed"]
        except Exception as e:
            # 失败补偿：流中断且未产生任何回复时，回滚孤立用户消息
            removed = False
            if not full_response:
                removed = conv_service.remove_orphan_user_message(req.conversation_id)
            logger.error(
                "[chat-stream] conversation_id=%s 流式调用失败，已%s孤立用户消息: %s",
                req.conversation_id,
                "回滚" if removed else "未能回滚（已有部分回复）" if full_response else "未能回滚",
                e,
                exc_info=True,
            )
            yield {"data": json.dumps({"content": "", "done": True, "error": "AI 服务暂时不可用，请重试"}, ensure_ascii=False)}
            return

        if search_performed:
            conv_service.increment_search_count(req.conversation_id)

        # 保存 AI 回复
        conv_service.add_message(
            conversation_id=req.conversation_id,
            role=MessageRole.ASSISTANT,
            content=full_response,
            metadata=MessageMetadata(
                model_used=conv.model,
                search_performed=search_performed,
            ),
        )

        yield {"data": json.dumps({"content": "", "done": True, "search_performed": search_performed}, ensure_ascii=False)}

    return EventSourceResponse(event_generator())
