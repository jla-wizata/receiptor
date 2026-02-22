from datetime import date

from pydantic import BaseModel


class PublicHoliday(BaseModel):
    date: date
    name: str
    local_name: str


class AvailableCountry(BaseModel):
    country_code: str
    name: str
