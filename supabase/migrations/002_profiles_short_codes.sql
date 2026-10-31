-- One contact card per user, shared by every group they're in, plus short
-- join codes. Run in the Supabase SQL editor after 001_init.sql.

create table public.profiles (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  first_name  text not null check (length(trim(first_name)) between 1 and 100),
  last_name   text check (length(last_name) <= 100),
  -- [{"label": "mobile", "number": "+1 555 010 2030"}, ...]
  phones      jsonb not null default '[]' check (jsonb_typeof(phones) = 'array'),
  -- [{"label": "work", "address": "ana@crew.co"}, ...]
  emails      jsonb not null default '[]' check (jsonb_typeof(emails) = 'array'),
  company     text check (length(company) <= 100),
  job_title   text check (length(job_title) <= 100),
  website     text check (length(website) <= 200),
  address     text check (length(address) <= 300),
  birthday    date,
  updated_at  timestamptz not null default now()
);

-- Same model as the other tables: only the API (service role) touches it.
alter table public.profiles enable row level security;

-- Owners are now members of their own groups. Backfill existing groups.
insert into public.members (group_id, user_id, name, email)
select g.id,
       g.owner_id,
       left(coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), split_part(u.email, '@', 1), 'Member'), 100),
       coalesce(u.email, '')
from public.groups g
join auth.users u on u.id = g.owner_id
on conflict (group_id, user_id) do nothing;

-- Join codes go from 12 characters to "ABC123" (shown as ABC-123).
-- Existing groups get new codes; old codes stop working.
update public.groups
set join_code = chr(65 + floor(random() * 26)::int)
             || chr(65 + floor(random() * 26)::int)
             || chr(65 + floor(random() * 26)::int)
             || lpad(floor(random() * 1000)::int::text, 3, '0');

alter table public.groups
  add constraint groups_join_code_format check (join_code ~ '^[A-Z]{3}[0-9]{3}$');
