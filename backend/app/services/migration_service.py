import json
from datetime import datetime, UTC
from sqlmodel import Session
from app.config import settings
from app.db import engine
from app.models.db_models import AppSetting, ConversationRecord, MessageRecord

_MIGRATION_FLAG = "migrated_json_conversations"


def _parse_dt(value):
    """解析 JSON 里的时间字符串，失败则用当前时间"""
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            pass
    return datetime.now(UTC)


def migrate_json_conversations() -> int:
    """把旧的 JSON 文件对话一次性导入数据库，返回导入数量。

    只迁移不删除原 JSON 文件；用 app_settings 里的标记防止重复迁移。
    """
    with Session(engine) as session:
        flag = session.get(AppSetting, _MIGRATION_FLAG)
        if flag is not None:
            return 0

    json_dir = settings.conversations_dir
    imported = 0
    for path in sorted(json_dir.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            print(f"[Migration] 跳过损坏的对话文件: {path.name}")
            continue

        with Session(engine) as session:
            exists = session.get(ConversationRecord, data.get("conversation_id", ""))
            if exists:
                continue
            rec = ConversationRecord(
                conversation_id=data["conversation_id"],
                title=data.get("title", "新对话"),
                model=data.get("model", "deepseek-chat"),
                created_at=_parse_dt(data.get("created_at")),
                updated_at=_parse_dt(data.get("updated_at")),
                metadata_json=data.get("metadata") or {},
            )
            session.add(rec)
            for m in data.get("messages", []):
                session.add(
                    MessageRecord(
                        conversation_id=rec.conversation_id,
                        role=m.get("role", "user"),
                        content=m.get("content", ""),
                        timestamp=_parse_dt(m.get("timestamp")),
                        metadata_json=m.get("metadata") or {},
                    )
                )
            session.commit()
            imported += 1

    with Session(engine) as session:
        session.add(AppSetting(key=_MIGRATION_FLAG, value="1"))
        session.commit()

    if imported:
        print(f"[Migration] 已从 JSON 导入 {imported} 个对话到数据库")
    return imported
