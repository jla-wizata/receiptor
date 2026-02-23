from datetime import date, timedelta


def _date_range(start: date, end: date):
    d = start
    while d <= end:
        yield d
        d += timedelta(days=1)


def expand_holiday_periods(periods: list[dict]) -> set[date]:
    """Flatten a list of {start_date, end_date} dicts into a set of individual dates."""
    dates: set[date] = set()
    for p in periods:
        start = date.fromisoformat(p["start_date"]) if isinstance(p["start_date"], str) else p["start_date"]
        end = date.fromisoformat(p["end_date"]) if isinstance(p["end_date"], str) else p["end_date"]
        for d in _date_range(start, end):
            dates.add(d)
    return dates


def _parse_periods(raw: list[dict]) -> list[tuple[date, date | None, set[int]]]:
    """Parse and sort schedule periods by start_date descending (most recent first)."""
    result = []
    for p in raw:
        start = date.fromisoformat(p["start_date"]) if isinstance(p["start_date"], str) else p["start_date"]
        end_raw = p.get("end_date")
        end = (date.fromisoformat(end_raw) if isinstance(end_raw, str) else end_raw) if end_raw else None
        result.append((start, end, set(p["working_days"])))
    return sorted(result, key=lambda x: x[0], reverse=True)


def _weekdays_for_date(d: date, periods: list[tuple], default: set[int]) -> set[int]:
    """Return the applicable working weekdays for a given date."""
    for start, end, weekdays in periods:
        if d >= start and (end is None or d <= end):
            return weekdays
    return default


def compute_summary(
    year: int,
    receipt_dates: set[date],
    public_holidays: set[date],
    user_holiday_dates: set[date],
    threshold: int,
    working_country_code: str,
    working_days: list[int] | None = None,
    schedule_periods: list[dict] | None = None,
) -> dict:
    today = date.today()
    year_start = date(year, 1, 1)
    year_end = date(year, 12, 31)

    default_weekdays = set(working_days) if working_days else {0, 1, 2, 3, 4}
    parsed_periods = _parse_periods(schedule_periods or [])

    all_working_days = {
        d for d in _date_range(year_start, year_end)
        if d.weekday() in _weekdays_for_date(d, parsed_periods, default_weekdays)
        and d not in public_holidays
        and d not in user_holiday_dates
    }

    past_working_days = {d for d in all_working_days if d <= today}
    future_working_days = all_working_days - past_working_days

    proved_days = receipt_dates & past_working_days
    homeworking_so_far = len(past_working_days) - len(proved_days)

    # Project the current home-working rate over remaining working days
    rate = homeworking_so_far / len(past_working_days) if past_working_days else 0.0
    projected = round(rate * len(future_working_days))
    forecast = homeworking_so_far + projected

    at_risk = forecast > threshold
    return {
        "year": year,
        "working_country_code": working_country_code,
        "homeworking_threshold": threshold,
        "total_working_days": len(all_working_days),
        "past_working_days": len(past_working_days),
        "days_with_proof": len(proved_days),
        "days_without_proof": homeworking_so_far,
        "forecast_homeworking_days": forecast,
        "forecasted_days_without_proof": forecast,
        "remaining_allowed_homeworking_days": max(0, threshold - homeworking_so_far),
        "is_at_risk": at_risk,
        "compliance_status": "at_risk" if at_risk else "compliant",
    }
