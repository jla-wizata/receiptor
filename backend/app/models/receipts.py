from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel


class ReceiptOut(BaseModel):
    id: UUID
    user_id: UUID
    receipt_date: Optional[date]
    ocr_status: str   # success | no_date_found | failed | skipped | manual
    storage_path: str
    image_url: str
    notes: Optional[str]
    created_at: datetime


class ReceiptDateUpdate(BaseModel):
    receipt_date: date


class ReceiptListResponse(BaseModel):
    receipts: list[ReceiptOut]
    total: int
