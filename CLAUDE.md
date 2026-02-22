# Fiscal Receipts App — Project Brief

## Business Context
Cross-border worker app for fiscal compliance. Users work in one country, live in another.
Limited to 34 days/year of homeworking, but should be editable threshold based on residence 
country (Belgium, Germany, France). App helps prove physical presence in working country
by scanning and dating receipts.

## Architecture
- **Backend**: Python FastAPI, hosted (TBD), exposes REST API
- **Frontend**: iOS app (Swift/SwiftUI) — future Android compatibility required
- **Auth & DB & Storage**: Supabase (PostgreSQL + file storage + auth)
- **OCR**: Google Cloud Vision API for date extraction from receipt images
- **Holidays**: Nager.Date free API for public holidays by country

## Core Features
1. Receipt scanning → image stored in Supabase Storage, metadata in DB
2. Date extracted automatically from receipt image via OCR (not scan date)
3. History of all scanned receipts with filtering by date range
4. Dashboard showing days with/without proof of presence, total days scanned, and forecast
predicting how many days with no proof will at the end of the year
5. Public holidays auto-fetched and excluded from compliance count
6. User-defined holiday periods and working regimes (part-time, etc.)
7. Yearly PDF compliance report with receipt links
8. Auth: email/password + Google SSO via Supabase Auth

## Backend Folder Structure
backend/
├── app/
│   ├── main.py          ← FastAPI entrypoint
│   ├── config.py        ← env vars and settings
│   ├── routers/         ← one file per feature domain
│   ├── models/          ← Pydantic models
│   ├── services/        ← business logic
│   └── db/              ← Supabase client and helpers
├── requirements.txt
└── .env.example

## Key Technical Decisions
- All dates derived from receipt content, not upload timestamp
- REST API must be platform-agnostic (iOS and Android compatible)
- Secrets via .env file, never committed to git
- Supabase project URL and anon key stored as SUPABASE_URL and SUPABASE_ANON_KEY