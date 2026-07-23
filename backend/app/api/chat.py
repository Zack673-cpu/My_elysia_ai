import json
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

router = APIRouter(prefix="/api/chat", tags=["chat"])
agent_service = AgentService()
conv_service = ConversationService()


def _prepare_chat(conversation_id: str):
    """校验对话并返回 (conv, system_prompt, history)"""
    conv = conv_service.get_conversation(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="对话不存在")

    system_prompt = PromptService.get_prompt(conv.stage)
    history = conv_service.get_history(conversation_id)
    return conv, system_prompt, history


async def _process_chat(conversation_id: str, user_message: str) -> dict:
    """处理聊天逻辑：智能体自主决定是否搜索，单轮内生成唯一回复"""
    conv, system_prompt, history = _prepare_chat(conversation_id)

    # 先持久化用户消息（history 已在上方获取，不含本条，不会重复）
    conv_service.add_message(
        conversation_id=conversation_id,
        role=MessageRole.USER,
        content=user_message,
    )

    final_response, search_performed, tokens = await agent_service.chat(
        system_prompt=system_prompt,
        history=history,
        user_message=user_message,
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
    conv, system_prompt, history = _prepare_chat(req.conversation_id)

    # 先持久化用户消息（history 已在上方获取，不含本条）
    conv_service.add_message(
        conversation_id=req.conversation_id,
        role=MessageRole.USER,
        content=req.message,
    )

    async def event_generator():
        full_response = ""
        search_performed = False

        async for evt in agent_service.chat_stream(
            system_prompt=system_prompt,
            history=history,
            user_message=req.message,
        ):
            if "content" in evt:
                full_response += evt["content"]
                yield {"data": json.dumps({"content": evt["content"], "done": False}, ensure_ascii=False)}
            elif "search_performed" in evt:
                search_performed = evt["search_performed"]

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
