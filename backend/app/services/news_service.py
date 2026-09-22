import asyncio
import json
import logging
import re
import time
import urllib.request
from datetime import datetime, UTC, timedelta
from html import unescape
from typing import Optional
from urllib.parse import urlparse
from sqlmodel import Session, select
from app.config import settings
from app.db import engine
from app.models.db_models import NewsItem
from app.services.llm_service import LLMService
from app.services.search_service import SearchService
from app.services.settings_service import settings_service

logger = logging.getLogger(__name__)

_SUMMARIZE_SYSTEM = """你是一个新闻编辑。用户的专业领域是「{topic}」。
下面给出的都是今天发布的新闻，每条附有网页原文摘录，请按重要性挑选最重要的精华新闻（最多 5 条，宁缺毋滥）：
1. 只保留与用户专业领域相关、或对该领域从业者有价值的新闻，与专业无关的一律不要
2. 忽略广告、论坛闲聊
3. 概括必须忠实于原文内容：外网新闻请先理解原文再翻译成简体中文，准确反映文章主体（如具体应用、具体结论），禁止用空泛说法代替，禁止脑补原文没有的信息
只输出 JSON：{"news": [{"index": 新闻序号, "summary": "一句话概括"}]}"""

# 路径里带这些段的链接基本是话题/分类列表页，不是单篇文章，直接排除
_LISTING_PATH_SEGMENTS = {
    "topic", "topics", "category", "categories", "tag", "tags",
    "search", "column", "columns", "special", "explore",
}

# 网页发布时间时间的常见埋点：meta 标签、JSON-LD、<time> 标签
_DATE_SOURCE_PATTERNS = [
    r'property=["\']article:published_time["\'][^>]*content=["\']([^"\']+)',
    r'content=["\']([^"\']+)["\'][^>]*property=["\']article:published_time["\']',
    r'(?:name|itemprop)=["\']datePublished["\'][^>]*content=["\']([^"\']+)',
    r'"datePublished"\s*:\s*"([^"]+)"',
    r'<time[^>]+datetime=["\']([^"\']+)',
]


# AIHOT：中文 AI 资讯精选站，匿名只读 API（个人非商业用途免费）。
# UA 遵循其 Skill 约定，便于服务端识别直接消费实例
_AIHOT_ITEMS_API = "https://aihot.virxact.com/api/v1/items"
_AIHOT_UA = "aihot-skill/1.5.4 (+https://aihot.virxact.com/aihot-skill/)"


def _parse_datetime_str(text: str) -> Optional[datetime]:
    """尽量把各种格式的日期字符串解析成 datetime，解析不了返回 None"""
    text = text.strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        pass
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d", "%Y/%m/%d", "%Y年%m月%d日"):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    # 兜底：从字符串里找 yyyy-mm-dd 形式的日期
    m = re.search(r"(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})", text)
    if m:
        try:
            return datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            return None
    return None


