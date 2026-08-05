from sqlalchemy import event
from sqlmodel import SQLModel, create_engine, Session
from app.config import settings

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


def create_db_and_tables():
    # 导入模型确保表已注册
    from app.models import db_models  # noqa: F401
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
