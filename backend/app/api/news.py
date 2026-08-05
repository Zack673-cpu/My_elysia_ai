from fastapi import APIRouter

from app.models.schemas import NewsItemOut
from app.services.news_service import news_service

router = APIRouter(prefix="/api/news", tags=["news"])


@router.get("", response_model=list[NewsItemOut])
async def list_news(limit: int = 30):
    """获取最近一周的新闻列表（按抓取时间倒序）"""
    return news_service.list_news(limit=limit)