def _fetch_html(url: str, timeout: float = 8.0) -> Optional[str]:
    """抓取网页 HTML；失败返回 None"""
    try:
        handlers = []
        if settings.search_proxy:
            handlers.append(urllib.request.ProxyHandler({
                "http": settings.search_proxy,
                "https": settings.search_proxy,
            }))
        opener = urllib.request.build_opener(*handlers)
        req = urllib.request.Request(url, headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,*/*",
        })
        with opener.open(req, timeout=timeout) as resp:
            return resp.read(512 * 1024).decode("utf-8", errors="ignore")
    except Exception as e:
        logger.warning("获取网页失败 %s: %s", url, e)
        return None


def _is_listing_url(url: str) -> bool:
    """URL 路径是否像话题/分类列表页（点开是一堆新闻而不是一篇文章）"""
    segments = [s.lower() for s in urlparse(url).path.split("/") if s]
    return bool(_LISTING_PATH_SEGMENTS & set(segments))


def _looks_like_listing_page(html: str) -> bool:
    """页面上带时间的条目太多，说明是新闻列表页而不是单篇文章"""
    return len(re.findall(r'<time[^>]+datetime=', html, re.IGNORECASE)) > 2


def _extract_text(html: str, limit: int = 2000) -> str:
    """从 HTML 里提取纯文本正文（去脚本样式和标签），供 AI 阅读翻译"""
    text = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    text = re.sub(r"<[^>]+>", " ", text)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text[:limit]


def get_page_publish_time(url: str, timeout: float = 8.0) -> Optional[datetime]:
    """抓取网页并解析其发布时间；获取不到返回 None。

    只认页面自身标注的时间（meta/JSON-LD/<time>），
    不用 Last-Modified——列表页会随服务器更新而变，会把旧内容伪装成“今天发布”。
    """
    html = _fetch_html(url, timeout)
    if html is None:
        return None

    for pattern in _DATE_SOURCE_PATTERNS:
        m = re.search(pattern, html, re.IGNORECASE)
        if m:
            dt = _parse_datetime_str(m.group(1))
            if dt is not None:
                return dt
    return None


def inspect_page(url: str) -> tuple[Optional[datetime], str]:
    """对候选网页只抓取一次，同时拿到发布时间和正文摘录。

    列表页（URL 像列表页，或页面上带时间的条目过多）直接判废，
    保证入库的新闻点开都是单篇文章。失败/列表页返回 (None, '')。
    """
    if _is_listing_url(url):
        return None, ""
    html = _fetch_html(url)
    if html is None or _looks_like_listing_page(html):
        return None, ""
    pub = None
    for pattern in _DATE_SOURCE_PATTERNS:
        m = re.search(pattern, html, re.IGNORECASE)
        if m:
            pub = _parse_datetime_str(m.group(1))
            if pub is not None:
                break
    return pub, _extract_text(html, 800)


def fetch_aihot_candidates(limit: int = 12) -> list[dict]:
    """从 AIHOT 拉取过去 24 小时的精选 AI 新闻。

    返回结构与搜索结果兼容（title/body/href），额外带 publishedAt（ISO 时间）。
    AIHOT 已给出发布时间和中文摘要，无需再逐页抓取验证。失败返回空列表，
    由调用方回退到搜索引擎。
    """
    url = f"{_AIHOT_ITEMS_API}?mode=selected&window=24h&limit={limit}"
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": _AIHOT_UA,
            "Accept": "application/json",
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        logger.warning("AIHOT 获取失败: %s", e)
        return []
    candidates: list[dict] = []
    for item in data.get("items", []):
        href = (item.get("links") or {}).get("original") or ""
        title = item.get("title") or ""
        if not href or not title:
            continue
        candidates.append({
            "title": title,
            "body": item.get("summary") or "",
            "href": href,
            "publishedAt": item.get("publishedAt") or item.get("discoveredAt") or "",
        })
    return candidates


class NewsService:
    """每日新闻：仅后端启动时抓取一次；数据库只保留最近一周。

    消息源优先用 AIHOT 精选（中文 AI 资讯策展站），失败时回退搜索引擎（ddgs）。
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

    async def refresh_news(self, force: bool = False) -> int:
        """抓取并入库新闻，返回新增条数。非 force 时 1 小时内抓过则跳过。

        force=True 供用户在设置里改范围后手动「立即刷新」，绕过 1 小时防抖。
        """
        if not force and time.time() - self._last_fetch_ts() < self.MIN_REFRESH_GAP:
            logger.info("最近 1 小时内已抓取过，跳过")
            return 0

        scope = settings_service.get_news_scope()
        topic = settings_service.get_quiz_topic()

        # 新闻源：优先 AIHOT 当日精选；它不可用时回退搜索引擎
        candidates = await asyncio.to_thread(fetch_aihot_candidates, 12)
        from_aihot = bool(candidates)
        if not from_aihot:
            # 搜索关键词结合用户专业领域，从源头让候选新闻更对口
            queries = [f"{scope} {topic} 最新 新闻", f"latest {scope} news"]
            seen_urls: set[str] = set()
            for q in queries:
                results = await asyncio.to_thread(self._search.search, q, 8)
                for r in results:
                    href = r.get("href", "")
                    if href and href not in seen_urls:
                        seen_urls.add(href)
                        candidates.append(r)

        if not candidates:
            logger.info("新闻源无结果，本次跳过")
            return 0

        candidates = candidates[:16]
        fresh: list[tuple[dict, datetime, str]] = []
        if from_aihot:
            # AIHOT 自带发布时间与中文摘要，直接用，不逐页抓取
            for r in candidates:
                pub = _parse_datetime_str(r.get("publishedAt", ""))
                if pub is not None and self.is_today(pub):
                    fresh.append((r, pub, r.get("body", "")))
                else:
                    logger.info("淘汰 AIHOT 候选: %s（发布时间: %s）", r.get("href", ""), pub)
        else:
            # 时效性先行：并发检查候选网页（排除列表页），只留电脑当天发布的
            inspections = await asyncio.gather(*[
                asyncio.to_thread(inspect_page, r.get("href", ""))
                for r in candidates
            ])
            for r, (pub, text) in zip(candidates, inspections):
                if pub is not None and self.is_today(pub):
                    fresh.append((r, pub, text))
                else:
                    logger.info("淘汰候选: %s（发布时间: %s）", r.get("href", ""), pub)

        if not fresh:
            logger.info("候选中没有当天发布的单篇新闻，本次跳过")
            return self._cleanup_legacy()

        # AI 基于网页原文摘录按重要性挑选并翻译成中文概括
        lines = []
        for i, (r, _, text) in enumerate(fresh, 1):
            excerpt = text or r.get("body", "")
            lines.append(f"{i}. {r.get('title', '')}\n   原文摘录: {excerpt}")
        data = await self.llm.ask_json(
            _SUMMARIZE_SYSTEM.replace("{topic}", topic), "\n\n".join(lines)
        )

        picked = data.get("news", [])[:5]
        fresh_picks: list[tuple[str, dict, datetime]] = []
        picked_urls: set[str] = set()
        for item in picked:
            try:
                idx = int(item.get("index")) - 1
            except (TypeError, ValueError):
                continue
            if not (0 <= idx < len(fresh)):
                continue
            summary = (item.get("summary") or "").strip()
            src, pub, _ = fresh[idx]
            url = src.get("href", "")
            if summary and url and url not in picked_urls:
                fresh_picks.append((summary, src, pub))
                picked_urls.add(url)

        added = 0
        with Session(engine) as session:
            existing_urls = {
                u[0] for u in session.exec(select(NewsItem.url)).all()
            }
            for summary, src, pub in fresh_picks:
                url = src.get("href", "")
                if url in existing_urls:
                    continue
                session.add(
                    NewsItem(
                        summary=summary,
                        url=url,
                        source_title=src.get("title", ""),
                        published_at=pub,
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

            # 清理历史脏数据：无发布时间，或发布时间与收集日期对不上的
            dirty_items = [
                item for item in session.exec(select(NewsItem)).all()
                if item.published_at is None or not self._same_day(
                    item.published_at, item.fetched_at
                )
            ]
            for item in dirty_items:
                session.delete(item)

            dup_items = self._find_duplicate_items(session)
            for item in dup_items:
                session.delete(item)

            session.commit()

        logger.info(
            "抓取完成（来源: %s），新增 %s 条，"
            "清理 %s 条过期、%s 条脏数据、%s 条重复",
            "AIHOT" if from_aihot else "搜索引擎",
            added,
            len(old_items),
            len(dirty_items),
            len(dup_items),
        )
        return added

    @staticmethod
    def _find_duplicate_items(session: Session) -> list[NewsItem]:
        """找出同 URL 的重复记录（多实例并发抓取可能写重），保留最新一条"""
        latest_by_url: dict[str, NewsItem] = {}
        dups: list[NewsItem] = []
        for item in session.exec(select(NewsItem).order_by(NewsItem.id)).all():
            prev = latest_by_url.get(item.url)
            if prev is not None:
                dups.append(prev)
            latest_by_url[item.url] = item
        return dups

    def _cleanup_legacy(self) -> int:
        """本次没抓到新新闻时，也要把历史脏数据和重复条目清掉"""
        with Session(engine) as session:
            dirty_items = [
                item for item in session.exec(select(NewsItem)).all()
                if item.published_at is None or not self._same_day(
                    item.published_at, item.fetched_at
                )
            ]
            for item in dirty_items:
                session.delete(item)
            dup_items = self._find_duplicate_items(session)
            for item in dup_items:
                session.delete(item)
            session.commit()
        if dirty_items or dup_items:
            logger.info("清理 %s 条脏数据、%s 条重复", len(dirty_items), len(dup_items))
        return 0

    @staticmethod
    def _same_day(published: datetime, fetched: datetime) -> bool:
        """发布时间与收集时间是否算同一天。

        数据库存储会丢时区（发布时间是网站当地钟点，收集时间是 UTC 钟点），
        裸日期最多可能差一天，所以允许 ±1 天的容差；
        真正的脏数据（旧闻）差的是几个月，不会被误放。
        """
        return abs((published.date() - fetched.date()).days) <= 1

    @staticmethod
    def is_today(dt: datetime) -> bool:
        """发布时间是否落在电脑当天（本地时区）"""
        if dt.tzinfo is not None:
            dt = dt.astimezone()
        return dt.date() == datetime.now().date()

    def list_news(self, limit: int = 30) -> list[NewsItem]:
        with Session(engine) as session:
            items = session.exec(
                select(NewsItem).order_by(NewsItem.fetched_at.desc()).limit(limit)
            ).all()
        # 库里存的是 UTC 钟点但没带时区标记，补上后前端才能正确换算本地日期
        for item in items:
            if item.fetched_at.tzinfo is None:
                item.fetched_at = item.fetched_at.replace(tzinfo=UTC)
        return items

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
