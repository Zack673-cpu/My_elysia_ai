import hashlib
import json
import time
from pathlib import Path
from typing import Optional
from duckduckgo_search import DDGS
from app.config import settings


class SearchService:
    """DuckDuckGo 搜索服务，带缓存和限频"""

    CACHE_TTL = 86400  # 缓存有效期 24 小时（秒）
    MIN_INTERVAL = 2.0  # 最小搜索间隔（秒）

    def __init__(self):
        self._last_search_time = 0.0
        self._cache_dir = settings.search_cache_dir

    def _cache_key(self, query: str) -> str:
        return hashlib.md5(query.encode()).hexdigest()

    def _read_cache(self, query: str) -> Optional[list[dict]]:
        cache_file = self._cache_dir / f"{self._cache_key(query)}.json"
        if cache_file.exists():
            data = json.loads(cache_file.read_text(encoding="utf-8"))
            if time.time() - data.get("timestamp", 0) < self.CACHE_TTL:
                return data.get("results", [])
        return None

    def _write_cache(self, query: str, results: list[dict]) -> None:
        cache_file = self._cache_dir / f"{self._cache_key(query)}.json"
        data = {"query": query, "results": results, "timestamp": time.time()}
        cache_file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def search(self, query: str, max_results: int = 5) -> list[dict]:
        """执行 DuckDuckGo 搜索，优先使用缓存"""
        # 检查缓存
        cached = self._read_cache(query)
        if cached is not None:
            return cached[:max_results]

        # 限频
        elapsed = time.time() - self._last_search_time
        if elapsed < self.MIN_INTERVAL:
            time.sleep(self.MIN_INTERVAL - elapsed)

        # 执行搜索
        try:
            with DDGS() as ddgs:
                results = list(ddgs.text(query, max_results=max_results))
            self._last_search_time = time.time()
        except Exception as e:
            print(f"[SearchService] 搜索失败: {e}")
            results = []

        # 写入缓存
        self._write_cache(query, results)
        return results

    @staticmethod
    def format_results_for_context(results: list[dict]) -> str:
        """将搜索结果格式化为 LLM 上下文"""
        if not results:
            return "未找到相关搜索结果。"
        lines = []
        for i, r in enumerate(results, 1):
            title = r.get("title", "")
            body = r.get("body", "")
            href = r.get("href", "")
            lines.append(f"{i}. {title}\n   {body}\n   来源: {href}")
        return "\n\n".join(lines)
