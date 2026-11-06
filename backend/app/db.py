import logging

from sqlalchemy import event, text
from sqlmodel import SQLModel, create_engine, Session
from app.config import settings

logger = logging.getLogger(__name__)

# SQLite 单文件数据库，放在数据目录下；WAL 模式防止并发写入冲突
DB_PATH = settings.data_dir_path / "app.db"
engine = create_engine(f"sqlite:///{DB_PATH}", echo=False)


@event.listens_for(engine, "connect")
def _set_sqlite_pragma(dbapi_connection, connection_record):
    """开启 WAL 与外键约束"""
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


def _add_column_if_missing(table: str, column: str, ddl: str) -> None:
    """给已存在的旧库补列（create_all 不会改已有表），幂等可重复执行"""
    with engine.connect() as conn:
        cols = {row[1] for row in conn.execute(text(f"PRAGMA table_info({table})"))}
        if column not in cols:
            conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {ddl}"))
            conn.commit()
            logger.info("数据库迁移：%s 表新增列 %s", table, column)


def create_db_and_tables():
    # 导入模型确保表已注册
    from app.models import db_models  # noqa: F401
    SQLModel.metadata.create_all(engine)
    _add_column_if_missing(
        "quiz_records", "on_demand",
        "on_demand BOOLEAN NOT NULL DEFAULT 0",
    )


def get_session():
    with Session(engine) as session:
        yield session
