import logging
from datetime import date, timedelta

from sqlmodel import Session, select

from app.db import engine
from app.models.db_models import QuizCard, QuizRecord
from app.services.llm_service import LLMService
from app.services.settings_service import settings_service

logger = logging.getLogger(__name__)


# 艾宾浩斯间隔梯度（自然日）：level 1~7 对应 1,2,4,7,15,30,90 天
INTERVALS = [1, 2, 4, 7, 15, 30, 90]
MAX_LEVEL = len(INTERVALS)

_GEN_SYSTEM = """你是一个专业出题官。在「{topic}」领域出一道专业问答题。
要求：
1. 难度适中，普通相关专业学生能在两分钟内口头答完
2. 概念清晰、答案明确，不要出开放式的论述题
3. 不要与给出的近期题目重复或高度相似
4. 一定要确保答案正确规范，再三思考确保答案无误之后再出题
只输出 JSON：{"question": "题目", "reference_answer": "参考答案，不超过三句话"}"""

_VERIFY_SYSTEM = """你是一个专业知识核验员。独立解答下面的问题，不要猜测，反复推敲确保准确。
只输出 JSON：{"answer": "简洁准确的答案，不超过三句话"}"""

_MERGE_SYSTEM = """你是一个严谨的参考答案终审官。同一道题有两份答案，请反复推敲：
判断哪份更准确，或综合两者给出最终参考答案；若两份都有错误，必须给出修正后的正确答案。
只输出 JSON：{"reference_answer": "最终参考答案，不超过三句话"}"""

_EVAL_SYSTEM = """你是一个严谨的答题评估官。根据题目和参考答案评估用户的回答。
你的反馈将以「昔涟」的口吻呈现：温柔、体贴、多鼓励少指责，即使答错了也要委婉柔和地指出，不打击用户积极性。
避免过分的夸赞。请记住，你的回答不一定是对的，我的判断也不一定是对的。对待所有问题都要反复推敲，优先保证准确性。
回答时条理清晰。
若你有充分把握判断参考答案本身存在错误，必须在 feedback 中明确指出，并给出你认为正确的答案，此时以正确内容为准评估用户回答。
输出要求：
1. feedback：第一句话必须先明确判定用户回答是正确、错误还是不够完整，然后再给出具体评价；
   无论用户回答得如何，feedback 中都必须给出本题完整正确的答案（以参考答案为准，可适当展开补充）
2. suggestion：给用户的复习建议（一句到两句，例如建议多巩固还是掌握得不错），此内容不计入 feedback
3. grade：三选一——
   "correct"：回答正确
   "wrong"：回答错误或基本没答上来
   "partial"：回答不够完整或不够精确，无法简单用对错判断
只输出 JSON：{"grade": "...", "feedback": "...", "suggestion": "..."}"""


