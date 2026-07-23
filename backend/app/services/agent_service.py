from typing import AsyncGenerator

from langchain_core.messages import (
    AIMessage,
    AIMessageChunk,
    HumanMessage,
    SystemMessage,
    ToolMessage,
)
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent

from app.config import settings
from app.models.schemas import Message, MessageRole
from app.services.search_service import SearchService


MAX_CONTEXT_MESSAGES = 30  # 滑动窗口大小

_search_service = SearchService()


@tool
def web_search(query: str) -> str:
    """搜索互联网获取最新的心理学研究、循证实践、特定疗法的具体操作步骤，或验证专业概念。

    在以下情况调用此工具：需要查阅最新研究进展、推荐具体练习/技术前需确认准确性、
    用户提到你不确定的心理学术语或症状、需要对比多种理论框架。

    Args:
        query: 搜索关键词，可用中文，应简洁精准。

    Returns:
        格式化的搜索结果文本，包含标题、摘要和来源链接。
    """
    results = _search_service.search(query)
    return SearchService.format_results_for_context(results)


class AgentService:
    """基于 LangGraph 的工具调用智能体，封装搜索工具。

    相比旧的 [SEARCH:] 两次调用方案，智能体在单轮内自主决定是否搜索：
    - 需要搜索时先调用 web_search 工具（不产生文本标记），再基于结果生成唯一回复；
    - 不需要时直接回复。彻底避免搜索标记外泄与"未搜索+已搜索"两段回复拼接。
    """

    def __init__(self):
        self.llm = ChatOpenAI(
            api_key=settings.deepseek_api_key,
            base_url=settings.deepseek_base_url,
            model=settings.deepseek_model,
            temperature=0.8,
            max_tokens=2048,
        )
        self.tools = [web_search]

    def _build_agent(self, system_prompt: str):
        """根据系统提示词构建 react 智能体"""
        return create_react_agent(self.llm, self.tools, prompt=system_prompt)

    @staticmethod
    def _build_history_messages(history: list[Message], user_message: str) -> list:
        """将对话历史与当前用户消息转换为 LangChain 消息列表（系统提示词由智能体注入）"""
        recent = history[-MAX_CONTEXT_MESSAGES:] if len(history) > MAX_CONTEXT_MESSAGES else history
        messages = []
        for msg in recent:
            if msg.role == MessageRole.USER:
                messages.append(HumanMessage(content=msg.content))
            elif msg.role == MessageRole.ASSISTANT:
                messages.append(AIMessage(content=msg.content))
            elif msg.role == MessageRole.SYSTEM_CONTEXT:
                # 兼容历史遗留的搜索上下文消息
                messages.append(SystemMessage(content=msg.content))
        messages.append(HumanMessage(content=user_message))
        return messages

    async def chat(
        self,
        system_prompt: str,
        history: list[Message],
        user_message: str,
    ) -> tuple[str, bool, int]:
        """非流式对话，返回 (回复内容, 是否执行了搜索, token 用量)"""
        agent = self._build_agent(system_prompt)
        messages = self._build_history_messages(history, user_message)

        result = await agent.ainvoke({"messages": messages})
        out_messages = result["messages"]

        search_performed = any(isinstance(m, ToolMessage) for m in out_messages)
        tokens = 0
        for m in out_messages:
            usage = getattr(m, "usage_metadata", None)
            if usage:
                tokens += usage.get("total_tokens", 0)

        final_message = out_messages[-1]
        content = final_message.content if isinstance(final_message.content, str) else str(final_message.content)
        return content, search_performed, tokens

    async def chat_stream(
        self,
        system_prompt: str,
        history: list[Message],
        user_message: str,
    ) -> AsyncGenerator[dict, None]:
        """流式对话，逐块 yield {"content": str} 文本增量，结束时 yield {"search_performed": bool}。

        仅转发智能体最终回复的文本增量；工具调用（搜索）过程不产生可见文本，
        因此不会出现搜索标记外泄或两段回复拼接。
        """
        agent = self._build_agent(system_prompt)
        messages = self._build_history_messages(history, user_message)

        search_performed = False
        async for chunk, _metadata in agent.astream(
            {"messages": messages}, stream_mode="messages"
        ):
            if isinstance(chunk, ToolMessage):
                search_performed = True
                continue
            if isinstance(chunk, AIMessageChunk):
                # 工具调用增量不含正文文本，天然被跳过
                if chunk.tool_call_chunks:
                    search_performed = True
                    continue
                if chunk.content:
                    text = chunk.content if isinstance(chunk.content, str) else str(chunk.content)
                    if text:
                        yield {"content": text}

        yield {"search_performed": search_performed}
