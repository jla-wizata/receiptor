-- Run this in Supabase → SQL Editor

create table public.user_settings (
    user_id                 uuid primary key references auth.users(id) on delete cascade,
    working_country_code    text not null default 'LU',   -- country where user is employed
    residence_country_code  text not null default 'BE',   -- country where user lives
    homeworking_threshold   integer not null default 34,  -- max allowed home-working days/year
    updated_at              timestamptz not null default now()
);

alter table public.user_settings enable row level security;

create policy "Users can manage their own settings"
    on public.user_settings
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
