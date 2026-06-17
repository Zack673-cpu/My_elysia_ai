import json
from pathlib import Path
from typing import Any, Optional
from filelock import FileLock


class JsonStore:
    """JSON 文件原子读写存储，使用 filelock 防止并发写入"""

    def __init__(self, base_dir: Path):
        self.base_dir = base_dir
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _get_file_path(self, key: str) -> Path:
        return self.base_dir / f"{key}.json"

    def _get_lock_path(self, key: str) -> Path:
        return self.base_dir / f"{key}.lock"

    def read(self, key: str) -> Optional[dict[str, Any]]:
        """读取 JSON 文件，不存在则返回 None"""
        file_path = self._get_file_path(key)
        lock = FileLock(str(self._get_lock_path(key)))
        with lock:
            if not file_path.exists():
                return None
            with open(file_path, "r", encoding="utf-8") as f:
                return json.load(f)

    def write(self, key: str, data: dict[str, Any]) -> None:
        """原子写入 JSON 文件"""
        file_path = self._get_file_path(key)
        lock = FileLock(str(self._get_lock_path(key)))
        with lock:
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2, default=str)

    def delete(self, key: str) -> bool:
        """删除 JSON 文件，返回是否成功删除"""
        file_path = self._get_file_path(key)
        lock_path = self._get_lock_path(key)
        lock = FileLock(str(lock_path))
        with lock:
            if file_path.exists():
                file_path.unlink()
                return True
            return False

    def list_keys(self) -> list[str]:
        """列出所有存储的 key"""
        return [f.stem for f in self.base_dir.glob("*.json")]

    def exists(self, key: str) -> bool:
        return self._get_file_path(key).exists()