class QuizService:
    """每日问答：艾宾浩斯间隔重复。

    选题与排期全部由代码查库完成，AI 不参与选题，也永远接触不到整个题库：
    - 出新题时只传领域要求 + 最近 2 道旧题做避重
    - 评估时只传当前题 + 参考答案 + 用户回答
    """

    def __init__(self):
        self.llm = LLMService()

    # ---- 工具方法 ----

    @staticmethod
    def _today() -> str:
        return date.today().isoformat()

    @staticmethod
    def _add_days(days: int) -> str:
        return (date.today() + timedelta(days=days)).isoformat()

    @staticmethod
    def _interval(level: int) -> int:
        return INTERVALS[max(1, min(level, MAX_LEVEL)) - 1]

    def count_due(self) -> int:
        """当前到期（含积压）的复习卡数量（只数领域在当前设置范围内的）"""
        with Session(engine) as session:
            cards = session.exec(
                select(QuizCard).where(
                    QuizCard.status == "learning",
                    QuizCard.next_review_date <= self._today(),
                )
            ).all()
            return sum(1 for c in cards if self._topic_in_scope(c.topic))

    def _pick_due_card(self) -> QuizCard | None:
        """取一张到期复习卡：优先逾期天数多的，同级取早创建的。

        只挑领域在当前设置范围内的卡：范围外的到期卡先放着，
        等用户把范围改回（再次包含该领域）时再出。
        """
        with Session(engine) as session:
            cards = session.exec(
                select(QuizCard)
                .where(
                    QuizCard.status == "learning",
                    QuizCard.next_review_date <= self._today(),
                )
                .order_by(QuizCard.next_review_date, QuizCard.id)
            ).all()
        for card in cards:
            if self._topic_in_scope(card.topic):
                logger.info(
                    "pick_due_card 选中 card=%s topic=%s level=%s 到期=%s",
                    card.id, card.topic, card.level, card.next_review_date,
                )
                return card
        logger.info(
            "pick_due_card 无可选到期卡（范围内共%d张到期，全部不在当前领域范围或已清空）",
            len(cards),
        )
        return None

    def _get_today_record(self) -> QuizRecord | None:
        """今日"当前应展示"的记录，按优先级：
        1. 已作答但未处理完（弹窗待决）的记录 —— 弹窗必须最先响应，否则决策会丢
        2. 最早一条未作答的复习题 —— 复习卡先插入、先展示，实现复习优先
        3. 未答的新题：仅当今天还没答过题时展示（当天首道可能就是新题）；
           今天已答过则跳过未答新题（那是"再来一题"的侧题，不自动弹）
        4. 兜底取最新一条（展示已答反馈/完成态）
        """
        def _first(stmt):
            with Session(engine) as session:
                return session.exec(stmt).first()

        record = _first(
            select(QuizRecord)
            .where(
                QuizRecord.asked_date == self._today(),
                QuizRecord.user_answer.is_not(None),
                QuizRecord.resolved.is_(False),
            )
            .order_by(QuizRecord.id.desc())
        )
        if record is not None:
            return record

        # 未答的复习题（复习优先）
        record = _first(
            select(QuizRecord)
            .where(
                QuizRecord.asked_date == self._today(),
                QuizRecord.user_answer.is_(None),
                QuizRecord.is_review.is_(True),
            )
            .order_by(QuizRecord.id)
        )
        if record is not None:
            return record

        if not self._has_answered_today():
            # 今天还没答过题：未答的新题照常展示（当天首次做的可能就是新题）
            record = _first(
                select(QuizRecord)
                .where(
                    QuizRecord.asked_date == self._today(),
                    QuizRecord.user_answer.is_(None),
                )
                .order_by(QuizRecord.id)
            )
            if record is not None:
                return record

        # 今天已答过：返回最新一条已答记录（完成态反馈），不再展示未答的补题
        return _first(
            select(QuizRecord)
            .where(
                QuizRecord.asked_date == self._today(),
                QuizRecord.user_answer.is_not(None),
            )
            .order_by(QuizRecord.id.desc())
        )

    def _has_answered_today(self) -> bool:
        """今天是否已作答过任意一道题（用于判定"今日已完成"，防止自动再出题）"""
        with Session(engine) as session:
            row = session.exec(
                select(QuizRecord.id).where(
                    QuizRecord.asked_date == self._today(),
                    QuizRecord.user_answer.is_not(None),
                )
            ).first()
            return row is not None

    @staticmethod
    def _recent_questions(exclude_card_id: int | None = None) -> list[str]:
        """最近 2 道旧题，仅用于出新题时避重"""
        with Session(engine) as session:
            stmt = select(QuizCard).order_by(QuizCard.id.desc()).limit(4)
            cards = session.exec(stmt).all()
        questions = []
        for c in cards:
            if exclude_card_id is not None and c.id == exclude_card_id:
                continue
            questions.append(c.question)
            if len(questions) >= 2:
                break
        return questions

    # 领域设置里多个主题的常见分隔符（"全栈和四六级英语单词" → 两个领域）
    _TOPIC_SEPARATORS = ("和", "与", "及", "、", ",", "，", ";", "；", "/", "|")

    def _split_topics(self, raw: str) -> list[str]:
        """把领域设置按常见分隔符拆成多个子领域（没匹配到就整体算一个）"""
        parts = [raw]
        for sep in self._TOPIC_SEPARATORS:
            parts = [p for chunk in parts for p in chunk.split(sep)]
        topics: list[str] = []
        for p in parts:
            p = p.strip()
            if p and p not in topics:
                topics.append(p)
        return topics or [raw]

    def _pick_topic(self) -> str:
        """本次出新题用哪个子领域：优先最近没出过的（含"前后端全栈"这种父写法），
        都出过就接在上一张之后轮换。"""
        topics = self._split_topics(settings_service.get_quiz_topic())
        if len(topics) == 1:
            return topics[0]
        with Session(engine) as session:
            recent = session.exec(
                select(QuizCard.topic).order_by(QuizCard.id.desc()).limit(5)
            ).all()
        for t in topics:
            if not any(t in c or c in t for c in recent):
                return t
        if recent:
            for i, t in enumerate(topics):
                if t in recent[0] or recent[0] in t:
                    return topics[(i + 1) % len(topics)]
        return topics[0]

    def _discard_unanswered(self) -> None:
        """清理没回答过的题：新题卡（pending）连同记录一起删，不留在库里；
        复习卡只删作答记录，卡片本身的复习排期保留。"""
        with Session(engine) as session:
            records = session.exec(
                select(QuizRecord).where(QuizRecord.user_answer.is_(None))
            ).all()
            for row in records:
                card = session.get(QuizCard, row.card_id)
                if card is not None and card.status == "pending":
                    session.delete(card)
                session.delete(row)
            session.commit()

    def _topic_in_scope(self, card_topic: str) -> bool:
        """卡片的领域是否在当前设置范围内。

        卡片领域和设置都拆成子领域做双向包含匹配；卡片领域是整串
        （如"全栈和四六级英语单词"）时，要求每个子领域都在当前范围内。
        """
        topics = self._split_topics(settings_service.get_quiz_topic())
        return all(
            any(t in ct or ct in t for t in topics)
            for ct in self._split_topics(card_topic)
        )

    def _card_topic(self, card_id: int) -> str:
        with Session(engine) as session:
            card = session.get(QuizCard, card_id)
            return card.topic if card else ""

    def _today_topics(self) -> set[str]:
        """今天所有题目（含复习）覆盖到的子领域"""
        with Session(engine) as session:
            records = session.exec(
                select(QuizRecord).where(QuizRecord.asked_date == self._today())
            ).all()
            card_ids = [r.card_id for r in records]
            cards = (
                session.exec(select(QuizCard).where(QuizCard.id.in_(card_ids))).all()
                if card_ids
                else []
            )
        covered: set[str] = set()
        for c in cards:
            covered.update(self._split_topics(c.topic))
        return covered

    def _uncovered_topics(self) -> list[str]:
        """范围内还没出过题的子领域（保持设置里的顺序）"""
        topics = self._split_topics(settings_service.get_quiz_topic())
        covered = self._today_topics()
        return [t for t in topics if not any(t in c or c in t for c in covered)]

    def _get_unanswered_new_today(self) -> QuizRecord | None:
        """今天最早一道还没作答的新题（"再来一题"连做多道新题用）"""
        with Session(engine) as session:
            return session.exec(
                select(QuizRecord)
                .where(
                    QuizRecord.asked_date == self._today(),
                    QuizRecord.is_review.is_(False),
                    QuizRecord.user_answer.is_(None),
                )
                .order_by(QuizRecord.id)
            ).first()

    def _count_pending_new_today(self) -> int:
        """今天还没作答的新题数量（"再来一题"按钮提示用）"""
        with Session(engine) as session:
            rows = session.exec(
                select(QuizRecord.id).where(
                    QuizRecord.asked_date == self._today(),
                    QuizRecord.is_review.is_(False),
                    QuizRecord.user_answer.is_(None),
                )
            ).all()
            return len(rows)

    def _new_record(self, card: QuizCard, is_review: bool) -> QuizRecord:
        """为卡片建一条今日作答记录"""
        record = QuizRecord(
            card_id=card.id,
            is_review=is_review,
            asked_date=self._today(),
        )
        with Session(engine) as session:
            session.add(record)
            session.commit()
            session.refresh(record)
        return record

    # ---- 对外接口 ----

    async def get_today(self, force_new: bool = False) -> dict:
        """获取今日题目。

        当日已作答过的场景（含晚上再打开/开机自检）：
        - force_new=False：直接返回当前状态，不再自动出新题、不再补齐领域题；
          已完成的返回完成态（前端不会再弹每日页），未答完的继续展示未答的题。
        - force_new=True（"再来一题"）：用户主动要求，才继续出复习卡/未答的新题。
        """
        record = self._get_today_record()
        if record and not force_new:
            if record.user_answer is None:
                if record.is_review:
                    # 复习题没答：范围不含就撤下今天的记录（复习卡留库等范围改回再出）
                    if not self._topic_in_scope(self._card_topic(record.card_id)):
                        logger.info(
                            "今日未答复习题超范围撤下 rec=%s card=%s topic=%s",
                            record.id, record.card_id, self._card_topic(record.card_id),
                        )
                        self._discard_unanswered()
                        record = None
                elif not self._topic_in_scope(self._card_topic(record.card_id)):
                    # 全新题没答：范围不含就当没出过，连卡带记录删掉
                    logger.info(
                        "今日未答新题超范围删除 rec=%s card=%s topic=%s",
                        record.id, record.card_id, self._card_topic(record.card_id),
                    )
                    self._discard_unanswered()
                    record = None
                if record is not None:
                    logger.info(
                        "get_today 复用今日记录 rec=%s 类型=%s 题目=%s",
                        record.id, "复习" if record.is_review else "新题", self._card_topic(record.card_id),
                    )
                    return self._build_state(record)
            elif record.resolved:
                logger.info(
                    "get_today 今日已完成 rec=%s 类型=%s 题目=%s",
                    record.id, "复习" if record.is_review else "新题", self._card_topic(record.card_id),
                )
                return self._build_state(record)
            else:
                # 已作答但决策弹窗没点：等用户处理完弹窗
                logger.info("get_today 有未处理弹窗 rec=%s，不出新题", record.id)
                return self._build_state(record)

        # 今天已经答过题，且用户没有主动"再来一题"：不再自动出任何题
        if self._has_answered_today() and not force_new:
            # 此时 record 可能是 None（今天未答的只剩超范围题被撤下），
            # 以最后一条已答记录作为"今日已完成"状态返回
            record = self._get_today_record()
            if record is not None:
                logger.info(
                    "get_today 今日已答过且非再来一题，返回完成态 rec=%s",
                    record.id,
                )
                return self._build_state(record)
            # 极端：有已答记录但取不到（超范围被清）→ 回到正常选题流程
        else:
            # 今天还没答过题（新的一天首次进入）
            # 上一题还有未完成的决策弹窗时，不允许出新题
            if record and not record.resolved:
                logger.info("get_today 有未处理弹窗 rec=%s，不出新题", record.id)
                return self._build_state(record)

        # 到这里：今天没答过题（首次进入）或用户主动 force_new
        # 优先到期复习卡，同时把范围里还没覆盖的领域各补一道新题，
        # 保证一轮下来范围里每个领域都有一道。展示的始终是到期复习题，
        # 补齐的新题留在今日记录里，用"再来一题"依次作答。
        card = self._pick_due_card()
        if card is not None:
            record = self._new_record(card, is_review=True)
            topics = self._uncovered_topics()
            for t in topics:
                new_card = await self._generate_new_card(topic=t)
                self._new_record(new_card, is_review=False)
            logger.info(
                "get_today 出新复习卡 card=%s topic=%s level=%s 到期=%s 当前待复习数=%s",
                card.id, card.topic, card.level, card.next_review_date, self.count_due(),
            )
            return self._build_state(record)

        if force_new:
            # "再来一题"：优先消化复习积压；没有积压就继续做今天还没答的新题
            pending = self._get_unanswered_new_today()
            if pending:
                return self._build_state(pending)
            if record:
                return self._build_state(record)
            logger.info("force_new 但没有任何待办，今天是新的一天或已清空")
            raise ValueError("没有到期的复习题")

        # 没有到期复习卡：清掉历史没回答过的题，按范围每个领域各出一道
        self._discard_unanswered()
        topics = self._uncovered_topics() or [self._pick_topic()]
        logger.info(
            "get_today 无到期复习卡，出%d道新题 topics=%s", len(topics), topics,
        )
        for t in topics:
            card = await self._generate_new_card(topic=t)
            self._new_record(card, is_review=False)
        record = self._get_today_record()
        return self._build_state(record)

    async def new_question(self) -> dict:
        """按当前设置领域立即出一道新题：不消耗到期复习卡，走原新题流程。

        用户在设置里改了领域想马上出题时用；艾宾浩斯复习排期完全不受影响，
        新题答完仍会弹窗问是否投入复习。
        """
        # 今天没回答的题：新题直接抛弃；复习题看新范围还包不包含它的领域——
        # 包含就保留（新题照出，复习题等答完新题后用"再来一题"继续答），
        # 不包含才丢掉今天的记录（复习卡本身保留，等范围改回时再出）。
        # 已作答但决策弹窗没点的仍要求先处理，否则卡片会悬在库里。
        record = self._get_today_record()
        if record and record.user_answer is None:
            keep_review = (
                record.is_review
                and self._topic_in_scope(self._card_topic(record.card_id))
            )
            if not keep_review:
                self._discard_unanswered()
        elif record and not record.resolved:
            raise ValueError("今天已作答的题还没点决策弹窗，先去每日页处理完再出新题")
        # 按范围出题：每个领域各出一道；今天已覆盖过的领域跳过，全覆盖则整轮再出
        topics = self._uncovered_topics() or self._split_topics(settings_service.get_quiz_topic())
        for t in topics:
            card = await self._generate_new_card(topic=t)
            self._new_record(card, is_review=False)
        record = self._get_today_record()
        return self._build_state(record)

    async def _generate_new_card(self, topic: str | None = None) -> QuizCard:
        topic = topic or self._pick_topic()
        recent = self._recent_questions()
        user_prompt = "领域：" + topic
        if recent:
            user_prompt += "\n近期已出过的题目（避免重复）：\n" + "\n".join(
                f"- {q}" for q in recent
            )
        data = await self.llm.ask_json(
            _GEN_SYSTEM.replace("{topic}", topic), user_prompt, temperature=0.3
        )
        question = (data.get("question") or "").strip() or f"请简述{topic}领域中的一个核心概念。"
        reference = (data.get("reference_answer") or "").strip()
        reference = await self._verify_answer(question, reference)

        card = QuizCard(topic=topic, question=question, reference_answer=reference, status="pending")
        with Session(engine) as session:
            session.add(card)
            session.commit()
            session.refresh(card)
        return card

    async def _verify_answer(self, question: str, reference: str) -> str:
        """双盲交叉验证参考答案：先让 AI 只看题目独立作答，再由终审对比两份答案定稿。
        任一环节失败都回退用原参考答案，保证出题不卡死。"""
        if not reference:
            return reference
        verify = await self.llm.ask_json(_VERIFY_SYSTEM, f"问题：{question}", temperature=0.3)
        independent = (verify.get("answer") or "").strip()
        if not independent:
            return reference
        merge = await self.llm.ask_json(
            _MERGE_SYSTEM,
            f"题目：{question}\n答案A：{reference}\n答案B：{independent}",
            temperature=0.2,
        )
        final = (merge.get("reference_answer") or "").strip()
        return final or reference

    async def answer(self, answer_text: str) -> dict:
        """提交今日题目的答案，AI 评估并自动处置（明确对错时）"""
        record = self._get_today_record()
        if record is None:
            raise ValueError("今日还没有题目")
        if record.user_answer is not None:
            return self._build_state(record)

        with Session(engine) as session:
            card = session.get(QuizCard, record.card_id)
            if card is None:
                raise ValueError("题目卡片不存在")

            data = await self.llm.ask_json(
                _EVAL_SYSTEM,
                f"题目：{card.question}\n参考答案：{card.reference_answer}\n用户回答：{answer_text}",
                temperature=0.3,
            )
            grade = data.get("grade")
            if grade not in ("correct", "wrong", "partial"):
                grade = "partial"
            feedback = (data.get("feedback") or "").strip() or "评估失败，请重试。"
            suggestion = (data.get("suggestion") or "").strip()

            record.user_answer = answer_text
            record.grade = grade
            record.feedback = feedback
            record.suggestion = suggestion

            if record.is_review:
                card.review_count += 1
                if grade == "correct":
                    card.correct_count += 1
                    if card.level >= MAX_LEVEL:
                        # 毕业考：最高级再答对，不自动毕业，等用户在弹窗里决定
                        pass
                    else:
                        card.level += 1
                        card.next_review_date = self._add_days(self._interval(card.level))
                        # 自动升级、没有决策弹窗，答完即算处理完成；
                        # 否则 resolved 恒为 False 会挡住当天“再来一题”继续清积压
                        record.resolved = True
                elif grade == "wrong":
                    # 答错只降一级，次日重问
                    card.level = max(1, card.level - 1)
                    card.next_review_date = self._add_days(1)
                    # 自动降级、没有决策弹窗，答完即算处理完成
                    record.resolved = True
                # partial：不自动升降级，等用户弹窗决策（resolved 保持 False）
            else:
                # 新题：等用户弹窗决定是否投入复习，暂不排期
                pass

            session.add(card)
            session.add(record)
            session.commit()
            session.refresh(record)
        return self._build_state(record)

    def resolve(self, decision: str) -> dict:
        """处理用户对决策弹窗按钮的选择。

        新题：join_review=投入轮回历练 / skip=秒了
        复习模糊题：decrease=再勤快些吧~ / increase=可以放松一些
        毕业考：reset=再次踏上轮回... / master=我已臻至化境！
        """
        record = self._get_today_record()
        if record is None or record.user_answer is None:
            raise ValueError("今日题目尚未作答")
        if record.resolved:
            return self._build_state(record)

        with Session(engine) as session:
            card = session.get(QuizCard, record.card_id)
            if card is None:
                raise ValueError("题目卡片不存在")

            if not record.is_review:
                if decision == "join_review":
                    card.status = "learning"
                    card.level = 1
                    card.next_review_date = self._add_days(INTERVALS[0])
                elif decision == "skip":
                    card.status = "mastered"
                else:
                    raise ValueError("未知决策")
            elif card.level >= MAX_LEVEL and record.grade == "correct":
                # 毕业考
                if decision == "reset":
                    card.level = 1
                    card.next_review_date = self._add_days(INTERVALS[0])
                elif decision == "master":
                    card.status = "mastered"
                else:
                    raise ValueError("未知决策")
            else:
                if decision == "decrease":
                    card.level = max(1, card.level - 1)
                    card.next_review_date = self._add_days(self._interval(card.level))
                elif decision == "increase":
                    card.level = min(MAX_LEVEL, card.level + 1)
                    card.next_review_date = self._add_days(self._interval(card.level))
                else:
                    raise ValueError("未知决策")

            record.resolved = True
            session.add(card)
            session.add(record)
            session.commit()
            session.refresh(record)
        return self._build_state(record)

    # ---- 状态组装 ----

    def _build_state(self, record: QuizRecord) -> dict:
        with Session(engine) as session:
            card = session.get(QuizCard, record.card_id)
            due_count = self.count_due()

        decision = None
        if record.user_answer is not None and not record.resolved:
            if not record.is_review:
                decision = "new_question"
            elif card.level >= MAX_LEVEL and record.grade == "correct":
                decision = "mastery_exam"
            elif record.grade == "partial":
                decision = "review_partial"

        return {
            "date": record.asked_date,
            "is_review": record.is_review,
            "card_id": card.id,
            "question": card.question,
            "topic": card.topic,
            "reference_answer": card.reference_answer,
            "level": card.level,
            "answered": record.user_answer is not None,
            "resolved": record.resolved,
            "user_answer": record.user_answer,
            "feedback": record.feedback,
            "suggestion": record.suggestion,
            "grade": record.grade,
            "is_mastery_exam": (decision == "mastery_exam"),
            "decision": decision,
            "due_count": due_count,
            "pending_new_count": self._count_pending_new_today(),
        }


quiz_service = QuizService()
