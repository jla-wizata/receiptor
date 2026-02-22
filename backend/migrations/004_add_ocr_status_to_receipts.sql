-- Run this in Supabase → SQL Editor

alter table public.receipts
    add column ocr_status text not null;

-- Possible values:
--   'success'       — OCR found a date automatically
--   'no_date_found' — OCR ran but no recognisable date in the image
--   'failed'        — OCR error (credentials, API unavailable, etc.)
--   'skipped'       — date_override was provided at upload time
--   'manual'        — user manually set the date after upload
