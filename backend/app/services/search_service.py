import hashlib
import json
import time
from typing import Optional
from ddgs import DDGS
from app.config import settings


class SearchService:
    """多引擎搜索服务，带缓存、限频、失败重试和过期缓存兜底"""

    CACHE_TTL = 86400  # 缓存有效期 24 小时（秒）
    MIN_INTERVAL = 2.0  # 最小搜索间隔（秒）
    # 限定搜索引擎：默认 auto 会轮询到 Google，代理 IP 易被其反爬拦截（403 automated queries）
    # ddgs 内部会按引擎优先级依次尝试，单个引擎失败会自动换下一个
    BACKENDS = "duckduckgo, bing, brave, startpage"
    TIMEOUT = 8  # 单次搜索超时（秒），走代理比直连慢，ddgs 默认 5 秒偏紧
    MAX_ATTEMPTS = 2  # 全部引擎都失败时的总尝试次数（含首次）
    RETRY_DELAY = 1.5  # 重试前的等待秒数

    def __init__(self):
        self._last_search_time = 0.0
        self._cache_dir = settings.search_cache_dir
        # 国内直连 DuckDuckGo 不可达，需走代理；留空则直连
        self._proxy = settings.search_proxy or None

    def _cache_key(self, query: str) -> str:
        return hashlib.md5(query.encode()).hexdigest()

    def _read_cache(self, query: str, ignore_ttl: bool = False) -> Optional[list[dict]]:
        """读取缓存；ignore_ttl=True 时连过期缓存也返回，用于搜索全部失败时兜底"""
        cache_file = self._cache_dir / f"{self._cache_key(query)}.json"
        if not cache_file.exists():
            return None
        try:
            data = json.loads(cache_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            # 缓存文件损坏不应中断搜索，当作没有缓存
            return None
        if ignore_ttl or time.time() - data.get("timestamp", 0) < self.CACHE_TTL:
            return data.get("results", [])
        return None

    def _write_cache(self, query: str, results: list[dict]) -> None:
        cache_file = self._cache_dir / f"{self._cache_key(query)}.json"
        data = {"query": query, "results": results, "timestamp": time.time()}
        cache_file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def search(self, query: str, max_results: int = 5) -> list[dict]:
        """执行搜索，优先使用缓存；全部引擎失败时重试，仍失败则退回过期缓存"""
        cached = self._read_cache(query)
        if cached is not None:
            return cached[:max_results]

        results = self._search_with_retry(query, max_results)

        # 仅缓存非空结果，避免失败的空结果被缓存 24h 导致后续查询无法重试
        if results:
            self._write_cache(query, results)
            return results

        # 兜底：所有引擎和重试都失败时，过期资料也比没资料强
        stale = self._read_cache(query, ignore_ttl=True)
        if stale:
            print(f"[SearchService] 搜索失败，使用过期缓存兜底: {query}")
            return stale[:max_results]
        return []

    def _search_with_retry(self, query: str, max_results: int) -> list[dict]:
        """按白名单引擎搜索，引擎全部失败时退避重试"""
        for attempt in range(1, self.MAX_ATTEMPTS + 1):
            self._wait_min_interval()
            try:
                with DDGS(proxy=self._proxy, timeout=self.TIMEOUT) as ddgs:
                    results = list(ddgs.text(query, max_results=max_results, backend=self.BACKENDS))
                if results:
                    return results
            except Exception as e:
                reason = self._describe_error(e)
                print(
                    f"[SearchService] 第 {attempt}/{self.MAX_ATTEMPTS} 次搜索失败（{reason}）: {e}"
                )
                # 引擎正常响应但确实没有资料，重试只是白白等待
                if reason == "无匹配结果":
                    return []
            finally:
                self._last_search_time = time.time()
            if attempt < self.MAX_ATTEMPTS:
                time.sleep(self.RETRY_DELAY)
        return []

    def _wait_min_interval(self) -> None:
        """限频：与上次搜索至少间隔 MIN_INTERVAL 秒，避免请求过密被引擎拦截"""
        elapsed = time.time() - self._last_search_time
        if elapsed < self.MIN_INTERVAL:
            time.sleep(self.MIN_INTERVAL - elapsed)

    @staticmethod
    def _describe_error(error: Exception) -> str:
        """把底层异常归类成人话，方便区分是网络问题、被拦截，还是真的搜不到"""
        text = str(error).lower()
        if "no results found" in text:
            return "无匹配结果"
        if "timed out" in text or "timeout" in text:
            return "网络超时"
        if "403" in text or "forbidden" in text or "automated" in text:
            return "被引擎反爬拦截"
        if "connect" in text:
            return "连接失败，检查代理是否开着"
        return "未知错误"

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
