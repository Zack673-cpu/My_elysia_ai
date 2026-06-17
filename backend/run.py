"""Demugo AI Backend 启动脚本"""
import uvicorn
from app.config import settings, APP_FULL_NAME


def main():
    print(f"🧠 {APP_FULL_NAME} Backend - Stage: {settings.stage.upper()}")
    print(f"🌐 Server: http://{settings.host}:{settings.port}")
    print(f"📁 Data directory: {settings.data_dir}")
    print(f"🔑 DeepSeek API: {'✅ Configured' if settings.deepseek_api_key else '❌ Not set'}")
    print("-" * 50)
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
    )


if __name__ == "__main__":
    main()
