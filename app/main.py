import asyncio
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import Base, engine, get_db
from app.models import Order
from app.schemas import OrderCreate, OrderRead


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="CloudOps Incident Platform",
    description="API de démo pour incidents et observabilité (portfolio).",
    lifespan=lifespan,
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/orders", response_model=list[OrderRead])
def list_orders(db: Session = Depends(get_db)):
    stmt = select(Order).order_by(Order.id.asc())
    return list(db.scalars(stmt))


@app.post("/api/orders", response_model=OrderRead, status_code=201)
def create_order(payload: OrderCreate, db: Session = Depends(get_db)):
    order = Order(
        customer_name=payload.customer_name,
        product=payload.product,
        quantity=payload.quantity,
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return order


@app.get("/api/error")
def simulated_error():
    raise HTTPException(
        status_code=500,
        detail="Erreur serveur simulée pour tests d’alerting.",
    )


@app.get("/api/slow")
async def simulated_slowness():
    await asyncio.sleep(5)
    return {"message": "Réponse après latence simulée (5 s)."}
