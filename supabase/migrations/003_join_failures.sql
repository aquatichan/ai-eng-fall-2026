-- Wrong join codes per user, so the API can cap guessing (10 per 15 minutes).
-- Run in the Supabase SQL editor after 002.

create table public.join_failures (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create index join_failures_user_time_idx on public.join_failures (user_id, created_at);

alter table public.join_failures enable row level security;
