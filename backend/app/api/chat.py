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
from app.services.llm_service import LLMService
from app.services.search_service import SearchService
from app.services.conversation_service import ConversationService
from app.services.prompt_service import PromptService

router = APIRouter(prefix="/api/chat", tags=["chat"])
llm_service = LLMService()
search_service = SearchService()
conv_service = ConversationService()


def _prepare_chat(conversation_id: str):
    """校验对话并返回 (conv, system_prompt, history)"""
    conv = conv_service.get_conversation(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="对话不存在")

    system_prompt = PromptService.get_prompt(conv.stage)
    history = conv_service.get_history(conversation_id)
    return conv, system_prompt, history


def _perform_search(conversation_id: str, search_queries: list) -> tuple:
    """执行搜索并保存搜索上下文，返回 (search_results, search_context)"""
    search_results = []
    for query in search_queries:
        search_results.extend(search_service.search(query))
        conv_service.increment_search_count(conversation_id)

    search_context = search_service.format_results_for_context(search_results)
    conv_service.add_message(
        conversation_id=conversation_id,
        role=MessageRole.SYSTEM_CONTEXT,
        content=f"[搜索结果] 查询: {search_queries}\n{search_context}",
        metadata=MessageMetadata(
            search_performed=True,
            search_query=", ".join(search_queries),
            search_results=search_results,
        ),
    )
    return search_results, search_context


async def _process_chat(conversation_id: str, user_message: str) -> dict:
    """处理聊天逻辑：LLM 回复 → 搜索检测 → 搜索 → 二次 LLM → 保存"""
    conv, system_prompt, history = _prepare_chat(conversation_id)

    # 第一次 LLM 调用
    raw_response, tokens = await llm_service.chat(
        system_prompt=system_prompt,
        history=history,
        user_message=user_message,
    )

    # 保存用户消息
    conv_service.add_message(
        conversation_id=conversation_id,
        role=MessageRole.USER,
        content=user_message,
    )

    # 检查是否需要搜索，如有则搜索并进行第二次 LLM 调用
    search_queries = llm_service.extract_search_queries(raw_response)
    search_results = None
    if search_queries:
        search_results, search_context = _perform_search(conversation_id, search_queries)
        final_response, extra_tokens = await llm_service.chat(
            system_prompt=system_prompt,
            history=history,
            user_message=user_message,
            search_context=search_context,
        )
        tokens += extra_tokens
    else:
        final_response = raw_response

    # 保存 AI 回复
    assistant_metadata = MessageMetadata(
        model_used=conv.model,
        search_performed=bool(search_queries),
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
        "search_performed": bool(search_queries),
        "search_results": search_results if search_results else None,
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

    # 保存用户消息
    conv_service.add_message(
        conversation_id=req.conversation_id,
        role=MessageRole.USER,
        content=req.message,
    )

    async def event_generator():
        full_response = ""

        async for chunk in llm_service.chat_stream(
            system_prompt=system_prompt,
            history=history,
            user_message=req.message,
        ):
            full_response += chunk
            yield {"data": json.dumps({"content": chunk, "done": False}, ensure_ascii=False)}

        # 检查搜索，如有则搜索并进行第二次流式调用
        search_queries = llm_service.extract_search_queries(full_response)
        if search_queries:
            _, search_context = _perform_search(req.conversation_id, search_queries)

            full_response = ""
            async for chunk in llm_service.chat_stream(
                system_prompt=system_prompt,
                history=history,
                user_message=req.message,
                search_context=search_context,
            ):
                full_response += chunk
                yield {"data": json.dumps({"content": chunk, "done": False}, ensure_ascii=False)}

        # 保存 AI 回复
        conv_service.add_message(
            conversation_id=req.conversation_id,
            role=MessageRole.ASSISTANT,
            content=llm_service.clean_search_markers(full_response),
            metadata=MessageMetadata(
                model_used=conv.model,
                search_performed=bool(search_queries),
            ),
        )

        yield {"data": json.dumps({"content": "", "done": True}, ensure_ascii=False)}

    return EventSourceResponse(event_generator())
