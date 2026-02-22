-- Run this in Supabase → SQL Editor

create table public.receipts (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    receipt_date date,
    storage_path text not null,
    notes       text,
    created_at  timestamptz not null default now()
);

-- Only allow users to see their own receipts
alter table public.receipts enable row level security;

create policy "Users can manage their own receipts"
    on public.receipts
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Useful index for dashboard/filter queries
create index receipts_user_date_idx on public.receipts(user_id, receipt_date);
