import logging
import uuid
from datetime import date
from typing import Optional

from fastapi import HTTPException, UploadFile, status
from supabase import Client

from app.services.ocr import extract_date_from_image

logger = logging.getLogger(__name__)

BUCKET = "receipts"
SIGNED_URL_EXPIRY = 3600  # seconds


def upload_receipt(
    supabase: Client,
    user_id: str,
    file: UploadFile,
) -> dict:
    image_bytes = file.file.read()
    receipt_date, ocr_status = _run_ocr(image_bytes)

    receipt_id = str(uuid.uuid4())
    ext = _extension(file.content_type)
    storage_path = f"{user_id}/{receipt_id}{ext}"

    supabase.storage.from_(BUCKET).upload(
        path=storage_path,
        file=image_bytes,
        file_options={"content-type": file.content_type or "application/octet-stream"},
    )

    row = {
        "id": receipt_id,
        "user_id": user_id,
        "receipt_date": receipt_date.isoformat() if receipt_date else None,
        "ocr_status": ocr_status,
        "storage_path": storage_path,
        "notes": None,
    }
    result = supabase.table("receipts").insert(row).execute()
    record = result.data[0]
    record["image_url"] = _signed_url(supabase, storage_path)
    record["ocr_status"] = ocr_status
    return record


def list_receipts(
    supabase: Client,
    user_id: str,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
) -> dict:
    query = (
        supabase.table("receipts")
        .select("*")
        .eq("user_id", user_id)
        .order("receipt_date", desc=True)
    )
    if start_date:
        query = query.gte("receipt_date", start_date.isoformat())
    if end_date:
        query = query.lte("receipt_date", end_date.isoformat())

    result = query.execute()
    rows = result.data
    for row in rows:
        row["image_url"] = _signed_url(supabase, row["storage_path"])

    return {"receipts": rows, "total": len(rows)}


def get_receipt(supabase: Client, user_id: str, receipt_id: str) -> dict:
    result = (
        supabase.table("receipts")
        .select("*")
        .eq("id", receipt_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receipt not found")
    row = result.data[0]
    row["image_url"] = _signed_url(supabase, row["storage_path"])
    return row


def update_receipt_date(supabase: Client, user_id: str, receipt_id: str, receipt_date: date) -> dict:
    result = (
        supabase.table("receipts")
        .update({"receipt_date": receipt_date.isoformat(), "ocr_status": "manual"})
        .eq("id", receipt_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receipt not found")
    row = result.data[0]
    row["image_url"] = _signed_url(supabase, row["storage_path"])
    return row


def delete_receipt(supabase: Client, user_id: str, receipt_id: str) -> None:
    result = (
        supabase.table("receipts")
        .select("storage_path")
        .eq("id", receipt_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receipt not found")

    storage_path = result.data[0]["storage_path"]
    # Delete storage first — if this fails the DB row is still intact
    try:
        supabase.storage.from_(BUCKET).remove([storage_path])
    except Exception as e:
        logger.error("Failed to delete storage file %s: %s", storage_path, e)
    supabase.table("receipts").delete().eq("id", receipt_id).eq("user_id", user_id).execute()


def _signed_url(supabase: Client, storage_path: str) -> str:
    response = supabase.storage.from_(BUCKET).create_signed_url(storage_path, SIGNED_URL_EXPIRY)
    return response["signedUrl"]


def _run_ocr(image_bytes: bytes) -> tuple[Optional[date], str]:
    """
    Attempt OCR date extraction. Always succeeds — returns (date, status).
    Status values: "success" | "no_date_found" | "failed"
    """
    try:
        extracted = extract_date_from_image(image_bytes)
        if extracted:
            return extracted, "success"
        return None, "no_date_found"
    except Exception as e:
        logger.exception("OCR failed: %s", e)
        return None, "failed"


def _extension(content_type: Optional[str]) -> str:
    return {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "application/pdf": ".pdf",
    }.get(content_type or "", ".jpg")  # default .jpg — iOS always sends JPEG
