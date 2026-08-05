from fastapi import APIRouter, HTTPException

from app.models.schemas import DailyAnswerRequest, DailyResolveRequest, DailyState
from app.services.quiz_service import quiz_service

router = APIRouter(prefix="/api/daily", tags=["daily"])


@router.get("/today", response_model=DailyState)
async def get_today(force_new: bool = False):
    """获取今日每日问答题目（优先复习到期卡，无到期卡才出新题）"""
    try:
        return await quiz_service.get_today(force_new=force_new)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/answer", response_model=DailyState)
async def submit_answer(req: DailyAnswerRequest):
    """提交答案，AI 评估反馈"""
    if not req.answer.strip():
        raise HTTPException(status_code=400, detail="答案不能为空")
    try:
        return await quiz_service.answer(req.answer.strip())
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/resolve", response_model=DailyState)
async def resolve(req: DailyResolveRequest):
    """提交用户对决策弹窗按钮的选择"""
    try:
        return quiz_service.resolve(req.decision)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
