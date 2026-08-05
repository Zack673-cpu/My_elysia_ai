from app.services.conversation_service import ConversationService
from app.services.llm_service import LLMService

KEEP_RECENT = 12  # 压缩后保留最近的消息条数

_COMPRESS_SYSTEM = """你是对话记录员。请把给出的历史对话压缩成一段简明摘要，要求：
1. 保留关键话题、用户的重要诉求与结论
2. 用第三人称叙述，不超过 300 字
3. 直接输出摘要正文，不要有多余说明"""


class CompressService:
    """上下文压缩：把较早的消息总结成摘要，减少发给模型的历史量。

    原始消息在数据库里一条不删（为训练留数据），压缩只影响 LLM 上下文。
    """

    def __init__(self):
        self._conv_service = ConversationService()
        self.llm = LLMService()

    async def compress(self, conversation_id: str) -> dict:
        conv = self._conv_service.get_conversation(conversation_id)
        if conv is None:
            raise ValueError("对话不存在")

        messages = [m for m in conv.messages if m.role.value != "system_context"]
        if len(messages) <= KEEP_RECENT:
            return {
                "compressed": False,
                "message": f"消息不超过 {KEEP_RECENT} 条，暂不需要压缩",
            }

        old_messages = messages[:-KEEP_RECENT]
        lines = []
        for m in old_messages:
            role = "用户" if m.role.value == "user" else "助手"
            lines.append(f"{role}: {m.content}")

        existing = conv.summary
        user_prompt = ""
        if existing:
            user_prompt += f"此前的摘要：\n{existing}\n\n"
        user_prompt += "新的历史对话：\n" + "\n".join(lines)

        summary = await self.llm.ask(_COMPRESS_SYSTEM, user_prompt)
        self._conv_service.set_summary(conversation_id, summary.strip())
        return {
            "compressed": True,
            "message": f"已压缩 {len(old_messages)} 条旧消息为摘要",
            "summary": summary.strip(),
        }


compress_service = CompressService()
