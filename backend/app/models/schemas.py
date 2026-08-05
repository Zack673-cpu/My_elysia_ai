from datetime import datetime, UTC
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field
import uuid


class MessageRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM_CONTEXT = "system_context"


class MessageMetadata(BaseModel):
    model_used: Optional[str] = None
    search_performed: bool = False
    search_query: Optional[str] = None
    search_results: Optional[list[dict]] = None
    tokens_used: Optional[int] = None


class Message(BaseModel):
    role: MessageRole
    content: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))
    metadata: MessageMetadata = Field(default_factory=MessageMetadata)


class ConversationMetadata(BaseModel):
    message_count: int = 0
    search_count: int = 0
    topics: list[str] = Field(default_factory=list)
    mood_trajectory: list[str] = Field(default_factory=list)


class Conversation(BaseModel):
    conversation_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str = "新对话"
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    model: str = "deepseek-chat"
    summary: Optional[str] = None  # 上下文压缩摘要
    metadata: ConversationMetadata = Field(default_factory=ConversationMetadata)
    messages: list[Message] = Field(default_factory=list)


class ChatRequest(BaseModel):
    conversation_id: str
    message: str
    stream: bool = False


class ChatResponse(BaseModel):
    conversation_id: str
    message: Message
    search_performed: bool = False
    search_results: Optional[list[dict]] = None


class StreamChunk(BaseModel):
    content: str = ""
    done: bool = False
    search_performed: bool = False
    search_results: Optional[list[dict]] = None


class CreateConversationRequest(BaseModel):
    title: Optional[str] = None


class SettingsResponse(BaseModel):
    model: str
    base_url: str
    quiz_topic: str = "前后端全栈"
    news_scope: str = "AI"


class SettingsUpdateRequest(BaseModel):
    model: Optional[str] = None
    quiz_topic: Optional[str] = None
    news_scope: Optional[str] = None


class DailyAnswerRequest(BaseModel):
    answer: str


class DailyResolveRequest(BaseModel):
    decision: str  # join_review/skip、decrease/increase、reset/master


class DailyState(BaseModel):
    date: str
    is_review: bool
    card_id: int
    question: str
    topic: str = ""
    level: int = 1
    answered: bool = False
    resolved: bool = False
    user_answer: Optional[str] = None
    feedback: Optional[str] = None
    suggestion: Optional[str] = None
    grade: Optional[str] = None  # correct / wrong / partial
    is_mastery_exam: bool = False
    # 需要用户弹窗决策的类型：new_question / review_partial / mastery_exam / None
    decision: Optional[str] = None
    due_count: int = 0


class NewsItemOut(BaseModel):
    id: int
    summary: str
    url: str
    source_title: str = ""
    fetched_at: datetime


class SearchRequest(BaseModel):
    query: str
    max_results: int = 5


class SearchResponse(BaseModel):
    query: str
    results: list[dict]
