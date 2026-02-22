from datetime import date

import httpx
from fastapi import HTTPException, status

NAGER_BASE = "https://date.nager.at/api/v3"


def _get(url: str) -> list:
    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(url)
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No data found at {url}",
            )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to fetch from public holidays service",
        )
    except httpx.RequestError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not reach the public holidays service",
        )


def fetch_public_holidays_detailed(year: int, country_code: str) -> list[dict]:
    """Return full holiday objects (date, name, localName) from Nager.Date."""
    data = _get(f"{NAGER_BASE}/PublicHolidays/{year}/{country_code}")
    return [
        {
            "date": h["date"],
            "name": h["name"],
            "local_name": h["localName"],
        }
        for h in data
    ]


def fetch_public_holidays(year: int, country_code: str) -> set[date]:
    """Return just the holiday dates — used internally by the dashboard computation."""
    data = _get(f"{NAGER_BASE}/PublicHolidays/{year}/{country_code}")
    return {date.fromisoformat(h["date"]) for h in data}


def fetch_available_countries() -> list[dict]:
    """Return the list of countries supported by Nager.Date."""
    data = _get(f"{NAGER_BASE}/AvailableCountries")
    return [{"country_code": c["countryCode"], "name": c["name"]} for c in data]
