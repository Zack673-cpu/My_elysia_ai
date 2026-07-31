"""后端基础测试"""
import sys
sys.path.insert(0, r"D:\Lib\site-packages")

import os
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def test_imports():
    """测试所有模块能正确导入"""
    from app.config import settings
    from app.models.schemas import Message, Conversation, ChatRequest
    from app.storage.json_store import JsonStore
    from app.services.agent_service import AgentService, web_search
    from app.services.search_service import SearchService
    from app.services.prompt_service import PromptService
    from app.services.conversation_service import ConversationService
    from app.main import app
    print("✅ 所有模块导入成功")


def test_json_store():
    """测试 JSON 存储"""
    from app.storage.json_store import JsonStore
    from pathlib import Path
    import tempfile

    with tempfile.TemporaryDirectory() as tmpdir:
        store = JsonStore(Path(tmpdir))
        store.write("test_key", {"hello": "world"})
        data = store.read("test_key")
        assert data == {"hello": "world"}, f"读取失败: {data}"
        assert store.exists("test_key")
        assert "test_key" in store.list_keys()
        store.delete("test_key")
        assert not store.exists("test_key")
    print("✅ JSON 存储测试通过")


def test_prompt_service():
    """测试提示词服务"""
    from app.services.prompt_service import PromptService
    prompt = PromptService.get_prompt()
    assert len(prompt) > 100, "提示词太短"
    assert "心理" in prompt or "咨询" in prompt, "缺少心理学相关内容"
    print("✅ 提示词服务测试通过")


def test_search_tool():
    """测试搜索工具已注册为智能体工具"""
    from app.services.agent_service import AgentService, web_search
    # web_search 应为 LangChain 工具，具备 name 与 description
    assert web_search.name == "web_search"
    assert web_search.description and len(web_search.description) > 10
    # 智能体应已挂载该工具
    agent = AgentService()
    assert any(t.name == "web_search" for t in agent.tools)
    print("✅ 搜索工具注册测试通过")


if __name__ == "__main__":
    test_imports()
    test_json_store()
    test_prompt_service()
    test_search_tool()
    print("\n🎉 所有测试通过!")
