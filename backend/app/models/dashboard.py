from datetime import date
from typing import Optional
from uuid import UUID

from pydantic import BaseModel


class UserSettings(BaseModel):
    user_id: UUID
    working_country_code: str
    residence_country_code: str
    homeworking_threshold: int
    working_days: list[int]   # weekday numbers: 0=Mon … 4=Fri


class UserSettingsUpdate(BaseModel):
    working_country_code: Optional[str] = None
    residence_country_code: Optional[str] = None
    homeworking_threshold: Optional[int] = None
    working_days: Optional[list[int]] = None


class WorkSchedulePeriodIn(BaseModel):
    start_date: date
    end_date: Optional[date] = None  # null = open-ended
    working_days: list[int]          # [] = full leave, [0,1,2,3] = Mon–Thu, etc.
    description: Optional[str] = None


class WorkSchedulePeriodOut(BaseModel):
    id: UUID
    user_id: UUID
    start_date: date
    end_date: Optional[date]
    working_days: list[int]
    description: Optional[str]


class UserHolidayIn(BaseModel):
    start_date: date
    end_date: date
    description: Optional[str] = None


class UserHolidayOut(BaseModel):
    id: UUID
    user_id: UUID
    start_date: date
    end_date: date
    description: Optional[str]


class DashboardSummary(BaseModel):
    year: int
    working_country_code: str
    homeworking_threshold: int
    total_working_days: int
    past_working_days: int
    days_with_proof: int
    days_without_proof: int
    forecast_homeworking_days: int
    forecasted_days_without_proof: int   # alias for iOS compatibility
    remaining_allowed_homeworking_days: int
    is_at_risk: bool
    compliance_status: str               # "compliant" | "at_risk" for iOS
