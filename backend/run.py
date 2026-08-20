"""My Elysia AI Backend 启动脚本"""
import logging

import uvicorn
from app.config import settings, APP_FULL_NAME


def main():
    # 统一日志格式：带时间戳与模块名，便于按 conversation_id 定位问题
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    print(f"🧠 {APP_FULL_NAME} Backend")
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
