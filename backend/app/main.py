from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import chat_router, conversations_router, search_router, settings_router
from app.config import APP_FULL_NAME

app = FastAPI(
    title=f"{APP_FULL_NAME} Backend",
    description="心理咨询 AI 后端服务 — Cryene",
    version="0.1.0",
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
