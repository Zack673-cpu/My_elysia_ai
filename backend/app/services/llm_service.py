import re
from typing import AsyncGenerator, Optional
from openai import AsyncOpenAI
from app.config import settings
from app.models.schemas import Message, MessageRole


SEARCH_PATTERN = re.compile(r"\[SEARCH:\s*(.+?)\]", re.IGNORECASE)
MAX_CONTEXT_MESSAGES = 30  # 滑动窗口大小


class LLMService:
    """DeepSeek LLM 调用封装（通过 OpenAI SDK 兼容接口）"""

    def __init__(self):
        self.client = AsyncOpenAI(
            api_key=settings.deepseek_api_key,
            base_url=settings.deepseek_base_url,
        )
        self.default_model = settings.deepseek_model

    def _build_messages(
        self,
        system_prompt: str,
        history: list[Message],
        user_message: str,
        search_context: Optional[str] = None,
    ) -> list[dict]:
        """构建发送给 LLM 的消息列表"""
        messages = [{"role": "system", "content": system_prompt}]

        # 滑动窗口：保留最近 N 条消息
        recent = history[-MAX_CONTEXT_MESSAGES:] if len(history) > MAX_CONTEXT_MESSAGES else history
        for msg in recent:
            role = msg.role.value
            if role == "system_context":
                messages.append({"role": "system", "content": msg.content})
            else:
                messages.append({"role": role, "content": msg.content})

        # 添加搜索上下文
        if search_context:
            messages.append({
                "role": "system",
                "content": f"以下是从互联网搜索到的参考资料，请在回答中适当引用：\n{search_context}",
            })

        messages.append({"role": "user", "content": user_message})
        return messages

    async def chat(
        self,
        system_prompt: str,
        history: list[Message],
        user_message: str,
        model: Optional[str] = None,
        search_context: Optional[str] = None,
    ) -> tuple[str, int]:
        """非流式对话，返回 (回复内容, token 用量)"""
        messages = self._build_messages(system_prompt, history, user_message, search_context)
        response = await self.client.chat.completions.create(
            model=model or self.default_model,
            messages=messages,
            temperature=0.8,
            max_tokens=2048,
        )
        content = response.choices[0].message.content or ""
        tokens = response.usage.total_tokens if response.usage else 0
        return content, tokens

    async def chat_stream(
        self,
        system_prompt: str,
        history: list[Message],
        user_message: str,
        model: Optional[str] = None,
        search_context: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        """流式对话，逐块 yield 内容"""
        messages = self._build_messages(system_prompt, history, user_message, search_context)
        stream = await self.client.chat.completions.create(
            model=model or self.default_model,
            messages=messages,
            temperature=0.8,
            max_tokens=2048,
            stream=True,
        )
        async for chunk in stream:
            if chunk.choices and chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    @staticmethod
    def extract_search_queries(response: str) -> list[str]:
        """从 LLM 回复中提取搜索标记 [SEARCH: 关键词]"""
        return SEARCH_PATTERN.findall(response)

    @staticmethod
    def clean_search_markers(text: str) -> str:
        """移除回复中的搜索标记"""
        return SEARCH_PATTERN.sub("", text).strip()
