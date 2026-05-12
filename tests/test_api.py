import asyncio


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_order_validation_error(client):
    response = client.post(
        "/api/orders",
        json={"customer_name": "", "product": "X", "quantity": 0},
    )
    assert response.status_code == 422


def test_orders_crud(client):
    response = client.get("/api/orders")
    assert response.status_code == 200
    assert response.json() == []

    response = client.post(
        "/api/orders",
        json={
            "customer_name": "Alice",
            "product": "Widget",
            "quantity": 2,
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["customer_name"] == "Alice"
    assert body["product"] == "Widget"
    assert body["quantity"] == 2
    assert "id" in body

    response = client.get("/api/orders")
    assert response.status_code == 200
    orders = response.json()
    assert len(orders) == 1
    assert orders[0]["customer_name"] == "Alice"


def test_simulated_error(client):
    response = client.get("/api/error")
    assert response.status_code == 500


def test_simulated_slow(client, monkeypatch):
    async def instant_sleep(_seconds: float):
        return None

    monkeypatch.setattr(asyncio, "sleep", instant_sleep)

    response = client.get("/api/slow")
    assert response.status_code == 200
    assert "message" in response.json()
