-- AutoContact schema: groups and members.
-- Run in the Supabase SQL editor (or `supabase db push`).

create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) between 1 and 100),
  join_code   text not null unique,
  owner_id    uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table public.members (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null check (length(trim(name)) between 1 and 100),
  phone       text,
  email       text not null,
  org         text,
  created_at  timestamptz not null default now(),
  unique (group_id, user_id)
);

create index members_user_id_idx on public.members (user_id);
create index groups_owner_id_idx on public.groups (owner_id);

-- Second layer of defense: RLS on with no policies, so the anon/authenticated
-- keys can't touch these tables directly. Only the Next.js API (service role)
-- reads and writes them, and it does its own authorization checks.
alter table public.groups  enable row level security;
alter table public.members enable row level security;
