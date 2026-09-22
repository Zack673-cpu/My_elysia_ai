"""统一日志配置：所有模块共用一份配置，控制台 + 单文件落盘（data/app.log）。

任何模块只需 `logger = logging.getLogger(__name__)`，
消息会同时输出到控制台和 app.log（日志行带模块名，便于按模块过滤排查）。
"""

import logging
import sys

from app.config import settings

# 防止反复调用 setup_logging 时重复挂 handler
_configured = False


def setup_logging() -> None:
    global _configured
    if _configured:
        return
    _configured = True

    fmt = logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")

    root = logging.getLogger()
    root.setLevel(logging.INFO)

    # 清掉 root 上已有的 handler（如 run.py 里的 basicConfig 或重复导入残留），
    # 统一用本配置挂载，避免控制台重复输出
    for handler in list(root.handlers):
        root.removeHandler(handler)

    # 控制台输出（开机自启等无终端场景也不影响）
    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(fmt)
    root.addHandler(console)

    # 统一落盘到 data/app.log，编码 utf-8（Windows 下避免中文乱码）
    file_handler = logging.FileHandler(
        settings.data_dir_path / "app.log", encoding="utf-8"
    )
    file_handler.setFormatter(fmt)
    root.addHandler(file_handler)

    # uvicorn 自己的日志（访问日志等）也并入同一文件
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        lg = logging.getLogger(name)
        lg.handlers.clear()
        lg.propagate = True


setup_logging()