-- ============================================================
--  BehaviorLog Pro — Real Shared Access (teacher ↔ specialist)
--  Paste this entire file into Supabase → SQL Editor → Run.
--  Safe to re-run (idempotent).
--
--  Model: a teacher shares a SINGLE student with a specialist by
--  email. The specialist logs into their OWN account and reads only
--  the shared student's slice (client + that student's sessions +
--  goals + the behavior definitions those reference). RLS keeps raw
--  user_data blobs private; cross-user reads happen ONLY through the
--  security-definer function below, which returns just the shared
--  subset — never the rest of the teacher's roster.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ── student_shares ───────────────────────────────────────────
-- One row per (owner → specialist → student) grant.
create table if not exists public.student_shares (
  id            uuid primary key default uuid_generate_v4(),
  owner_id      uuid not null references auth.users(id) on delete cascade,
  grantee_email text not null,                 -- specialist's login email
  student_id    text not null,                 -- client.id inside the owner's jsonb
  student_name  text,                          -- denormalized for display
  specialist_role text not null default 'behaviorist', -- 'behaviorist' | 'school_psych'
  access        text not null default 'read',  -- 'read' (v1) | 'write' (future)
  created_at    timestamptz not null default now(),
  unique(owner_id, grantee_email, student_id)
);

alter table public.student_shares enable row level security;

-- Owner fully manages their own shares (create / view / revoke).
drop policy if exists "owner manages shares" on public.student_shares;
create policy "owner manages shares"
  on public.student_shares for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Grantee may READ rows addressed to their email (so their app knows
-- what's shared with them). Email taken from the JWT — no auth.users read.
drop policy if exists "grantee reads shares" on public.student_shares;
create policy "grantee reads shares"
  on public.student_shares for select
  using (lower(grantee_email) = lower(coalesce(auth.jwt() ->> 'email', '')));

create index if not exists student_shares_grantee_idx
  on public.student_shares (lower(grantee_email));

-- ── get_shared_students() ────────────────────────────────────
-- Returns ONLY the students shared with the caller, as data slices
-- pulled out of each owner's user_data blob. Security-definer so it
-- can read across users, but it filters to shared student_ids only.
create or replace function public.get_shared_students()
returns table (
  owner_id     uuid,
  owner_email  text,
  student_id   text,
  specialist_role text,
  access       text,
  client       jsonb,
  sessions     jsonb,
  goals        jsonb,
  customs      jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  myemail text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if myemail = '' then
    return;
  end if;

  return query
  select
    s.owner_id,
    (select u.email::text from auth.users u where u.id = s.owner_id) as owner_email,
    s.student_id,
    s.specialist_role,
    s.access,
    -- the single shared student object
    (select c
       from jsonb_array_elements(coalesce(ud.data->'clients','[]'::jsonb)) c
      where c->>'id' = s.student_id
      limit 1) as client,
    -- only that student's sessions
    coalesce((select jsonb_agg(se)
       from jsonb_array_elements(coalesce(ud.data->'sessions','[]'::jsonb)) se
      where se->>'clientId' = s.student_id), '[]'::jsonb) as sessions,
    -- only that student's goals
    coalesce((select jsonb_agg(g)
       from jsonb_array_elements(coalesce(ud.data->'goals','[]'::jsonb)) g
      where g->>'clientId' = s.student_id), '[]'::jsonb) as goals,
    -- behavior definitions (generic labels — needed to resolve ids)
    coalesce(ud.data->'customs','[]'::jsonb) as customs
  from public.student_shares s
  join public.user_data ud on ud.user_id = s.owner_id
  where lower(s.grantee_email) = myemail;
end;
$$;

grant execute on function public.get_shared_students() to authenticated;

-- ── Verify (optional) ────────────────────────────────────────
-- select * from public.student_shares;
-- select owner_email, student_id, jsonb_array_length(sessions) from public.get_shared_students();
