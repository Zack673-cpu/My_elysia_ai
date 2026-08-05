from fastapi import APIRouter
from app.config import settings
from app.models.schemas import SettingsResponse, SettingsUpdateRequest
from app.services.settings_service import settings_service

router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("", response_model=SettingsResponse)
async def get_settings():
    """获取当前设置（模型 + 每日问答领域 + 新闻范围）"""
    return SettingsResponse(
        model=settings.deepseek_model,
        base_url=settings.deepseek_base_url,
        quiz_topic=settings_service.get_quiz_topic(),
        news_scope=settings_service.get_news_scope(),
    )


@router.put("")
async def update_settings(req: SettingsUpdateRequest):
    """更新设置（模型选择、问答领域、新闻范围），问答与新闻设置持久化到数据库"""
    if req.model:
        settings.deepseek_model = req.model
    if req.quiz_topic is not None and req.quiz_topic.strip():
        settings_service.set("quiz_topic", req.quiz_topic.strip())
    if req.news_scope is not None and req.news_scope.strip():
        settings_service.set("news_scope", req.news_scope.strip())
    return {
        "status": "ok",
        "model": settings.deepseek_model,
        "quiz_topic": settings_service.get_quiz_topic(),
        "news_scope": settings_service.get_news_scope(),
    }
