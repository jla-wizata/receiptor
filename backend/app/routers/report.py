from datetime import date

from fastapi import APIRouter, Depends
from fastapi.responses import Response
from supabase import Client

from app.db.supabase import get_supabase_admin
from app.dependencies import get_current_user
from app.services import dashboard as dashboard_service
from app.services.nager import fetch_public_holidays, fetch_public_holidays_detailed
from app.services.pdf import REPORT_SIGNED_URL_EXPIRY, generate_compliance_report

router = APIRouter()

_DEFAULTS = {
    "working_country_code": "LU",
    "residence_country_code": "BE",
    "homeworking_threshold": 34,
    "working_days": [0, 1, 2, 3, 4],
}


@router.get("")
def get_compliance_report(
    year: int = date.today().year,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    user_id = str(current_user.id)
    user_email = current_user.email or user_id

    # User settings
    settings_row = supabase.table("user_settings").select("*").eq("user_id", user_id).execute()
    settings = settings_row.data[0] if settings_row.data else {**_DEFAULTS, "user_id": user_id}

    # Receipts for the year with long-lived signed URLs
    receipts_result = (
        supabase.table("receipts")
        .select("*")
        .eq("user_id", user_id)
        .gte("receipt_date", date(year, 1, 1).isoformat())
        .lte("receipt_date", date(year, 12, 31).isoformat())
        .order("receipt_date")
        .execute()
    )
    receipts = receipts_result.data
    for r in receipts:
        signed = supabase.storage.from_("receipts").create_signed_url(
            r["storage_path"], REPORT_SIGNED_URL_EXPIRY
        )
        r["image_url"] = signed["signedUrl"]

    # Public holidays (dates for computation + detailed for the report)
    public_holidays_dates = fetch_public_holidays(year, settings["working_country_code"])
    public_holidays_detailed = fetch_public_holidays_detailed(year, settings["working_country_code"])

    # User-defined holidays
    user_holidays = (
        supabase.table("user_holidays")
        .select("*")
        .eq("user_id", user_id)
        .order("start_date")
        .execute()
    ).data

    user_holiday_dates = dashboard_service.expand_holiday_periods(user_holidays)

    # Work schedule periods
    schedule_periods = (
        supabase.table("work_schedule_periods")
        .select("*")
        .eq("user_id", user_id)
        .order("start_date")
        .execute()
    ).data

    # Compliance summary
    receipt_dates = {
        date.fromisoformat(r["receipt_date"])
        for r in receipts
        if r.get("receipt_date")
    }
    summary = dashboard_service.compute_summary(
        year=year,
        receipt_dates=receipt_dates,
        public_holidays=public_holidays_dates,
        user_holiday_dates=user_holiday_dates,
        threshold=settings["homeworking_threshold"],
        working_country_code=settings["working_country_code"],
        working_days=settings.get("working_days"),
        schedule_periods=schedule_periods,
    )

    pdf_bytes = generate_compliance_report(
        user_email=user_email,
        year=year,
        summary=summary,
        receipts=receipts,
        public_holidays=public_holidays_detailed,
        user_holidays=user_holidays,
        schedule_periods=schedule_periods,
    )

    filename = f"compliance_report_{year}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
