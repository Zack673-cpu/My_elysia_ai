from datetime import datetime
from typing import Optional
from app.config import settings
from app.models.schemas import (
    Conversation,
    ConversationMetadata,
    Message,
    MessageMetadata,
    MessageRole,
)
from app.storage.json_store import JsonStore


class ConversationService:
    """对话增删改查业务逻辑"""

    def __init__(self):
        self.store = JsonStore(settings.conversations_dir)

    def create_conversation(self, title: Optional[str] = None) -> Conversation:
        """创建新对话"""
        conv = Conversation(
            title=title or "新对话",
            model=settings.deepseek_model,
        )
        self._save(conv)
        return conv

    def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        """获取对话，不存在返回 None"""
        data = self.store.read(conversation_id)
        if data is None:
            return None
        return Conversation(**data)

    def list_conversations(self) -> list[Conversation]:
        """获取所有对话，按更新时间倒序"""
        conversations = []
        for key in self.store.list_keys():
            data = self.store.read(key)
            if data:
                conversations.append(Conversation(**data))
        conversations.sort(key=lambda c: c.updated_at, reverse=True)
        return conversations

    def delete_conversation(self, conversation_id: str) -> bool:
        return self.store.delete(conversation_id)

    def add_message(
        self,
        conversation_id: str,
        role: MessageRole,
        content: str,
        metadata: Optional[MessageMetadata] = None,
    ) -> Conversation:
        """向对话添加消息"""
        conv = self.get_conversation(conversation_id)
        if conv is None:
            raise ValueError(f"对话不存在: {conversation_id}")

        msg = Message(
            role=role,
            content=content,
            metadata=metadata or MessageMetadata(),
        )
        conv.messages.append(msg)
        conv.updated_at = datetime.utcnow()
        conv.metadata.message_count = len([m for m in conv.messages if m.role in (MessageRole.USER, MessageRole.ASSISTANT)])

        # 自动从用户首条消息提取标题
        if conv.title == "新对话" and role == MessageRole.USER:
            conv.title = content[:30] + ("..." if len(content) > 30 else "")

        self._save(conv)
        return conv

    def get_history(self, conversation_id: str) -> list[Message]:
        """获取对话历史消息（用于 LLM 上下文）"""
        conv = self.get_conversation(conversation_id)
        if conv is None:
            return []
        return conv.messages

    def increment_search_count(self, conversation_id: str) -> None:
        conv = self.get_conversation(conversation_id)
        if conv:
            conv.metadata.search_count += 1
            self._save(conv)

    def _save(self, conv: Conversation) -> None:
        self.store.write(conv.conversation_id, conv.model_dump())
