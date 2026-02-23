from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, status
from supabase import Client

from app.db.supabase import get_supabase_admin
from app.dependencies import get_current_user
from app.models.dashboard import (
    DashboardSummary, UserHolidayIn, UserHolidayOut, UserSettings, UserSettingsUpdate,
    WorkSchedulePeriodIn, WorkSchedulePeriodOut,
)
from app.services import dashboard as dashboard_service
from app.services.nager import fetch_public_holidays

router = APIRouter()

# ---------------------------------------------------------------------------
# Default settings used when a user hasn't configured their profile yet
# ---------------------------------------------------------------------------
_DEFAULTS = {
    "working_country_code": "LU",
    "residence_country_code": "BE",
    "homeworking_threshold": 34,
    "working_days": [0, 1, 2, 3, 4],
}


# ---------------------------------------------------------------------------
# Main dashboard summary
# ---------------------------------------------------------------------------

@router.get("", response_model=DashboardSummary)
def get_summary(
    year: int = date.today().year,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    user_id = str(current_user.id)

    # User settings (fall back to defaults if not configured)
    settings_row = (
        supabase.table("user_settings").select("*").eq("user_id", user_id).execute()
    )
    settings = settings_row.data[0] if settings_row.data else {**_DEFAULTS, "user_id": user_id}

    # Receipts for the year
    receipts = (
        supabase.table("receipts")
        .select("receipt_date")
        .eq("user_id", user_id)
        .gte("receipt_date", date(year, 1, 1).isoformat())
        .lte("receipt_date", date(year, 12, 31).isoformat())
        .execute()
    )
    receipt_dates = {
        date.fromisoformat(r["receipt_date"])
        for r in receipts.data
        if r["receipt_date"]
    }

    # Public holidays for the working country
    public_holidays = fetch_public_holidays(year, settings["working_country_code"])

    # User-defined holiday periods
    holidays = (
        supabase.table("user_holidays")
        .select("start_date,end_date")
        .eq("user_id", user_id)
        .execute()
    )
    user_holiday_dates = dashboard_service.expand_holiday_periods(holidays.data)

    # Work schedule periods
    schedule_periods = (
        supabase.table("work_schedule_periods")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    ).data

    return dashboard_service.compute_summary(
        year=year,
        receipt_dates=receipt_dates,
        public_holidays=public_holidays,
        user_holiday_dates=user_holiday_dates,
        threshold=settings["homeworking_threshold"],
        working_country_code=settings["working_country_code"],
        working_days=settings.get("working_days"),
        schedule_periods=schedule_periods,
    )


# ---------------------------------------------------------------------------
# User settings
# ---------------------------------------------------------------------------

@router.get("/settings", response_model=UserSettings)
def get_settings(
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    user_id = str(current_user.id)
    result = supabase.table("user_settings").select("*").eq("user_id", user_id).execute()
    if not result.data:
        return {**_DEFAULTS, "user_id": user_id}
    return result.data[0]


@router.put("/settings", response_model=UserSettings)
def update_settings(
    body: UserSettingsUpdate,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    user_id = str(current_user.id)

    # Build update payload from non-null fields only
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    payload["user_id"] = user_id

    result = (
        supabase.table("user_settings")
        .upsert(payload, on_conflict="user_id")
        .execute()
    )
    return result.data[0]


# ---------------------------------------------------------------------------
# User-defined holiday periods
# ---------------------------------------------------------------------------

@router.get("/holidays", response_model=list[UserHolidayOut])
def list_holidays(
    year: Optional[int] = None,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    user_id = str(current_user.id)
    query = (
        supabase.table("user_holidays")
        .select("*")
        .eq("user_id", user_id)
        .order("start_date")
    )
    if year:
        query = query.gte("start_date", date(year, 1, 1).isoformat()).lte("end_date", date(year, 12, 31).isoformat())

    return query.execute().data


@router.post("/holidays", response_model=UserHolidayOut, status_code=status.HTTP_201_CREATED)
def create_holiday(
    body: UserHolidayIn,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    user_id = str(current_user.id)
    row = {
        "user_id": user_id,
        "start_date": body.start_date.isoformat(),
        "end_date": body.end_date.isoformat(),
        "description": body.description,
    }
    result = supabase.table("user_holidays").insert(row).execute()
    return result.data[0]


@router.put("/holidays/{holiday_id}", response_model=UserHolidayOut)
def update_holiday(
    holiday_id: str,
    body: UserHolidayIn,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    row = {
        "start_date": body.start_date.isoformat(),
        "end_date": body.end_date.isoformat(),
        "description": body.description,
    }
    from fastapi import HTTPException
    result = (
        supabase.table("user_holidays")
        .update(row)
        .eq("id", holiday_id)
        .eq("user_id", str(current_user.id))
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Holiday not found")
    return result.data[0]


@router.delete("/holidays/{holiday_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_holiday(
    holiday_id: str,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    user_id = str(current_user.id)
    supabase.table("user_holidays").delete().eq("id", holiday_id).eq("user_id", user_id).execute()


# ---------------------------------------------------------------------------
# Work schedule periods (time-bounded regime overrides)
# ---------------------------------------------------------------------------

@router.get("/schedule", response_model=list[WorkSchedulePeriodOut])
def list_schedule_periods(
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    return (
        supabase.table("work_schedule_periods")
        .select("*")
        .eq("user_id", str(current_user.id))
        .order("start_date")
        .execute()
    ).data


@router.post("/schedule", response_model=WorkSchedulePeriodOut, status_code=status.HTTP_201_CREATED)
def create_schedule_period(
    body: WorkSchedulePeriodIn,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    row = {
        "user_id": str(current_user.id),
        "start_date": body.start_date.isoformat(),
        "end_date": body.end_date.isoformat() if body.end_date else None,
        "working_days": body.working_days,
        "description": body.description,
    }
    return supabase.table("work_schedule_periods").insert(row).execute().data[0]


@router.put("/schedule/{period_id}", response_model=WorkSchedulePeriodOut)
def update_schedule_period(
    period_id: str,
    body: WorkSchedulePeriodIn,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    row = {
        "start_date": body.start_date.isoformat(),
        "end_date": body.end_date.isoformat() if body.end_date else None,
        "working_days": body.working_days,
        "description": body.description,
    }
    result = (
        supabase.table("work_schedule_periods")
        .update(row)
        .eq("id", period_id)
        .eq("user_id", str(current_user.id))
        .execute()
    )
    if not result.data:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Schedule period not found")
    return result.data[0]


@router.delete("/schedule/{period_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_schedule_period(
    period_id: str,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    supabase.table("work_schedule_periods").delete().eq("id", period_id).eq("user_id", str(current_user.id)).execute()
