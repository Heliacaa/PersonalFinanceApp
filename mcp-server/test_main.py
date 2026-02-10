import pytest
from fastapi.testclient import TestClient
from main import app

@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c

def test_read_root(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "sentix-mcp-server"}

def test_analyze_sentiment(client):
    response = client.post(
        "/analyze-sentiment",
        json={"text": "I love this stock, it is going to the moon!"}
    )
    assert response.status_code == 200
    assert response.json()["sentiment"] == "BULLISH"
