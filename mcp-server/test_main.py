from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "sentix-mcp-server"}

def test_analyze_sentiment():
    response = client.post(
        "/analyze-sentiment",
        json={"text": "I love this stock, it is going to the moon!"}
    )
    assert response.status_code == 200
    assert response.json()["sentiment"] == "BULLISH"
