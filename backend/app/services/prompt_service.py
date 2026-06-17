from app.prompts.base import UNIFIED_PSYCHOLOGY_PROMPT


# 所有阶段共用同一套最强提示词
# 阶段演进路线：Demugo（当前）→ Cryene（加入 skill 文档后）→ Elysia（完整形态）
# 目前三个阶段都使用统一的最强提示词
STAGE_PROMPTS = {
    "demugo": UNIFIED_PSYCHOLOGY_PROMPT,
    "cryene": UNIFIED_PSYCHOLOGY_PROMPT,
    "elysia": UNIFIED_PSYCHOLOGY_PROMPT,
}


class PromptService:
    """系统提示词管理，根据阶段返回对应提示词"""

    @staticmethod
    def get_prompt(stage: str) -> str:
        stage = stage.lower()
        if stage not in STAGE_PROMPTS:
            raise ValueError(f"未知阶段: {stage}，可选: {list(STAGE_PROMPTS.keys())}")
        return STAGE_PROMPTS[stage]

    @staticmethod
    def list_stages() -> list[str]:
        return list(STAGE_PROMPTS.keys())
