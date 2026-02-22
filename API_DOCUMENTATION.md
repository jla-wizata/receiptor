# Receiptor API Documentation

## Table of Contents

1. [Overview](#1-overview)
2. [Authentication](#2-authentication)
3. [Receipts](#3-receipts)
4. [Dashboard](#4-dashboard)
5. [Public Holidays](#5-public-holidays)
6. [Compliance Report](#6-compliance-report)
7. [Database Schema](#7-database-schema)
8. [Setup and Running](#8-setup-and-running)
9. [Business Logic](#9-business-logic)

---

## 1. Overview

Receiptor is a fiscal compliance backend for cross-border workers — people who live in one country and are employed in another. Many bilateral tax treaties (for example, between Belgium, France, Germany, and Luxembourg) restrict the number of days per year that an employee may work from home without triggering tax residency obligations in the country of residence. The default limit is **34 days per year**, but this threshold is configurable per user.

The app lets workers prove their physical presence in their working country by scanning receipts dated on the days they were present. From those receipts the system derives a compliance score, a forecast, and a downloadable PDF report that can be presented to tax authorities.

### Tech Stack

| Layer | Technology |
|---|---|
| API framework | FastAPI (Python) |
| Auth, database, file storage | Supabase (PostgreSQL + Storage + GoTrue Auth) |
| OCR (date extraction) | Google Cloud Vision API |
| Public holidays data | Nager.Date API (free, no key required) |
| PDF generation | fpdf2 |
| HTTP server | Uvicorn |

### Base URL

```
http://localhost:8000
```

Interactive documentation is available at `/docs` (Swagger UI) and `/redoc` (ReDoc).

### Authentication

All endpoints except `GET /holidays/countries` require a valid JWT Bearer token in the `Authorization` header:

```
Authorization: Bearer <access_token>
```

Tokens are obtained via `POST /auth/login` or `POST /auth/register`.

---

## 2. Authentication

All auth operations are handled server-side via Supabase Auth. The mobile app never communicates with Supabase directly — it talks exclusively to this API.

### Flow

1. User calls `POST /auth/register` or `POST /auth/login`.
2. The API returns an `access_token` (JWT) and `refresh_token`.
3. The client includes the `access_token` as a Bearer token in all subsequent requests.
4. When the access token expires (typically 1 hour), call `POST /auth/refresh` to get a new one.

---

### POST /auth/register

Register a new account. If Supabase email confirmation is disabled, returns tokens immediately. If enabled, returns a message asking the user to check their email.

**Request body**

```json
{
  "email": "user@example.com",
  "password": "SecurePassword123"
}
```

**Response — 201 Created (tokens)**

```json
{
  "access_token": "eyJ...",
  "refresh_token": "abc...",
  "token_type": "bearer"
}
```

**Response — 201 Created (email confirmation required)**

```json
{
  "message": "Registration successful. Please check your email to confirm your account."
}
```

**Error responses**

| Status | Meaning |
|---|---|
| 400 | Email already registered or invalid input |
| 422 | Validation error (malformed email, weak password) |

---

### POST /auth/login

Authenticate with email and password.

**Request body**

```json
{
  "email": "user@example.com",
  "password": "SecurePassword123"
}
```

**Response — 200 OK**

```json
{
  "access_token": "eyJ...",
  "refresh_token": "abc...",
  "token_type": "bearer"
}
```

**Error responses**

| Status | Meaning |
|---|---|
| 401 | Invalid credentials |

---

### POST /auth/refresh

Exchange a refresh token for a new access token.

**Request body**

```json
{
  "refresh_token": "abc..."
}
```

**Response — 200 OK**

```json
{
  "access_token": "eyJ...",
  "refresh_token": "xyz...",
  "token_type": "bearer"
}
```

**Error responses**

| Status | Meaning |
|---|---|
| 401 | Refresh token is invalid or expired |

---

### POST /auth/logout

Invalidate the current session. Requires authentication.

**Response — 204 No Content**

---

## 3. Receipts

Receipts are the core evidence of physical presence. Each receipt is an image file stored in Supabase Storage. The receipt date is extracted automatically via OCR when the image is uploaded.

### Receipt Object

```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "user_id": "7e2d4f8b-1a3c-4d9e-b5f6-0a1b2c3d4e5f",
  "receipt_date": "2026-02-15",
  "ocr_status": "success",
  "storage_path": "user-id/uuid.jpg",
  "image_url": "https://....supabase.co/storage/v1/object/sign/receipts/...?token=...",
  "notes": null,
  "created_at": "2026-02-15T10:30:00Z"
}
```

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Unique identifier |
| `user_id` | UUID | Owner of the receipt |
| `receipt_date` | date or null | Date on the receipt (from OCR or manual entry). Null if OCR failed and no manual date set |
| `ocr_status` | string | See table below |
| `storage_path` | string | Internal path in Supabase Storage |
| `image_url` | string | Short-lived signed URL (1 hour) for displaying the image |
| `notes` | string or null | Free-text notes |
| `created_at` | datetime | Upload timestamp |

### OCR Status Values

| Value | Meaning |
|---|---|
| `success` | A date was successfully extracted from the image |
| `no_date_found` | OCR ran but could not find a recognisable date |
| `failed` | OCR call threw an error (e.g. Vision API not configured) |
| `manual` | Date was set or overridden manually via `PUT /receipts/{id}/date` |

When `ocr_status` is `no_date_found` or `failed`, the app should prompt the user to enter the date manually.

---

### POST /receipts/upload

Upload a receipt image. OCR date extraction runs automatically.

**Request** — `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `file` | file | Yes | Receipt image. Supported: JPEG, PNG, WebP, PDF. For iOS, always send JPEG (use `image.jpegData`) |

**Response — 201 Created**

Returns the receipt object. If OCR failed, `receipt_date` will be null and `ocr_status` will be `no_date_found` or `failed`.

---

### GET /receipts/

List all receipts for the authenticated user, ordered by `receipt_date` descending.

**Query parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `start_date` | date | none | Only return receipts on or after this date (ISO 8601: `YYYY-MM-DD`) |
| `end_date` | date | none | Only return receipts on or before this date |

**Response — 200 OK**

Array of receipt objects.

---

### GET /receipts/{receipt_id}

Get a single receipt by ID.

**Response — 200 OK**

Single receipt object.

**Error responses**

| Status | Meaning |
|---|---|
| 404 | Receipt not found or does not belong to the authenticated user |

---

### PUT /receipts/{receipt_id}/date

Set or correct the date on a receipt. Sets `ocr_status` to `"manual"`.

**Request body**

```json
{
  "receipt_date": "2026-02-15"
}
```

**Response — 200 OK**

Returns the updated receipt object.

**Error responses**

| Status | Meaning |
|---|---|
| 404 | Receipt not found or does not belong to the authenticated user |

---

### DELETE /receipts/{receipt_id}

Delete a receipt and its stored image file.

**Response — 204 No Content**

**Error responses**

| Status | Meaning |
|---|---|
| 404 | Receipt not found or does not belong to the authenticated user |

---

## 4. Dashboard

The dashboard computes and returns the user's fiscal compliance status for a given year.

---

### 4.1 Compliance Summary

#### GET /dashboard

Compute and return the compliance summary.

**Query parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `year` | integer | current year | The year to compute compliance for |

**Response — 200 OK**

```json
{
  "year": 2026,
  "working_country_code": "LU",
  "homeworking_threshold": 34,
  "total_working_days": 253,
  "past_working_days": 36,
  "days_with_proof": 28,
  "days_without_proof": 8,
  "forecast_homeworking_days": 56,
  "remaining_allowed_homeworking_days": 26,
  "is_at_risk": false
}
```

| Field | Type | Description |
|---|---|---|
| `year` | integer | The requested year |
| `working_country_code` | string | ISO code of the user's employment country |
| `homeworking_threshold` | integer | Maximum allowed home-working days per year |
| `total_working_days` | integer | All working days in the year, excluding public holidays and user-defined holiday periods |
| `past_working_days` | integer | Working days from 1 January to today (inclusive) |
| `days_with_proof` | integer | Past working days that have at least one uploaded receipt |
| `days_without_proof` | integer | Past working days with no receipt — assumed home-working |
| `forecast_homeworking_days` | integer | Projected total home-working days at year end, based on current rate |
| `remaining_allowed_homeworking_days` | integer | How many more days without proof can be tolerated before breaching the threshold |
| `is_at_risk` | boolean | `true` if the forecast exceeds the threshold |

---

### 4.2 User Settings

#### GET /dashboard/settings

Return the user's compliance settings. If no settings have been saved, returns defaults.

**Response — 200 OK**

```json
{
  "user_id": "7e2d4f8b-1a3c-4d9e-b5f6-0a1b2c3d4e5f",
  "working_country_code": "LU",
  "residence_country_code": "BE",
  "homeworking_threshold": 34,
  "working_days": [0, 1, 2, 3, 4]
}
```

| Field | Type | Description |
|---|---|---|
| `working_country_code` | string | ISO 3166-1 alpha-2 code of employment country (used for public holidays) |
| `residence_country_code` | string | ISO 3166-1 alpha-2 code of residence country |
| `homeworking_threshold` | integer | Maximum allowed home-working days per year |
| `working_days` | array of integers | Default working weekdays: 0 = Mon, 1 = Tue, 2 = Wed, 3 = Thu, 4 = Fri |

**Defaults (if not configured)**

| Setting | Default |
|---|---|
| `working_country_code` | `"LU"` |
| `residence_country_code` | `"BE"` |
| `homeworking_threshold` | `34` |
| `working_days` | `[0, 1, 2, 3, 4]` (Mon–Fri) |

---

#### PUT /dashboard/settings

Update one or more settings. Only provided fields are updated.

**Request body** (all fields optional)

```json
{
  "working_country_code": "LU",
  "residence_country_code": "BE",
  "homeworking_threshold": 34,
  "working_days": [0, 1, 2, 3, 4]
}
```

**`working_days` examples**

| Schedule | Value |
|---|---|
| Full Mon–Fri | `[0, 1, 2, 3, 4]` |
| 4-day week Mon–Thu | `[0, 1, 2, 3]` |
| Part-time Mon/Wed/Fri | `[0, 2, 4]` |

**Response — 200 OK**

Returns the full updated settings object.

---

### 4.3 Holiday Periods

User-defined holiday periods (paid leave, school holidays, etc.) are excluded from the compliance calculation entirely — days that fall within a holiday period are not counted as working days, so they neither require proof nor count as home-working days.

#### GET /dashboard/holidays

List all user-defined holiday periods, ordered by `start_date`.

**Query parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `year` | integer | No | If provided, only return periods that fall within that calendar year |

**Response — 200 OK**

```json
[
  {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "user_id": "7e2d4f8b-1a3c-4d9e-b5f6-0a1b2c3d4e5f",
    "start_date": "2026-07-14",
    "end_date": "2026-07-25",
    "description": "Summer holidays"
  }
]
```

---

#### POST /dashboard/holidays

Create a new holiday period.

**Request body**

```json
{
  "start_date": "2026-07-14",
  "end_date": "2026-07-25",
  "description": "Summer holidays"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `start_date` | date | Yes | First day (inclusive) |
| `end_date` | date | Yes | Last day (inclusive). Must be >= `start_date` |
| `description` | string | No | Free-text label |

**Response — 201 Created**

Returns the created holiday object.

---

#### DELETE /dashboard/holidays/{holiday_id}

Delete a holiday period.

**Response — 204 No Content**

---

### 4.4 Work Schedule Periods

Work schedule periods allow the user to define time-bounded overrides to their default working week. Useful for part-time arrangements, parental leave, secondments, or any period where the working pattern differs from the default in settings.

Each period specifies which weekday numbers are working days during that interval. A period may be open-ended (no `end_date`). When computing compliance, the most recently starting period that covers a date wins. If no period covers a date, the default `working_days` from settings applies.

Setting `working_days` to `[]` (empty array) models a full leave period — no days in the range count as working days.

#### Work Schedule Period Object

```json
{
  "id": "b2c3d4e5-f6a7-8901-bcde-f01234567891",
  "user_id": "7e2d4f8b-1a3c-4d9e-b5f6-0a1b2c3d4e5f",
  "start_date": "2026-09-01",
  "end_date": "2026-12-31",
  "working_days": [0, 1, 2],
  "description": "Part-time: Mon-Wed only"
}
```

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Unique identifier |
| `user_id` | UUID | Owner |
| `start_date` | date | First date this schedule applies |
| `end_date` | date or null | Last date (inclusive); `null` = open-ended |
| `working_days` | array of integers | Active weekdays (0=Mon...4=Fri); `[]` = full leave |
| `description` | string or null | Optional label |

---

#### GET /dashboard/schedule

List all work schedule periods, ordered by `start_date`.

**Response — 200 OK** — Array of work schedule period objects.

---

#### POST /dashboard/schedule

Create a new work schedule period.

**Request body**

```json
{
  "start_date": "2026-09-01",
  "end_date": "2026-12-31",
  "working_days": [0, 1, 2],
  "description": "Part-time: Mon-Wed only"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `start_date` | date | Yes | First date the schedule applies |
| `end_date` | date | No | Last date (inclusive). Omit for open-ended |
| `working_days` | array of integers | Yes | Weekday numbers. Use `[]` for full leave |
| `description` | string | No | Optional label |

**Response — 201 Created** — Returns the created period object.

---

#### PUT /dashboard/schedule/{period_id}

Replace an existing work schedule period entirely.

**Request body** — Same shape as `POST /dashboard/schedule`.

**Response — 200 OK** — Returns the updated period object.

**Error responses**

| Status | Meaning |
|---|---|
| 404 | Period not found or does not belong to the authenticated user |

---

#### DELETE /dashboard/schedule/{period_id}

Delete a work schedule period.

**Response — 204 No Content**

---

## 5. Public Holidays

These endpoints proxy the [Nager.Date](https://date.nager.at/) public API. No API key is required.

---

### GET /holidays

Return public holidays for a country and year. Requires authentication.

**Query parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `year` | integer | current year | The year to fetch holidays for |
| `country` | string | user's `working_country_code` | ISO 3166-1 alpha-2 country code (e.g. `LU`, `BE`, `FR`, `DE`) |

**Response — 200 OK**

```json
[
  {
    "date": "2026-01-01",
    "name": "New Year's Day",
    "local_name": "Neijoerschdag"
  },
  {
    "date": "2026-04-06",
    "name": "Easter Monday",
    "local_name": "Ouschterméindeg"
  }
]
```

**Error responses**

| Status | Meaning |
|---|---|
| 400 | Country code not recognised |
| 502 | Nager.Date API unreachable |

---

### GET /holidays/countries

Return all countries supported by Nager.Date. **No authentication required.**

**Response — 200 OK**

```json
[
  { "country_code": "BE", "name": "Belgium" },
  { "country_code": "DE", "name": "Germany" },
  { "country_code": "FR", "name": "France" },
  { "country_code": "LU", "name": "Luxembourg" }
]
```

---

## 6. Compliance Report

### GET /report

Generate and download a yearly PDF compliance report. Requires authentication.

**Query parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `year` | integer | current year | The year to generate the report for |

**Response — 200 OK**

- `Content-Type: application/pdf`
- `Content-Disposition: attachment; filename="compliance_report_{year}.pdf"`

**Example (curl)**

```bash
curl -X GET "http://localhost:8000/report?year=2026" \
  -H "Authorization: Bearer <token>" \
  --output compliance_report_2026.pdf
```

### PDF Contents

1. **Title and metadata** — report year, user email, generation date.
2. **Compliance status badge** — prominent green `COMPLIANT` or red `AT RISK` banner.
3. **Compliance summary table** — all fields from `GET /dashboard`.
4. **Receipts table** — one row per receipt: date, day of week, OCR status, and a clickable link to the stored image. Receipt image URLs are signed with a **5-year expiry** (suitable for archiving with tax authorities).
5. **Public holidays** — all public holidays excluded from the count for the working country.
6. **Personal holiday periods** — user-defined leave periods.
7. **Work schedule periods** — any part-time or leave schedules active during the year.

---

## 7. Database Schema

All tables use Supabase Row Level Security (RLS). Users can only read and write their own rows. All `user_id` columns reference `auth.users(id) ON DELETE CASCADE`.

### receipts

```sql
create table public.receipts (
    id           uuid         primary key default gen_random_uuid(),
    user_id      uuid         not null references auth.users(id) on delete cascade,
    receipt_date date,
    ocr_status   text         not null,
    storage_path text         not null,
    notes        text,
    created_at   timestamptz  not null default now()
);

create index receipts_user_date_idx on public.receipts(user_id, receipt_date);
```

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | uuid | No | Primary key |
| `user_id` | uuid | No | Owner |
| `receipt_date` | date | Yes | Date from OCR or manual entry. Null if OCR failed |
| `ocr_status` | text | No | `success` / `no_date_found` / `failed` / `manual` |
| `storage_path` | text | No | Path in the `receipts` Supabase Storage bucket |
| `notes` | text | Yes | Free-text notes |
| `created_at` | timestamptz | No | Upload timestamp |

---

### user_settings

One row per user. If missing, API falls back to hardcoded defaults.

```sql
create table public.user_settings (
    user_id                uuid      primary key references auth.users(id) on delete cascade,
    working_country_code   text      not null default 'LU',
    residence_country_code text      not null default 'BE',
    homeworking_threshold  integer   not null default 34,
    working_days           integer[] not null default '{0,1,2,3,4}',
    updated_at             timestamptz not null default now()
);
```

| Column | Type | Default | Description |
|---|---|---|---|
| `user_id` | uuid | — | Primary key; references `auth.users` |
| `working_country_code` | text | `'LU'` | ISO code of employment country |
| `residence_country_code` | text | `'BE'` | ISO code of residence country |
| `homeworking_threshold` | integer | `34` | Max permitted home-working days/year |
| `working_days` | integer[] | `{0,1,2,3,4}` | Default weekdays that are working days |
| `updated_at` | timestamptz | `now()` | Last modification time |

---

### user_holidays

User-defined leave periods. Each row spans a date range fully excluded from compliance.

```sql
create table public.user_holidays (
    id          uuid  primary key default gen_random_uuid(),
    user_id     uuid  not null references auth.users(id) on delete cascade,
    start_date  date  not null,
    end_date    date  not null,
    description text,
    created_at  timestamptz not null default now(),
    constraint valid_date_range check (end_date >= start_date)
);

create index user_holidays_user_date_idx
    on public.user_holidays(user_id, start_date, end_date);
```

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | uuid | No | Primary key |
| `user_id` | uuid | No | Owner |
| `start_date` | date | No | First day (inclusive) |
| `end_date` | date | No | Last day (inclusive) |
| `description` | text | Yes | Optional label |
| `created_at` | timestamptz | No | Creation timestamp |

---

### work_schedule_periods

Time-bounded overrides to the user's regular working week.

```sql
create table public.work_schedule_periods (
    id           uuid      primary key default gen_random_uuid(),
    user_id      uuid      not null references auth.users(id) on delete cascade,
    start_date   date      not null,
    end_date     date,
    working_days integer[] not null,
    description  text,
    created_at   timestamptz not null default now(),
    constraint valid_date_range check (end_date is null or end_date >= start_date)
);

create index work_schedule_periods_user_date_idx
    on public.work_schedule_periods(user_id, start_date, end_date);
```

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | uuid | No | Primary key |
| `user_id` | uuid | No | Owner |
| `start_date` | date | No | First date this schedule applies |
| `end_date` | date | Yes | Last date (inclusive). `null` = open-ended |
| `working_days` | integer[] | No | Active weekdays. `{}` = full leave |
| `description` | text | Yes | Optional label |
| `created_at` | timestamptz | No | Creation timestamp |

---

## 8. Setup and Running

### Prerequisites

- Python 3.11+
- A [Supabase](https://supabase.com/) project with all migrations applied
- A Google Cloud project with the **Vision API** enabled and a service account JSON key
- Network access to `https://date.nager.at`

### 1. Create a Virtual Environment

```bash
cd receiptor/backend
python -m venv .venv
source .venv/bin/activate       # macOS/Linux
# .venv\Scripts\activate        # Windows
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

| Package | Purpose |
|---|---|
| `fastapi` | Web framework |
| `uvicorn[standard]` | ASGI server |
| `supabase` | Supabase Python client (v2+) |
| `python-dotenv` | Load `.env` files |
| `pydantic[email]` | Data validation |
| `pydantic-settings` | Settings from env vars |
| `google-cloud-vision` | OCR |
| `httpx` | HTTP client (Nager.Date calls) |
| `python-multipart` | File upload support |
| `fpdf2` | PDF report generation |

### 3. Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env`:

```env
# Supabase
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# Google Cloud Vision
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/gcloud.json

# App
APP_ENV=development
SECRET_KEY=<long-random-string>
```

| Variable | Where to find it |
|---|---|
| `SUPABASE_URL` | Supabase Dashboard > Project Settings > API |
| `SUPABASE_ANON_KEY` | Supabase Dashboard > Project Settings > API > `anon public` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Dashboard > Project Settings > API > `service_role` (keep secret) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Google Cloud Console > IAM > Service Accounts > Keys > JSON |

> **Never commit `.env` or the Google service account JSON file to version control.**

### 4. Apply Database Migrations

Run each file in order in the Supabase SQL Editor:

```
migrations/001_create_receipts.sql
migrations/002_create_user_settings.sql
migrations/003_create_user_holidays.sql
migrations/004_add_ocr_status_to_receipts.sql
migrations/005_add_working_days_to_user_settings.sql
migrations/006_create_work_schedule_periods.sql
```

Also create a **private** Storage bucket named `receipts` in Supabase Dashboard > Storage.

### 5. Run the Server

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API: `http://localhost:8000`
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

Remove `--reload` for production. Set `allow_origins` in `main.py` to your actual client origins instead of `"*"`.

---

## 9. Business Logic

### How Working Days Are Counted

For a given year, the compliance engine:

1. Generates all calendar days from 1 January to 31 December.
2. For each day, determines the **applicable weekday schedule** (see below).
3. Excludes the day if:
   - Its weekday is not in the applicable schedule, **or**
   - It falls on a **public holiday** in the working country (from Nager.Date), **or**
   - It falls within a **user-defined holiday period**.
4. Remaining days = `total_working_days`.
5. Days on or before today = `past_working_days`.

### How Schedule Periods Override the Default

`user_settings.working_days` is the default. `work_schedule_periods` are time-bounded exceptions.

For each calendar date, the engine scans all periods sorted by `start_date` descending. The **first matching period wins**. If no period matches, the default applies.

**Example:**

| Description | Start | End | Working days |
|---|---|---|---|
| Parental leave | 2026-04-01 | 2026-06-30 | `[]` (none) |
| Part-time pilot | 2026-09-01 | open-ended | `[0, 1, 2]` Mon-Wed |
| Default (settings) | — | — | `[0,1,2,3,4]` Mon-Fri |

- April 2026: parental leave matches → day excluded.
- October 2026: part-time period matches → only Mon/Tue/Wed count.
- March 2026: no period matches → full Mon-Fri applies.

### How the Forecast Works

```
days_without_proof  = past_working_days - days_with_proof  (home-working so far)

home_working_rate   = days_without_proof / past_working_days

future_working_days = total_working_days - past_working_days
projected_future    = round(home_working_rate * future_working_days)

forecast_homeworking_days = days_without_proof + projected_future
```

The forecast extrapolates the current home-working rate over the remaining year. It improves automatically as the user uploads more receipts.

### What "AT RISK" Means

```
is_at_risk = forecast_homeworking_days > homeworking_threshold
```

When `is_at_risk` is `true`, the user is on track to exceed their treaty-allowed home-working limit. They need to upload receipts for past days, or ensure better coverage going forward.

```
remaining_allowed_homeworking_days = max(0, threshold - days_without_proof)
```

### Typical Compliance Thresholds

| Country pair | Typical threshold |
|---|---|
| Belgium - Luxembourg | 34 days/year |
| Belgium - France | 34 days/year |
| Belgium - Germany | 34 days/year |
| France - Luxembourg | 29 days/year |
| Germany - Luxembourg | 34 days/year |

Always verify with the applicable bilateral tax treaty, as limits change.

### OCR Date Extraction

On upload the backend:

1. Sends the image to **Google Cloud Vision API** (`text_detection`).
2. Parses the returned text for date patterns:
   - `DD/MM/YYYY`, `DD-MM-YYYY`, `DD.MM.YYYY` (European, day-first)
   - `YYYY-MM-DD` (ISO 8601)
   - `DD Mon YYYY` (e.g. `15 Jan 2026`)
   - `Month DD, YYYY` (e.g. `January 15, 2026`)
3. Discards future dates and dates older than 10 years.
4. Returns the **most recent** surviving candidate (receipts print the transaction date last).

If OCR fails or finds no date, the receipt is still saved with `receipt_date = null`. The user corrects it via `PUT /receipts/{id}/date`, which sets `ocr_status` to `"manual"`.

iOS clients should send JPEG images (`image.jpegData(compressionQuality: 0.85)`) rather than HEIC, as Google Cloud Vision does not support HEIC natively.
