from fastapi import APIRouter
from app.config import settings
from app.models.schemas import SettingsResponse, SettingsUpdateRequest

router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("", response_model=SettingsResponse)
async def get_settings():
    """获取当前设置"""
    return SettingsResponse(
        model=settings.deepseek_model,
        base_url=settings.deepseek_base_url,
    )


@router.put("")
async def update_settings(req: SettingsUpdateRequest):
    """更新设置（模型选择）"""
    if req.model:
        settings.deepseek_model = req.model
    return {
        "status": "ok",
        "model": settings.deepseek_model,
    }
