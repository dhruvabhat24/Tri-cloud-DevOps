from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, HTTPException, Response, status
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field

from app.store import build_store

BASE_DIR = Path(__file__).resolve().parent

app = FastAPI(
    title="Multi-Cloud Task API",
    version=os.getenv("APP_VERSION", "dev"),
    docs_url="/docs",
    redoc_url=None,
)
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")

store = build_store()


class TaskCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    title: str = Field(min_length=1, max_length=120)


class TaskUpdate(BaseModel):
    completed: bool


class Task(BaseModel):
    id: int
    title: str
    completed: bool


@app.get("/", include_in_schema=False)
def index() -> FileResponse:
    return FileResponse(BASE_DIR / "static" / "index.html")


@app.get("/health/live", tags=["health"])
def liveness() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/ready", tags=["health"])
def readiness() -> dict[str, str]:
    try:
        if store.ping():
            return {"status": "ready"}
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Backing store is unavailable") from exc
    raise HTTPException(status_code=503, detail="Backing store is unavailable")


@app.get("/api/info", tags=["metadata"])
def info() -> dict[str, str]:
    return {
        "application": "multi-cloud-task-api",
        "version": os.getenv("APP_VERSION", "dev"),
        "deployment_target": os.getenv("DEPLOYMENT_TARGET", "local"),
        "store_backend": os.getenv("STORE_BACKEND", "memory"),
    }


@app.get("/api/tasks", response_model=list[Task], tags=["tasks"])
def list_tasks() -> list[dict[str, int | str | bool]]:
    return store.list_tasks()


@app.post(
    "/api/tasks",
    response_model=Task,
    status_code=status.HTTP_201_CREATED,
    tags=["tasks"],
)
def create_task(payload: TaskCreate) -> dict[str, int | str | bool]:
    return store.create_task(payload.title)


@app.patch("/api/tasks/{task_id}", response_model=Task, tags=["tasks"])
def update_task(task_id: int, payload: TaskUpdate) -> dict[str, int | str | bool]:
    task = store.update_task(task_id, payload.completed)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@app.delete(
    "/api/tasks/{task_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["tasks"],
)
def delete_task(task_id: int) -> Response:
    if not store.delete_task(task_id):
        raise HTTPException(status_code=404, detail="Task not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
