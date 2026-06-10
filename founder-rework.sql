-- ============================================================
--  BehaviorLog Pro — Founder = macro/business only (Phase 6)
--  Run AFTER founder.sql. Idempotent.
--
--  Founder NEVER sees employee or student data. This adds the
--  business layer the founder DOES see: districts with contract
--  dates + billing rate, sites (schools) under each district, and
--  a counts-only overview RPC (headcounts by role + by site — NO
--  emails, names, or student data). The old founder_list_users()
--  roster is dropped by the app deploy step (it exposed emails).
-- ============================================================

-- ── contracts + billing on districts ────────────────────────
alter table public.districts
  add column if not exists contract_start date,
  add column if not exists contract_end   date,
  add column if not exists monthly_rate   numeric not null default 0,
  add column if not exists billable_roles text[]  not null default array['behaviorist','school_psych','admin'];

-- ── sites (schools) under a district ─────────────────────────
create table if not exists public.sites (
  id          uuid primary key default uuid_generate_v4(),
  district_id uuid not null references public.districts(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now(),
  unique(district_id, name)
);
alter table public.sites enable row level security;
alter table public.user_roles add column if not exists site_id uuid references public.sites(id);
create index if not exists user_roles_site_idx on public.user_roles(site_id);

drop policy if exists "founder_manage_sites" on public.sites;
create policy "founder_manage_sites" on public.sites for all
  using (public.is_founder()) with check (public.is_founder());
drop policy if exists "admin_manage_sites" on public.sites;
create policy "admin_manage_sites" on public.sites for all
  using (public.get_my_role()='admin' and district_id=public.get_my_district())
  with check (public.get_my_role()='admin' and district_id=public.get_my_district());
drop policy if exists "read_own_district_sites" on public.sites;
create policy "read_own_district_sites" on public.sites for select
  using (public.is_founder() or district_id=public.get_my_district());

-- ── founder_overview(): COUNTS ONLY, founder-gated ──────────
-- Returns one object per district: contract/billing fields, headcount
-- by role, total users, and per-site headcounts. No PII, no student data.
create or replace function public.founder_overview()
returns jsonb language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  if not public.is_founder() then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(d_obj order by d_obj->>'name'), '[]'::jsonb) into result
  from (
    select jsonb_build_object(
      'district_id',    d.id,
      'name',           d.name,
      'contract_start', d.contract_start,
      'contract_end',   d.contract_end,
      'monthly_rate',   d.monthly_rate,
      'billable_roles', d.billable_roles,
      'total_users',    (select count(*) from public.user_roles where district_id = d.id),
      'role_counts',    (select coalesce(jsonb_object_agg(role, n), '{}'::jsonb)
                           from (select role, count(*) n from public.user_roles
                                 where district_id = d.id group by role) rc),
      'sites',          (select coalesce(jsonb_agg(jsonb_build_object(
                              'site_id', s.id, 'name', s.name,
                              'users', (select count(*) from public.user_roles ur where ur.site_id = s.id)
                           ) order by s.name), '[]'::jsonb)
                           from public.sites s where s.district_id = d.id)
    ) as d_obj
    from public.districts d
  ) t;
  return result;
end;
$$;
grant execute on function public.founder_overview() to authenticated;
