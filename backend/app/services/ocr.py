import re
from datetime import date
from typing import Optional

from google.cloud import vision

MONTH_MAP = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}

# (regex pattern, format hint)
DATE_PATTERNS = [
    # DD/MM/YYYY or MM/DD/YYYY — treated as DD/MM (European receipts)
    (r"\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})\b", "dmy"),
    # YYYY-MM-DD (ISO)
    (r"\b(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})\b", "ymd"),
    # DD Mon YYYY  e.g. 15 Jan 2024
    (r"\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{4})\b", "dmy_text"),
    # Mon DD, YYYY  e.g. January 15, 2024
    (r"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b", "mdy_text"),
]


def extract_date_from_text(text: str) -> Optional[date]:
    """Return the most plausible receipt date found in OCR text."""
    today = date.today()
    candidates: list[date] = []

    for pattern, fmt in DATE_PATTERNS:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            try:
                if fmt == "dmy":
                    d, m, y = int(match.group(1)), int(match.group(2)), int(match.group(3))
                elif fmt == "ymd":
                    y, m, d = int(match.group(1)), int(match.group(2)), int(match.group(3))
                elif fmt == "dmy_text":
                    d = int(match.group(1))
                    m = MONTH_MAP[match.group(2)[:3].lower()]
                    y = int(match.group(3))
                elif fmt == "mdy_text":
                    m = MONTH_MAP[match.group(1)[:3].lower()]
                    d = int(match.group(2))
                    y = int(match.group(3))
                else:
                    continue
                candidates.append(date(y, m, d))
            except (ValueError, KeyError):
                continue

    # Discard future dates and anything older than 10 years
    valid = [c for c in candidates if c <= today and c.year >= today.year - 10]
    # Most recent plausible date wins (receipt date is usually the latest on the slip)
    return max(valid) if valid else None


def extract_date_from_image(image_bytes: bytes) -> Optional[date]:
    """Call Google Cloud Vision and extract the receipt date from the returned text."""
    client = vision.ImageAnnotatorClient()
    image = vision.Image(content=image_bytes)
    response = client.text_detection(image=image)

    if response.error.message:
        raise RuntimeError(f"Vision API error: {response.error.message}")

    if not response.text_annotations:
        return None

    full_text = response.text_annotations[0].description
    return extract_date_from_text(full_text)
