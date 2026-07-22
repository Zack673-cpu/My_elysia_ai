from pathlib import Path
from pydantic_settings import BaseSettings
from pydantic import Field

# ====== 应用名称变量 ======
# 阶段演进：Demugo → Cryene → Elysia，改这里即可
APP_NAME = "Demugo"
APP_FULL_NAME = f"{APP_NAME} AI"
# ==========================


class Settings(BaseSettings):
    """应用配置，从环境变量和 .env 文件加载"""

    # DeepSeek API
    deepseek_api_key: str = Field(default="", alias="DEEPSEEK_API_KEY")
    deepseek_model: str = Field(default="deepseek-chat", alias="DEEPSEEK_MODEL")
    deepseek_base_url: str = Field(default="https://api.deepseek.com", alias="DEEPSEEK_BASE_URL")

    # Server
    host: str = Field(default="0.0.0.0", alias="HOST")
    port: int = Field(default=8000, alias="PORT")

    # Stage
    stage: str = Field(default="demugo", alias="STAGE")

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