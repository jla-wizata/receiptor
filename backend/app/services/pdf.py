from datetime import date

from fpdf import FPDF
from fpdf.enums import XPos, YPos

# Signed URL expiry used specifically for report links (5 years)
REPORT_SIGNED_URL_EXPIRY = 157_680_000

_COL_DATE = 32
_COL_DAY = 28
_COL_OCR = 35
_COL_LINK = 75
_ROW_H = 6


class _PDF(FPDF):
    def __init__(self, header_text: str):
        super().__init__()
        self._header_text = header_text

    def header(self):
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(150, 150, 150)
        self.cell(0, 8, self._header_text, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_draw_color(210, 210, 210)
        self.line(self.l_margin, self.get_y(), self.w - self.r_margin, self.get_y())
        self.ln(3)

    def footer(self):
        self.set_y(-14)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(150, 150, 150)
        self.cell(0, 8, f"Page {self.page_no()}", align="C")


_WEEKDAY_NAMES = {0: "Mon", 1: "Tue", 2: "Wed", 3: "Thu", 4: "Fri", 5: "Sat", 6: "Sun"}


def generate_compliance_report(
    user_email: str,
    year: int,
    summary: dict,
    receipts: list[dict],
    public_holidays: list[dict],
    user_holidays: list[dict],
    schedule_periods: list[dict] | None = None,
) -> bytes:
    pdf = _PDF(f"Fiscal Compliance Report {year} - {user_email}")
    pdf.set_margins(20, 20, 20)
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.add_page()

    # ── Title ────────────────────────────────────────────────────────────────
    pdf.set_font("Helvetica", "B", 20)
    pdf.set_text_color(30, 30, 30)
    pdf.cell(0, 12, "Fiscal Compliance Report", align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 12)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 7, str(year), align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(3)

    pdf.set_font("Helvetica", "", 10)
    pdf.cell(0, 6, f"Account: {user_email}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Generated: {date.today().strftime('%d %B %Y')}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(6)

    # ── Compliance status badge ───────────────────────────────────────────────
    if summary.get("is_at_risk"):
        pdf.set_fill_color(200, 50, 50)
        status_text = "AT RISK"
    else:
        pdf.set_fill_color(34, 139, 34)
        status_text = "COMPLIANT"
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 11, status_text, align="C", fill=True, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(7)

    # ── Summary ───────────────────────────────────────────────────────────────
    _section_title(pdf, "Compliance Summary")
    _summary_row(pdf, "Working country", summary["working_country_code"])
    _summary_row(pdf, "Home-working threshold", f"{summary['homeworking_threshold']} days / year")
    _summary_row(pdf, "Total working days in year", str(summary["total_working_days"]))
    _summary_row(pdf, "Days with proof of presence", str(summary["days_with_proof"]))
    _summary_row(pdf, "Days without proof (home-working so far)", str(summary["days_without_proof"]))
    _summary_row(pdf, "Forecasted home-working days at year end", str(summary["forecast_homeworking_days"]))
    _summary_row(pdf, "Remaining allowed home-working days", str(summary["remaining_allowed_homeworking_days"]))
    pdf.ln(7)

    # ── Receipts ──────────────────────────────────────────────────────────────
    _section_title(pdf, f"Receipts ({len(receipts)})")
    if receipts:
        _receipts_table(pdf, receipts)
    else:
        pdf.set_font("Helvetica", "I", 10)
        pdf.set_text_color(120, 120, 120)
        pdf.cell(0, 7, "No receipts recorded for this year.", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(7)

    # ── Public holidays ───────────────────────────────────────────────────────
    if public_holidays:
        _section_title(pdf, f"Public Holidays Excluded ({len(public_holidays)})")
        _holidays_table(pdf, public_holidays)
        pdf.ln(7)

    # ── User-defined holidays ─────────────────────────────────────────────────
    if user_holidays:
        _section_title(pdf, f"Personal Holiday Periods ({len(user_holidays)})")
        _user_holidays_table(pdf, user_holidays)
        pdf.ln(7)

    # ── Work schedule periods ─────────────────────────────────────────────────
    if schedule_periods:
        _section_title(pdf, f"Work Schedule Periods ({len(schedule_periods)})")
        _schedule_periods_table(pdf, schedule_periods)

    return bytes(pdf.output())


# ── Helpers ───────────────────────────────────────────────────────────────────

def _section_title(pdf: FPDF, text: str):
    pdf.set_font("Helvetica", "B", 12)
    pdf.set_text_color(30, 30, 30)
    pdf.cell(0, 8, text, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(1)


def _summary_row(pdf: FPDF, label: str, value: str):
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(115, 6, label)
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(30, 30, 30)
    pdf.cell(55, 6, value, new_x=XPos.LMARGIN, new_y=YPos.NEXT)


def _table_header(pdf: FPDF, widths: list[int], labels: list[str]):
    pdf.set_fill_color(60, 60, 60)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "B", 9)
    for w, label in zip(widths, labels):
        pdf.cell(w, 7, label, border=1, fill=True)
    pdf.ln()


def _receipts_table(pdf: FPDF, receipts: list[dict]):
    widths = [_COL_DATE, _COL_DAY, _COL_OCR, _COL_LINK]
    _table_header(pdf, widths, ["Date", "Day of week", "OCR status", "Receipt image"])

    pdf.set_font("Helvetica", "", 9)
    for idx, r in enumerate(receipts):
        receipt_date = date.fromisoformat(r["receipt_date"]) if r.get("receipt_date") else None
        date_str = receipt_date.strftime("%d/%m/%Y") if receipt_date else "-"
        day_str = receipt_date.strftime("%A") if receipt_date else "-"
        ocr_str = r.get("ocr_status", "-")

        fill = idx % 2 == 1
        pdf.set_fill_color(245, 245, 245)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(_COL_DATE, _ROW_H, date_str, border=1, fill=fill)
        pdf.cell(_COL_DAY, _ROW_H, day_str, border=1, fill=fill)
        pdf.cell(_COL_OCR, _ROW_H, ocr_str, border=1, fill=fill)
        pdf.set_text_color(0, 80, 180)
        pdf.cell(_COL_LINK, _ROW_H, "View receipt", border=1, fill=fill, link=r.get("image_url", ""))
        pdf.ln()


def _holidays_table(pdf: FPDF, holidays: list[dict]):
    widths = [32, 138]
    _table_header(pdf, widths, ["Date", "Holiday"])

    pdf.set_font("Helvetica", "", 9)
    for idx, h in enumerate(holidays):
        fill = idx % 2 == 1
        pdf.set_fill_color(245, 245, 245)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(widths[0], _ROW_H, h.get("date", ""), border=1, fill=fill)
        pdf.cell(widths[1], _ROW_H, h.get("name", ""), border=1, fill=fill)
        pdf.ln()


def _schedule_periods_table(pdf: FPDF, periods: list[dict]):
    widths = [32, 32, 40, 66]
    _table_header(pdf, widths, ["From", "To", "Working days", "Description"])

    pdf.set_font("Helvetica", "", 9)
    for idx, p in enumerate(periods):
        fill = idx % 2 == 1
        pdf.set_fill_color(245, 245, 245)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(widths[0], _ROW_H, p.get("start_date", ""), border=1, fill=fill)
        pdf.cell(widths[1], _ROW_H, p.get("end_date") or "ongoing", border=1, fill=fill)
        days_str = ", ".join(_WEEKDAY_NAMES[d] for d in sorted(p.get("working_days", []))) or "None (leave)"
        pdf.cell(widths[2], _ROW_H, days_str, border=1, fill=fill)
        pdf.cell(widths[3], _ROW_H, p.get("description") or "-", border=1, fill=fill)
        pdf.ln()


def _user_holidays_table(pdf: FPDF, holidays: list[dict]):
    widths = [32, 32, 106]
    _table_header(pdf, widths, ["From", "To", "Description"])

    pdf.set_font("Helvetica", "", 9)
    for idx, h in enumerate(holidays):
        fill = idx % 2 == 1
        pdf.set_fill_color(245, 245, 245)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(widths[0], _ROW_H, h.get("start_date", ""), border=1, fill=fill)
        pdf.cell(widths[1], _ROW_H, h.get("end_date", ""), border=1, fill=fill)
        pdf.cell(widths[2], _ROW_H, h.get("description") or "-", border=1, fill=fill)
        pdf.ln()
