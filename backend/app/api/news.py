from fastapi import APIRouter

from app.models.schemas import NewsItemOut
from app.services.news_service import news_service

router = APIRouter(prefix="/api/news", tags=["news"])


@router.get("", response_model=list[NewsItemOut])
async def list_news(limit: int = 30):
    """获取最近一周的新闻列表（按抓取时间倒序）"""
    return news_service.list_news(limit=limit)


@router.post("/refresh")
async def refresh_news():
    """按当前新闻范围立即重新抓取（忽略 1 小时防抖），返回新增条数"""
    added = await news_service.refresh_news(force=True)
    return {"status": "ok", "added": added}
