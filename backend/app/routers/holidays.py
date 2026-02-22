from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends
from supabase import Client

from app.db.supabase import get_supabase_admin
from app.dependencies import get_current_user
from app.models.holidays import AvailableCountry, PublicHoliday
from app.services.nager import fetch_available_countries, fetch_public_holidays_detailed

router = APIRouter()

_DEFAULT_COUNTRY = "LU"


@router.get("", response_model=list[PublicHoliday])
def get_public_holidays(
    year: int = date.today().year,
    country: Optional[str] = None,
    current_user=Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    """
    Return public holidays for a given year.
    Defaults to the user's configured working country; override with ?country=XX.
    """
    if country is None:
        result = (
            supabase.table("user_settings")
            .select("working_country_code")
            .eq("user_id", str(current_user.id))
            .execute()
        )
        country = result.data[0]["working_country_code"] if result.data else _DEFAULT_COUNTRY

    return fetch_public_holidays_detailed(year, country)


@router.get("/countries", response_model=list[AvailableCountry])
def get_available_countries():
    """Return all countries supported by the Nager.Date public holidays API."""
    return fetch_available_countries()
