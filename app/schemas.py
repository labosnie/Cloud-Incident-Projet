from datetime import datetime

from pydantic import BaseModel, Field


class OrderCreate(BaseModel):
    customer_name: str = Field(..., min_length=1, max_length=120)
    product: str = Field(..., min_length=1, max_length=200)
    quantity: int = Field(..., ge=1, le=9999)


class OrderRead(BaseModel):
    id: int
    customer_name: str
    product: str
    quantity: int
    created_at: datetime

    model_config = {"from_attributes": True}
