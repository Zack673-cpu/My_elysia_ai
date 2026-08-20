"""聊天核心链路聚焦测试

覆盖 /api/health 与 /api/chat/send 的正常/失败分支（LLM 失败用 mock 模拟，
不发起真实请求）。使用临时数据目录，不污染真实对话数据。

运行方式（在 backend 目录下，两种方式均可）：
    python tests\\test_chat.py
    python -m tests.test_chat
"""
import os
import sys
import tempfile

# 锚定 backend 目录：无论从哪个工作目录、以哪种方式调用都能导入 app
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)
os.chdir(BACKEND_DIR)

# Windows GBK 控制台无法输出 emoji，统一切到 UTF-8
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# 必须在导入 app 之前设置：让数据库落在临时目录，测试不碰真实数据
_TMP_DATA_DIR = tempfile.TemporaryDirectory(prefix="elysia_test_")
os.environ["DATA_DIR"] = _TMP_DATA_DIR.name

from unittest.mock import AsyncMock  # noqa: E402

from fastapi.testclient import TestClient  # noqa: E402

from app.api import chat as chat_api  # noqa: E402
from app.db import create_db_and_tables, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.services.conversation_service import ConversationService  # noqa: E402

import atexit  # noqa: E402

# 退出时关闭连接池，否则 SQLite 文件被占用导致临时目录清理失败
atexit.register(engine.dispose)

create_db_and_tables()
# 不走 with 上下文（避免触发 lifespan 里的后台新闻抓取）
client = TestClient(app)
conv_service = ConversationService()


def test_health():
    """健康检查可达"""
    resp = client.get("/api/health")
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "ok"
    print("✅ 健康检查测试通过")


def test_send_success():
    """正常链路：用户消息与 AI 回复都入库"""
    conv = conv_service.create_conversation("测试-成功")
    chat_api.agent_service.chat = AsyncMock(return_value=("你好呀", False, 10))

    resp = client.post(
        "/api/chat/send",
        json={"conversation_id": conv.conversation_id, "message": "你好"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["message"]["content"] == "你好呀"

    roles = [m.role.value for m in conv_service.get_history(conv.conversation_id)]
    assert roles == ["user", "assistant"], f"消息序列异常: {roles}"
    print("✅ 聊天正常链路测试通过")


def test_send_failure_compensation():
    """失败补偿：LLM 抛错时返回 502，且不残留孤立用户消息"""
    conv = conv_service.create_conversation("测试-失败")
    chat_api.agent_service.chat = AsyncMock(side_effect=RuntimeError("LLM 不可用"))

    resp = client.post(
        "/api/chat/send",
        json={"conversation_id": conv.conversation_id, "message": "你好"},
    )
    assert resp.status_code == 502, resp.text

    msgs = conv_service.get_history(conv.conversation_id)
    assert msgs == [], f"残留半写对话: {[m.content for m in msgs]}"
    print("✅ LLM 失败补偿测试通过（无半写对话残留）")


if __name__ == "__main__":
    test_health()
    test_send_success()
    test_send_failure_compensation()
    print("\n🎉 聊天链路测试全部通过!")
