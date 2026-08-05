from datetime import datetime, UTC
from typing import Optional
from sqlmodel import Session, select
from app.config import settings
from app.db import engine
from app.models.db_models import ConversationRecord, MessageRecord
from app.models.schemas import (
    Conversation,
    ConversationMetadata,
    Message,
    MessageMetadata,
    MessageRole,
)


class ConversationService:
    """对话增删改查业务逻辑（SQLite 版，接口与旧 JSON 版保持一致）"""

    # ---- 记录 <-> 模型转换 ----

    @staticmethod
    def _conv_to_schema(rec: ConversationRecord, messages: list[MessageRecord]) -> Conversation:
        return Conversation(
            conversation_id=rec.conversation_id,
            title=rec.title,
            created_at=rec.created_at,
            updated_at=rec.updated_at,
            model=rec.model,
            summary=rec.summary,
            metadata=ConversationMetadata(**(rec.metadata_json or {})),
            messages=[
                Message(
                    role=MessageRole(m.role),
                    content=m.content,
                    timestamp=m.timestamp,
                    metadata=MessageMetadata(**(m.metadata_json or {})),
                )
                for m in messages
            ],
        )

    def _get_records(self, session: Session, conversation_id: str):
        rec = session.get(ConversationRecord, conversation_id)
        if rec is None:
            return None, []
        messages = session.exec(
            select(MessageRecord)
            .where(MessageRecord.conversation_id == conversation_id)
            .order_by(MessageRecord.timestamp, MessageRecord.id)
        ).all()
        return rec, messages

    # ---- 对外接口 ----

    def create_conversation(self, title: Optional[str] = None) -> Conversation:
        """创建新对话"""
        rec = ConversationRecord(
            title=title or "新对话",
            model=settings.deepseek_model,
        )
        with Session(engine) as session:
            session.add(rec)
            session.commit()
            session.refresh(rec)
        return self._conv_to_schema(rec, [])

    def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        """获取对话，不存在返回 None"""
        with Session(engine) as session:
            rec, messages = self._get_records(session, conversation_id)
            if rec is None:
                return None
            return self._conv_to_schema(rec, messages)

    def get_summary(self, conversation_id: str) -> Optional[str]:
        """获取对话的上下文压缩摘要"""
        with Session(engine) as session:
            rec = session.get(ConversationRecord, conversation_id)
            return rec.summary if rec else None

    def set_summary(self, conversation_id: str, summary: str) -> None:
        """保存上下文压缩摘要"""
        with Session(engine) as session:
            rec = session.get(ConversationRecord, conversation_id)
            if rec:
                rec.summary = summary
                session.add(rec)
                session.commit()

    def list_conversations(self) -> list[Conversation]:
        """获取所有对话，按更新时间倒序（含消息，兼容前端现有用法）"""
        with Session(engine) as session:
            recs = session.exec(
                select(ConversationRecord).order_by(ConversationRecord.updated_at.desc())
            ).all()
            result = []
            for rec in recs:
                messages = session.exec(
                    select(MessageRecord)
                    .where(MessageRecord.conversation_id == rec.conversation_id)
                    .order_by(MessageRecord.timestamp, MessageRecord.id)
                ).all()
                result.append(self._conv_to_schema(rec, messages))
        return result

    def delete_conversation(self, conversation_id: str) -> bool:
        with Session(engine) as session:
            rec = session.get(ConversationRecord, conversation_id)
            if rec is None:
                return False
            messages = session.exec(
                select(MessageRecord).where(
                    MessageRecord.conversation_id == conversation_id
                )
            ).all()
            for m in messages:
                session.delete(m)
            session.delete(rec)
            session.commit()
            return True

    def add_message(
        self,
        conversation_id: str,
        role: MessageRole,
        content: str,
        metadata: Optional[MessageMetadata] = None,
    ) -> Conversation:
        """向对话添加消息"""
        with Session(engine) as session:
            rec, messages = self._get_records(session, conversation_id)
            if rec is None:
                raise ValueError(f"对话不存在: {conversation_id}")

            msg = MessageRecord(
                conversation_id=conversation_id,
                role=role.value,
                content=content,
                metadata_json=(metadata or MessageMetadata()).model_dump(),
            )
            session.add(msg)

            rec.updated_at = datetime.now(UTC)
            new_count = len([m for m in messages if m.role in ("user", "assistant")]) + (
                1 if role in (MessageRole.USER, MessageRole.ASSISTANT) else 0
            )
            meta = ConversationMetadata(**(rec.metadata_json or {}))
            meta.message_count = new_count
            rec.metadata_json = meta.model_dump()

            # 自动从用户首条消息提取标题
            if rec.title == "新对话" and role == MessageRole.USER:
                rec.title = content[:30] + ("..." if len(content) > 30 else "")

            session.add(rec)
            session.commit()

            messages.append(msg)
            return self._conv_to_schema(rec, messages)

    def get_history(self, conversation_id: str) -> list[Message]:
        """获取对话历史消息（用于 LLM 上下文）"""
        conv = self.get_conversation(conversation_id)
        if conv is None:
            return []
        return conv.messages

    def increment_search_count(self, conversation_id: str) -> None:
        with Session(engine) as session:
            rec = session.get(ConversationRecord, conversation_id)
            if rec:
                meta = ConversationMetadata(**(rec.metadata_json or {}))
                meta.search_count += 1
                rec.metadata_json = meta.model_dump()
                session.add(rec)
                session.commit()
