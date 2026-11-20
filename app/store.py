from __future__ import annotations

import os
from dataclasses import asdict, dataclass
from threading import Lock
from typing import Protocol


@dataclass(frozen=True)
class TaskRecord:
    id: int
    title: str
    completed: bool = False

    def to_dict(self) -> dict[str, int | str | bool]:
        return asdict(self)


class TaskStore(Protocol):
    def ping(self) -> bool: ...

    def list_tasks(self) -> list[dict[str, int | str | bool]]: ...

    def create_task(self, title: str) -> dict[str, int | str | bool]: ...

    def update_task(self, task_id: int, completed: bool) -> dict[str, int | str | bool] | None: ...

    def delete_task(self, task_id: int) -> bool: ...


class MemoryTaskStore:
    """Thread-safe in-memory store used for tests and simple Docker runs."""

    def __init__(self) -> None:
        self._tasks: dict[int, TaskRecord] = {}
        self._next_id = 1
        self._lock = Lock()

    def ping(self) -> bool:
        return True

    def clear(self) -> None:
        with self._lock:
            self._tasks.clear()
            self._next_id = 1

    def list_tasks(self) -> list[dict[str, int | str | bool]]:
        with self._lock:
            return [self._tasks[key].to_dict() for key in sorted(self._tasks)]

    def create_task(self, title: str) -> dict[str, int | str | bool]:
        with self._lock:
            task = TaskRecord(id=self._next_id, title=title)
            self._tasks[task.id] = task
            self._next_id += 1
            return task.to_dict()

    def update_task(self, task_id: int, completed: bool) -> dict[str, int | str | bool] | None:
        with self._lock:
            current = self._tasks.get(task_id)
            if current is None:
                return None
            updated = TaskRecord(id=current.id, title=current.title, completed=completed)
            self._tasks[task_id] = updated
            return updated.to_dict()

    def delete_task(self, task_id: int) -> bool:
        with self._lock:
            return self._tasks.pop(task_id, None) is not None


class RedisTaskStore:
    """Redis-backed store shared by all application replicas."""

    def __init__(self) -> None:
        from redis import Redis

        self.client = Redis(
            host=os.getenv("REDIS_HOST", "redis"),
            port=int(os.getenv("REDIS_PORT", "6379")),
            db=int(os.getenv("REDIS_DB", "0")),
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
            health_check_interval=30,
        )

    @staticmethod
    def _key(task_id: int) -> str:
        return f"tasks:item:{task_id}"

    @staticmethod
    def _decode(raw: dict[str, str]) -> dict[str, int | str | bool]:
        return {
            "id": int(raw["id"]),
            "title": raw["title"],
            "completed": raw["completed"] == "1",
        }

    def ping(self) -> bool:
        return bool(self.client.ping())

    def list_tasks(self) -> list[dict[str, int | str | bool]]:
        ids = sorted(int(value) for value in self.client.smembers("tasks:ids"))
        if not ids:
            return []

        pipeline = self.client.pipeline(transaction=False)
        for task_id in ids:
            pipeline.hgetall(self._key(task_id))

        tasks: list[dict[str, int | str | bool]] = []
        for raw in pipeline.execute():
            if raw:
                tasks.append(self._decode(raw))
        return tasks

    def create_task(self, title: str) -> dict[str, int | str | bool]:
        task_id = int(self.client.incr("tasks:next_id"))
        task = {"id": task_id, "title": title, "completed": False}
        pipeline = self.client.pipeline(transaction=True)
        pipeline.hset(
            self._key(task_id),
            mapping={"id": task_id, "title": title, "completed": "0"},
        )
        pipeline.sadd("tasks:ids", task_id)
        pipeline.execute()
        return task

    def update_task(self, task_id: int, completed: bool) -> dict[str, int | str | bool] | None:
        key = self._key(task_id)
        raw = self.client.hgetall(key)
        if not raw:
            return None
        self.client.hset(key, mapping={"completed": "1" if completed else "0"})
        raw["completed"] = "1" if completed else "0"
        return self._decode(raw)

    def delete_task(self, task_id: int) -> bool:
        key = self._key(task_id)
        pipeline = self.client.pipeline(transaction=True)
        pipeline.delete(key)
        pipeline.srem("tasks:ids", task_id)
        deleted, _ = pipeline.execute()
        return bool(deleted)


def build_store() -> TaskStore:
    backend = os.getenv("STORE_BACKEND", "memory").strip().lower()
    if backend == "memory":
        return MemoryTaskStore()
    if backend == "redis":
        return RedisTaskStore()
    raise ValueError(f"Unsupported STORE_BACKEND: {backend!r}")
