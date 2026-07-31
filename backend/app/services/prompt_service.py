from app.prompts.base import UNIFIED_PSYCHOLOGY_PROMPT



# Demugo / Cryene / Elysia 是项目"开发阶段"代号，不是三个人格；AI 始终只扮演一个角色"昔涟"：
#   - Demugo：搭框架、跑通流程，纯原生模型，无角色提示词
#   - Cryene：加入提示词与智能体，让模型模仿昔涟的性格语调
#   - Elysia：远期自训练或接入特化模型，让昔涟性格内化进模型本身
# 三阶段区别的只是"实现昔涟"的技术手段，目前共用同一套统一提示词，暂不按阶段区分。


class PromptService:
    """系统提示词管理"""

    @staticmethod
    def get_prompt() -> str:
        return UNIFIED_PSYCHOLOGY_PROMPT
