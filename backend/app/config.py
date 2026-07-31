from pathlib import Path
from pydantic_settings import BaseSettings
from pydantic import Field

# ====== 应用名称变量 ======
# 应用显示名（产品名），改这里即可；Demugo → Cryene → Elysia 是项目开发阶段代号（非人格，AI 角色始终是昔涟）
APP_NAME = "My Elysia"
APP_FULL_NAME = f"{APP_NAME} AI"
# ==========================


class Settings(BaseSettings):
    """应用配置，从环境变量和 .env 文件加载"""

    # DeepSeek API
    deepseek_api_key: str = Field(default="", alias="DEEPSEEK_API_KEY")
    deepseek_model: str = Field(default="deepseek-chat", alias="DEEPSEEK_MODEL")
    deepseek_base_url: str = Field(default="https://api.deepseek.com", alias="DEEPSEEK_BASE_URL")

    # Search
    # 国内访问 DuckDuckGo 需要代理（FClash 默认混合端口 http://127.0.0.1:7890），留空则直连
    search_proxy: str = Field(default="", alias="SEARCH_PROXY")

    # Server
    host: str = Field(default="0.0.0.0", alias="HOST")
    port: int = Field(default=8000, alias="PORT")

    # Data directory
    data_dir: str = Field(default="./data", alias="DATA_DIR")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"

    @property
    def conversations_dir(self) -> Path:
        path = Path(self.data_dir) / "conversations"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def personality_dir(self) -> Path:
        path = Path(self.data_dir) / "personality"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def search_cache_dir(self) -> Path:
        path = Path(self.data_dir) / "search_cache"
        path.mkdir(parents=True, exist_ok=True)
        return path


settings = Settings()


if __name__ == "__main__":
    print(f"APP_NAME = {APP_NAME}")