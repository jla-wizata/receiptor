-- Run this in Supabase → SQL Editor

create table public.user_holidays (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    start_date  date not null,
    end_date    date not null,
    description text,
    created_at  timestamptz not null default now(),
    constraint valid_date_range check (end_date >= start_date)
);

alter table public.user_holidays enable row level security;

create policy "Users can manage their own holidays"
    on public.user_holidays
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create index user_holidays_user_date_idx on public.user_holidays(user_id, start_date, end_date);
