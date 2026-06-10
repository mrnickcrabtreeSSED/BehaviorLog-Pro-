-- ============================================================
--  BehaviorLog Pro — close the self-promotion hole (Phase 3 tail)
--  Run AFTER the redeem_invite()-based app (commit c0eb50e+) is live.
--
--  Before: users_insert_own_role allowed a brand-new user to INSERT
--  their own user_roles row with ANY role (e.g. 'admin') on first login.
--  After: a self-insert may only be role='teacher' with no district.
--  Elevation + district assignment now happen server-side via
--  redeem_invite() (security-definer) or by an admin/founder — none of
--  which rely on this policy, so invited signups keep working.
-- ============================================================

drop policy if exists "users_insert_own_role" on public.user_roles;
create policy "users_insert_own_role" on public.user_roles for insert
  with check (auth.uid() = user_id and role = 'teacher' and district_id is null);
