import pytest
from fastapi.testclient import TestClient

from app.main import app, store

client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_memory_store() -> None:
    clear = getattr(store, "clear", None)
    if clear is not None:
        clear()


def test_health_and_metadata() -> None:
    assert client.get("/health/live").json() == {"status": "ok"}
    assert client.get("/health/ready").status_code == 200
    info = client.get("/api/info").json()
    assert info["application"] == "multi-cloud-task-api"
    assert info["store_backend"] == "memory"


def test_task_lifecycle() -> None:
    created = client.post("/api/tasks", json={"title": "Build container"})
    assert created.status_code == 201
    assert created.json() == {"id": 1, "title": "Build container", "completed": False}

    listed = client.get("/api/tasks")
    assert listed.json() == [created.json()]

    updated = client.patch("/api/tasks/1", json={"completed": True})
    assert updated.status_code == 200
    assert updated.json()["completed"] is True

    deleted = client.delete("/api/tasks/1")
    assert deleted.status_code == 204
    assert client.get("/api/tasks").json() == []


def test_validation_and_not_found() -> None:
    assert client.post("/api/tasks", json={"title": "   "}).status_code == 422
    assert client.patch("/api/tasks/999", json={"completed": True}).status_code == 404
    assert client.delete("/api/tasks/999").status_code == 404
