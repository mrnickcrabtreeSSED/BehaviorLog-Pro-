-- ============================================================
--  BehaviorLog Pro — District multi-tenancy, Phase 1 (foundation)
--  Paste into Supabase → SQL Editor → Run. Idempotent + additive.
--
--  Adds the districts + audit_log tables, district_id columns,
--  helper functions, seeds "CrabsFarren School District", backfills
--  EVERY existing user into it (roles unchanged), and promotes
--  Nick + Devin to founder. NEVER touches user_data (student data).
--
--  RLS POLICIES are NOT defined here — see the Phase 2 migration.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ── districts ────────────────────────────────────────────────
create table if not exists public.districts (
  id         uuid primary key default uuid_generate_v4(),
  name       text not null unique,
  created_at timestamptz not null default now(),
  created_by uuid
);
alter table public.districts enable row level security;

-- ── district_id on user_roles + invites ──────────────────────
alter table public.user_roles add column if not exists district_id uuid references public.districts(id);
alter table public.invites    add column if not exists district_id uuid references public.districts(id);
create index if not exists user_roles_district_idx on public.user_roles (district_id);
create index if not exists invites_district_idx    on public.invites (district_id);

-- ── audit_log (FERPA: break-glass, export, delete, role changes)
create table if not exists public.audit_log (
  id             uuid primary key default uuid_generate_v4(),
  actor_id       uuid,
  actor_email    text,
  action         text not null,
  target_user_id uuid,
  target_email   text,
  district_id    uuid,
  detail         jsonb,
  created_at     timestamptz not null default now()
);
alter table public.audit_log enable row level security;
create index if not exists audit_log_created_idx on public.audit_log (created_at desc);

-- ── helper functions (mirror existing get_my_role()) ─────────
create or replace function public.get_my_district()
returns uuid language sql stable security definer set search_path = public as $$
  select district_id from public.user_roles where user_id = auth.uid() limit 1;
$$;

create or replace function public.is_founder()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'founder' from public.user_roles where user_id = auth.uid() limit 1), false);
$$;

-- ── widen the role check constraint ─────────────────────────
-- Original allowed only teacher/behaviorist/admin. Add school_psych
-- (made assignable in the app) and founder (this migration).
alter table public.user_roles drop constraint if exists user_roles_role_check;
alter table public.user_roles add constraint user_roles_role_check
  check (role = any (array['teacher','behaviorist','school_psych','admin','founder']));

-- ── seed + data-preserving backfill ──────────────────────────
insert into public.districts (name) values ('CrabsFarren School District')
  on conflict (name) do nothing;

-- Every existing member → CrabsFarren (only fills NULLs; safe to re-run).
update public.user_roles
  set district_id = (select id from public.districts where name = 'CrabsFarren School District')
  where district_id is null;

-- Promote the two SureStep founders by email; their home district stays CrabsFarren.
update public.user_roles ur
  set role = 'founder'
  from auth.users u
  where u.id = ur.user_id
    and lower(u.email) in ('mrnickcrabtree@gmail.com', 'devinfarren@gmail.com');

-- ── verify (optional) ────────────────────────────────────────
-- select u.email, ur.role, d.name from user_roles ur
--   join auth.users u on u.id=ur.user_id
--   left join districts d on d.id=ur.district_id order by ur.role;
