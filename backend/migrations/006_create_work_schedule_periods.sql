-- Run this in Supabase → SQL Editor

create table public.work_schedule_periods (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references auth.users(id) on delete cascade,
    start_date   date not null,
    end_date     date,              -- null = open-ended (current ongoing regime)
    working_days integer[] not null, -- [] = full leave, [0,1,2,3] = Mon–Thu, etc.
    description  text,
    created_at   timestamptz not null default now(),
    constraint valid_date_range check (end_date is null or end_date >= start_date)
);

alter table public.work_schedule_periods enable row level security;

create policy "Users can manage their own work schedule periods"
    on public.work_schedule_periods
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create index work_schedule_periods_user_date_idx
    on public.work_schedule_periods(user_id, start_date, end_date);
