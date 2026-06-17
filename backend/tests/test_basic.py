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
    from app.services.llm_service import LLMService
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
    stages = PromptService.list_stages()
    assert stages == ["demugo", "cryene", "elysia"]
    for stage in stages:
        prompt = PromptService.get_prompt(stage)
        assert len(prompt) > 100, f"{stage} 提示词太短"
        assert "心理" in prompt or "咨询" in prompt, f"{stage} 缺少心理学相关内容"
    print("✅ 提示词服务测试通过")


def test_search_markers():
    """测试搜索标记解析"""
    from app.services.llm_service import LLMService
    text = "我觉得需要了解一些信息 [SEARCH: 认知行为疗法 焦虑] 然后继续说 [SEARCH: 正念冥想]"
    queries = LLMService.extract_search_queries(text)
    assert len(queries) == 2
    assert "认知行为疗法 焦虑" in queries
    assert "正念冥想" in queries
    cleaned = LLMService.clean_search_markers(text)
    assert "[SEARCH" not in cleaned
    print("✅ 搜索标记解析测试通过")


if __name__ == "__main__":
    test_imports()
    test_json_store()
    test_prompt_service()
    test_search_markers()
    print("\n🎉 所有测试通过!")
