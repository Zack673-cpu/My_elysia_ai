import asyncio
import time
from datetime import datetime, UTC, timedelta
from sqlmodel import Session, select
from app.db import engine
from app.models.db_models import NewsItem
from app.services.llm_service import LLMService
from app.services.search_service import SearchService
from app.services.settings_service import settings_service

_SUMMARIZE_SYSTEM = """你是一个新闻编辑。用户的专业领域是「{topic}」。
从给出的搜索结果中挑选最新、最重要的精华新闻（最多 5 条，宁缺毋滥）：
1. 只保留与用户专业领域相关、或对该领域从业者有价值的新闻，与专业无关的一律不要
2. 忽略广告、旧闻、论坛闲聊
3. 对每条入选新闻用一句简体中文概括其核心内容
只输出 JSON：{"news": [{"index": 搜索结果序号, "summary": "一句话概括"}]}"""


class NewsService:
    """每日新闻：仅后端启动时抓取一次；数据库只保留最近一周。

    消息源暂用现有搜索引擎（ddgs），后续换更权威的源只需改这里。
    """

    MIN_REFRESH_GAP = 3600  # 上次抓取距今不足 1 小时则跳过（防短时间反复重启重复抓）
    KEEP_DAYS = 7

    def __init__(self):
        self._search = SearchService()
        self.llm = LLMService()

    def _last_fetch_ts(self) -> float:
        with Session(engine) as session:
            item = session.exec(
                select(NewsItem).order_by(NewsItem.fetched_at.desc())
            ).first()
        return item.fetched_at.timestamp() if item else 0.0

    async def refresh_news(self) -> int:
        """抓取并入库新闻，返回新增条数。1 小时内抓过则跳过。"""
        if time.time() - self._last_fetch_ts() < self.MIN_REFRESH_GAP:
            print("[NewsService] 最近 1 小时内已抓取过，跳过")
            return 0

        scope = settings_service.get_news_scope()
        topic = settings_service.get_quiz_topic()
        # 搜索关键词结合用户专业领域，从源头让候选新闻更对口
        queries = [f"{scope} {topic} 最新 新闻", f"latest {scope} news"]
        candidates: list[dict] = []
        seen_urls: set[str] = set()
        for q in queries:
            results = await asyncio.to_thread(self._search.search, q, 8)
            for r in results:
                href = r.get("href", "")
                if href and href not in seen_urls:
                    seen_urls.add(href)
                    candidates.append(r)

        if not candidates:
            print("[NewsService] 搜索无结果，本次跳过")
            return 0

        # AI 筛选精华并一句话概括（最多传 16 条候选，控制上下文量）
        lines = []
        for i, r in enumerate(candidates[:16], 1):
            lines.append(f"{i}. {r.get('title', '')}\n   {r.get('body', '')}")
        data = await self.llm.ask_json(
            _SUMMARIZE_SYSTEM.replace("{topic}", topic), "\n\n".join(lines)
        )

        picked = data.get("news", [])[:5]
        added = 0
        with Session(engine) as session:
            existing_urls = {
                u[0] for u in session.exec(select(NewsItem.url)).all()
            }
            for item in picked:
                try:
                    idx = int(item.get("index")) - 1
                except (TypeError, ValueError):
                    continue
                if not (0 <= idx < len(candidates)):
                    continue
                summary = (item.get("summary") or "").strip()
                src = candidates[idx]
                url = src.get("href", "")
                if not summary or not url or url in existing_urls:
                    continue
                session.add(
                    NewsItem(
                        summary=summary,
                        url=url,
                        source_title=src.get("title", ""),
                    )
                )
                existing_urls.add(url)
                added += 1

            # 清理 7 天前的旧新闻
            cutoff = datetime.now(UTC) - timedelta(days=self.KEEP_DAYS)
            old_items = session.exec(
                select(NewsItem).where(NewsItem.fetched_at < cutoff)
            ).all()
            for item in old_items:
                session.delete(item)

            session.commit()

        print(f"[NewsService] 抓取完成，新增 {added} 条，清理 {len(old_items)} 条过期")
        return added

    def list_news(self, limit: int = 30) -> list[NewsItem]:
        with Session(engine) as session:
            return session.exec(
                select(NewsItem).order_by(NewsItem.fetched_at.desc()).limit(limit)
            ).all()

    @staticmethod
    def query_news(keyword: str, limit: int = 8) -> str:
        """供聊天智能体调用：按关键词在本地新闻库里找相关新闻"""
        with Session(engine) as session:
            items = session.exec(
                select(NewsItem)
                .where(
                    NewsItem.summary.contains(keyword)
                    | NewsItem.source_title.contains(keyword)
                )
                .order_by(NewsItem.fetched_at.desc())
                .limit(limit)
            ).all()
        if not items:
            return "本地新闻库中没有找到相关内容，可以改用搜索工具。"
        lines = []
        for item in items:
            fetched = item.fetched_at.strftime("%Y-%m-%d")
            lines.append(f"- {item.summary}（{fetched}）\n  来源: {item.url}")
        return "\n".join(lines)


news_service = NewsService()
