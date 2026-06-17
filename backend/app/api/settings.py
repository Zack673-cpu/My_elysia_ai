from fastapi import APIRouter
from app.config import settings
from app.models.schemas import SettingsResponse, SettingsUpdateRequest
from app.services.prompt_service import PromptService

router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("", response_model=SettingsResponse)
async def get_settings():
    """获取当前设置"""
    return SettingsResponse(
        stage=settings.stage,
        model=settings.deepseek_model,
        base_url=settings.deepseek_base_url,
    )


@router.put("")
async def update_settings(req: SettingsUpdateRequest):
    """更新设置（阶段切换、模型选择）"""
    if req.stage:
        if req.stage not in PromptService.list_stages():
            return {"error": f"无效的阶段: {req.stage}"}
        settings.stage = req.stage
    if req.model:
        settings.deepseek_model = req.model
    return {
        "status": "ok",
        "stage": settings.stage,
        "model": settings.deepseek_model,
    }
