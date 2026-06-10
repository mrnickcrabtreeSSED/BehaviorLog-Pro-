-- ============================================================
--  BehaviorLog Pro — District multi-tenancy, Phase 2 (RLS + RPCs)
--  Run AFTER districts.sql. Idempotent. Rewrites access control so:
--    • founder  → global (all districts)
--    • admin    → only their own district
--    • everyone → unchanged feature access, scoped to their district
--  Also adds redeem_invite() (server-side role+district assignment)
--  and district-scopes list_specialists().
--
--  NOTE: tightening users_insert_own_role is intentionally NOT here —
--  it ships at the END of Phase 3 (once the app calls redeem_invite),
--  so the currently-deployed app's invite flow keeps working meanwhile.
-- ============================================================

-- ── user_roles: founder global, admin district-scoped ───────
drop policy if exists "admins_manage_all_roles" on public.user_roles;

drop policy if exists "founder_manage_roles" on public.user_roles;
create policy "founder_manage_roles" on public.user_roles for all
  using (public.is_founder()) with check (public.is_founder());

-- District admin manages roles only within their district, and may not
-- mint founders or move users to another district.
drop policy if exists "district_admin_manage_roles" on public.user_roles;
create policy "district_admin_manage_roles" on public.user_roles for all
  using (public.get_my_role() = 'admin' and district_id = public.get_my_district())
  with check (public.get_my_role() = 'admin' and district_id = public.get_my_district() and role <> 'founder');
-- (users_read_own_role + users_insert_own_role remain unchanged here.)

-- ── user_data: founder all; district admin read + delete ─────
drop policy if exists "admins can read all user_data" on public.user_data;

drop policy if exists "founder_manage_user_data" on public.user_data;
create policy "founder_manage_user_data" on public.user_data for all
  using (public.is_founder()) with check (public.is_founder());

drop policy if exists "district_admin_read_user_data" on public.user_data;
create policy "district_admin_read_user_data" on public.user_data for select
  using (public.get_my_role() = 'admin'
         and exists (select 1 from public.user_roles t
                     where t.user_id = user_data.user_id and t.district_id = public.get_my_district()));

drop policy if exists "district_admin_delete_user_data" on public.user_data;
create policy "district_admin_delete_user_data" on public.user_data for delete
  using (public.get_my_role() = 'admin'
         and exists (select 1 from public.user_roles t
                     where t.user_id = user_data.user_id and t.district_id = public.get_my_district()));

-- ── invites: founder all; district admin scoped ─────────────
drop policy if exists "Admins manage invites" on public.invites;

drop policy if exists "founder_manage_invites" on public.invites;
create policy "founder_manage_invites" on public.invites for all
  using (public.is_founder()) with check (public.is_founder());

drop policy if exists "district_admin_manage_invites" on public.invites;
create policy "district_admin_manage_invites" on public.invites for all
  using (public.get_my_role() = 'admin' and district_id = public.get_my_district())
  with check (public.get_my_role() = 'admin' and district_id = public.get_my_district() and role <> 'founder');
-- ("Anyone can read unused invites" + "Users can claim invites" remain.)

-- ── districts: founder all; members read their own ──────────
drop policy if exists "founder_manage_districts" on public.districts;
create policy "founder_manage_districts" on public.districts for all
  using (public.is_founder()) with check (public.is_founder());

drop policy if exists "read_own_district" on public.districts;
create policy "read_own_district" on public.districts for select
  using (public.is_founder() or id = public.get_my_district());

-- ── audit_log: founder all; admin reads own district; any
--    authenticated user may insert rows attributing themselves ──
drop policy if exists "founder_manage_audit" on public.audit_log;
create policy "founder_manage_audit" on public.audit_log for all
  using (public.is_founder()) with check (public.is_founder());

drop policy if exists "district_admin_read_audit" on public.audit_log;
create policy "district_admin_read_audit" on public.audit_log for select
  using (public.get_my_role() = 'admin' and district_id = public.get_my_district());

drop policy if exists "insert_own_audit" on public.audit_log;
create policy "insert_own_audit" on public.audit_log for insert
  with check (actor_id = auth.uid());

-- ── redeem_invite(): server-side role + district assignment ─
-- Called by boot() when the user has no role row yet. Sets role+district
-- from a valid unused invite (else defaults to teacher / no district),
-- marks the invite used. Security-definer so the self-insert RLS policy
-- can be locked to teacher-only without breaking invited signups.
create or replace function public.redeem_invite(p_code text)
returns text language plpgsql security definer set search_path = public as $$
declare inv record; existing text;
begin
  if auth.uid() is null then return null; end if;

  select role into existing from public.user_roles where user_id = auth.uid();
  if existing is not null then return existing; end if;  -- already provisioned

  if p_code is not null then
    select * into inv from public.invites where code = p_code and used_by is null limit 1;
  end if;

  if inv.code is null then
    insert into public.user_roles(user_id, role) values (auth.uid(), 'teacher')
      on conflict (user_id) do nothing;
    return 'teacher';
  end if;

  insert into public.user_roles(user_id, role, district_id)
    values (auth.uid(), inv.role, inv.district_id)
    on conflict (user_id) do update set role = excluded.role, district_id = excluded.district_id;
  update public.invites set used_by = auth.uid(), used_at = now() where id = inv.id;
  return inv.role;
end;
$$;
grant execute on function public.redeem_invite(text) to authenticated;

-- ── list_specialists(): scope to caller's district ─────────-
create or replace function public.list_specialists()
returns table (user_id uuid, email text, display_name text, role text)
language sql security definer set search_path = public as $$
  select
    ur.user_id,
    lower((select u.email::text from auth.users u where u.id = ur.user_id)) as email,
    coalesce(nullif(ud.data->>'_displayName',''),
             (select u.email::text from auth.users u where u.id = ur.user_id)) as display_name,
    ur.role
  from public.user_roles ur
  left join public.user_data ud on ud.user_id = ur.user_id
  where ur.role in ('behaviorist','school_psych')
    and ur.district_id = public.get_my_district()
  order by display_name;
$$;
grant execute on function public.list_specialists() to authenticated;
