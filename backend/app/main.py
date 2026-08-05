from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    chat_router,
    conversations_router,
    daily_router,
    news_router,
    search_router,
    settings_router,
)
from app.config import APP_FULL_NAME
from app.db import create_db_and_tables
from app.services.migration_service import migrate_json_conversations
from app.services.news_service import news_service


@asynccontextmanager
async def lifespan(app: FastAPI):
    """启动时：建表 → 一次性迁移旧 JSON 对话 → 后台抓取新闻（不阻塞服务就绪）"""
    create_db_and_tables()
    migrate_json_conversations()

    import asyncio

    async def _fetch_news_background():
        try:
            await news_service.refresh_news()
        except Exception as e:
            print(f"[NewsService] 抓取失败（不影响服务）: {e}")

    task = asyncio.create_task(_fetch_news_background())

    yield

    task.cancel()


app = FastAPI(
    title=f"{APP_FULL_NAME} Backend",
    description="心理咨询 AI 后端服务 — Cryene",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS 中间件 — 允许 Flutter 前端跨域访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(chat_router)
app.include_router(conversations_router)
app.include_router(daily_router)
app.include_router(news_router)
app.include_router(search_router)
app.include_router(settings_router)


@app.get("/api/health")
async def health_check():
    """健康检查"""
    return {
        "status": "ok",
        "service": f"{APP_FULL_NAME} Backend",
        "version": "0.1.0",
    }
