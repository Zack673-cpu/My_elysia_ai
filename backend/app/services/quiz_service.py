from datetime import date, timedelta
from sqlmodel import Session, select
from app.db import engine
from app.models.db_models import QuizCard, QuizRecord
from app.services.llm_service import LLMService
from app.services.settings_service import settings_service


# 艾宾浩斯间隔梯度（自然日）：level 1~7 对应 1,2,4,7,15,30,90 天
INTERVALS = [1, 2, 4, 7, 15, 30, 90]
MAX_LEVEL = len(INTERVALS)

_GEN_SYSTEM = """你是一个专业出题官。在「{topic}」领域出一道专业问答题。
要求：
1. 难度适中，普通相关专业学生能在两分钟内口头答完
2. 概念清晰、答案明确，不要出开放式的论述题
3. 不要与给出的近期题目重复或高度相似
只输出 JSON：{"question": "题目", "reference_answer": "参考答案，不超过三句话"}"""

_EVAL_SYSTEM = """你是一个严谨的答题评估官。根据题目和参考答案评估用户的回答。
你的反馈将以「昔涟」的口吻呈现：温柔、体贴、多鼓励少指责，即使答错了也要委婉柔和地指出，不打击用户积极性。
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
        """当前到期（含积压）的复习卡数量"""
        with Session(engine) as session:
            cards = session.exec(
                select(QuizCard).where(
                    QuizCard.status == "learning",
                    QuizCard.next_review_date <= self._today(),
                )
            ).all()
            return len(cards)

    def _pick_due_card(self) -> QuizCard | None:
        """取一张到期复习卡：优先逾期天数多的，同级取早创建的"""
        with Session(engine) as session:
            card = session.exec(
                select(QuizCard)
                .where(
                    QuizCard.status == "learning",
                    QuizCard.next_review_date <= self._today(),
                )
                .order_by(QuizCard.next_review_date, QuizCard.id)
            ).first()
            return card

    def _get_today_record(self) -> QuizRecord | None:
        """今日最新一条作答记录（"再来一题"支持一天多题，取最新的）"""
        with Session(engine) as session:
            return session.exec(
                select(QuizRecord)
                .where(QuizRecord.asked_date == self._today())
                .order_by(QuizRecord.id.desc())
            ).first()

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

    # ---- 对外接口 ----

    async def get_today(self, force_new: bool = False) -> dict:
        """获取今日题目。优先复习到期卡，无到期卡才出新题。

        force_new=True 用于"再来一题"：积压未消化完时继续按逾期优先出复习题。
        """
        record = self._get_today_record()
        if record and not force_new:
            return self._build_state(record)

        # 上一题还有未完成的决策弹窗时，不允许出新题
        if record and not record.resolved:
            return self._build_state(record)

        card = self._pick_due_card()
        is_review = card is not None
        if card is None:
            if force_new:
                # "再来一题"仅用于消化积压，没有到期卡就不重复出题
                if record:
                    return self._build_state(record)
                raise ValueError("没有到期的复习题")
            card = await self._generate_new_card()

        record = QuizRecord(
            card_id=card.id,
            is_review=is_review,
            asked_date=self._today(),
        )
        with Session(engine) as session:
            session.add(record)
            session.commit()
            session.refresh(record)
        return self._build_state(record)

    async def _generate_new_card(self) -> QuizCard:
        topic = settings_service.get_quiz_topic()
        recent = self._recent_questions()
        user_prompt = "领域：" + topic
        if recent:
            user_prompt += "\n近期已出过的题目（避免重复）：\n" + "\n".join(
                f"- {q}" for q in recent
            )
        data = await self.llm.ask_json(_GEN_SYSTEM.replace("{topic}", topic), user_prompt)
        question = (data.get("question") or "").strip() or f"请简述{topic}领域中的一个核心概念。"
        reference = (data.get("reference_answer") or "").strip()

        card = QuizCard(topic=topic, question=question, reference_answer=reference, status="pending")
        with Session(engine) as session:
            session.add(card)
            session.commit()
            session.refresh(card)
        return card

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
                elif grade == "wrong":
                    # 答错只降一级，次日重问
                    card.level = max(1, card.level - 1)
                    card.next_review_date = self._add_days(1)
                # partial：不自动升降级，等用户弹窗决策
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
        }


quiz_service = QuizService()
