from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, File, UploadFile, status
from supabase import Client

from app.db.supabase import get_supabase_admin
from app.dependencies import get_current_user
from app.models.receipts import ReceiptDateUpdate
from app.services import receipts as receipts_service

router = APIRouter()


@router.post("/upload", status_code=status.HTTP_201_CREATED)
def upload_receipt(
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    return receipts_service.upload_receipt(supabase, str(current_user.id), file)


@router.get("/")
def list_receipts(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    return receipts_service.list_receipts(supabase, str(current_user.id), start_date, end_date)


@router.get("/{receipt_id}")
def get_receipt(
    receipt_id: str,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    return receipts_service.get_receipt(supabase, str(current_user.id), receipt_id)


@router.put("/{receipt_id}/date")
def update_receipt_date(
    receipt_id: str,
    body: ReceiptDateUpdate,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    return receipts_service.update_receipt_date(supabase, str(current_user.id), receipt_id, body.receipt_date)


@router.delete("/{receipt_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_receipt(
    receipt_id: str,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    receipts_service.delete_receipt(supabase, str(current_user.id), receipt_id)
