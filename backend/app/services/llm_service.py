import json
import re
from langchain_openai import ChatOpenAI
from app.config import settings


class LLMService:
    """轻量 LLM 调用封装，用于出题、评估、新闻概括、上下文压缩等独立任务。

    与聊天智能体（AgentService）分离：这些任务不需要工具调用，
    且需要严格控制传给模型的内容量。
    """

    def __init__(self):
        self.llm = ChatOpenAI(
            api_key=settings.deepseek_api_key,
            base_url=settings.deepseek_base_url,
            model=settings.deepseek_model,
            temperature=0.7,
            max_tokens=2048,
        )

    async def ask(self, system: str, user: str) -> str:
        result = await self.llm.ainvoke([
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ])
        content = result.content
        return content if isinstance(content, str) else str(content)

    async def ask_json(self, system: str, user: str) -> dict:
        """要求模型输出 JSON 并解析，解析失败返回空字典"""
        text = await self.ask(system, user)
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if not match:
            return {}
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            return {}
