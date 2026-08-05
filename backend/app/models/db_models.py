import uuid
from datetime import datetime, UTC
from typing import Optional
from sqlalchemy import JSON
from sqlmodel import SQLModel, Field


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(UTC)


class ConversationRecord(SQLModel, table=True):
    """对话主表"""

    __tablename__ = "conversations"

    conversation_id: str = Field(default_factory=_uuid, primary_key=True)
    title: str = "新对话"
    model: str = "deepseek-chat"
    created_at: datetime = Field(default_factory=_now)
    updated_at: datetime = Field(default_factory=_now)
    summary: Optional[str] = None  # 上下文压缩摘要
    metadata_json: dict = Field(default_factory=dict, sa_type=JSON)  # JSON 列


class MessageRecord(SQLModel, table=True):
    """聊天消息表，永久保留（为将来训练留数据）"""

    __tablename__ = "messages"

    id: Optional[int] = Field(default=None, primary_key=True)
    conversation_id: str = Field(index=True)
    role: str  # user / assistant / system_context
    content: str
    timestamp: datetime = Field(default_factory=_now)
    metadata_json: dict = Field(default_factory=dict, sa_type=JSON)


class QuizCard(SQLModel, table=True):
    """每日问答题目卡片（艾宾浩斯间隔重复）

    status: pending=新题待用户决定是否入复习 / learning=复习中 / mastered=已掌握不再复习
    next_review_date 只存自然日（yyyy-mm-dd），不存时刻
    """

    __tablename__ = "quiz_cards"

    id: Optional[int] = Field(default=None, primary_key=True)
    topic: str = ""
    question: str
    reference_answer: str = ""
    level: int = 1
    next_review_date: Optional[str] = None
    review_count: int = 0
    correct_count: int = 0
    status: str = "learning"
    created_at: datetime = Field(default_factory=_now)


class QuizRecord(SQLModel, table=True):
    """每日问答作答记录，每次作答全记录"""

    __tablename__ = "quiz_records"

    id: Optional[int] = Field(default=None, primary_key=True)
    card_id: int = Field(index=True)
    is_review: bool = False
    asked_date: str = Field(default="", index=True)  # yyyy-mm-dd
    asked_at: datetime = Field(default_factory=_now)
    user_answer: Optional[str] = None
    feedback: Optional[str] = None
    suggestion: Optional[str] = None
    grade: Optional[str] = None  # correct / wrong / partial
    resolved: bool = False  # 用户决策（弹窗按钮）是否已完成


class NewsItem(SQLModel, table=True):
    """每日新闻，只保留最近一周"""

    __tablename__ = "news_items"

    id: Optional[int] = Field(default=None, primary_key=True)
    summary: str  # 一句话简体中文概括
    url: str = Field(index=True)
    source_title: str = ""
    published_at: Optional[datetime] = None
    fetched_at: datetime = Field(default_factory=_now, index=True)


class AppSetting(SQLModel, table=True):
    """应用设置 key-value 持久化"""

    __tablename__ = "app_settings"

    key: str = Field(primary_key=True)
    value: str = ""
