import os

# Base SQLite en mémoire pour les tests (avant tout import app.*)
os.environ["TESTING"] = "1"

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client
