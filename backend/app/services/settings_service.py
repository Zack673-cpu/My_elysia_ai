from sqlmodel import Session
from app.db import engine
from app.models.db_models import AppSetting

# 默认设置：每日问答领域默认前后端全栈，新闻范围默认 AI
DEFAULTS = {
    "quiz_topic": "前后端全栈",
    "news_scope": "AI",
}


class SettingsService:
    """应用设置 key-value 持久化（数据库），重启不丢"""

    def get(self, key: str) -> str:
        with Session(engine) as session:
            row = session.get(AppSetting, key)
            if row:
                return row.value
        return DEFAULTS.get(key, "")

    def set(self, key: str, value: str) -> None:
        with Session(engine) as session:
            row = session.get(AppSetting, key)
            if row:
                row.value = value
            else:
                row = AppSetting(key=key, value=value)
                session.add(row)
            session.commit()

    def get_quiz_topic(self) -> str:
        return self.get("quiz_topic") or DEFAULTS["quiz_topic"]

    def get_news_scope(self) -> str:
        return self.get("news_scope") or DEFAULTS["news_scope"]


settings_service = SettingsService()
