from fastapi import APIRouter, HTTPException
from app.models.schemas import Conversation, CreateConversationRequest
from app.services.compress_service import compress_service
from app.services.conversation_service import ConversationService

router = APIRouter(prefix="/api/conversations", tags=["conversations"])
conv_service = ConversationService()


@router.get("", response_model=list[Conversation])
async def list_conversations():
    """获取所有对话列表"""
    return conv_service.list_conversations()


@router.get("/{conversation_id}", response_model=Conversation)
async def get_conversation(conversation_id: str):
    """获取单个对话详情"""
    conv = conv_service.get_conversation(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="对话不存在")
    return conv


@router.post("", response_model=Conversation)
async def create_conversation(req: CreateConversationRequest):
    """创建新对话"""
    return conv_service.create_conversation(title=req.title)


@router.delete("/{conversation_id}")
async def delete_conversation(conversation_id: str):
    """删除对话"""
    success = conv_service.delete_conversation(conversation_id)
    if not success:
        raise HTTPException(status_code=404, detail="对话不存在")
    return {"status": "ok", "message": "对话已删除"}


@router.post("/{conversation_id}/compress")
async def compress_conversation(conversation_id: str):
    """压缩上下文：把较早的消息总结成摘要，原始消息不删"""
    try:
        return await compress_service.compress(conversation_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
