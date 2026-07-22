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
    stage: str = "demugo"
    model: str = "deepseek-chat"
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
    stage: str
    model: str
    base_url: str


class SettingsUpdateRequest(BaseModel):
    stage: Optional[str] = None
    model: Optional[str] = None


class SearchRequest(BaseModel):
    query: str
    max_results: int = 5


class SearchResponse(BaseModel):
    query: str
    results: list[dict]
