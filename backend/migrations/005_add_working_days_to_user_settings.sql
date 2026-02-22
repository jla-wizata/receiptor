-- Run this in Supabase → SQL Editor

alter table public.user_settings
    add column working_days integer[] not null default '{0,1,2,3,4}';

-- working_days stores weekday numbers: 0=Monday … 4=Friday
-- Full-time (default): {0,1,2,3,4}
-- Mon–Wed part-time:   {0,1,2}
-- Mon/Wed/Fri:         {0,2,4}
