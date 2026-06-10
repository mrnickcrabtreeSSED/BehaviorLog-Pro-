-- ============================================================
--  BehaviorLog Pro — Specialist Directory
--  Paste into Supabase → SQL Editor → Run. Safe to re-run.
--
--  Powers the teacher's "Share with…" dropdown: a list of every
--  user whose role is behaviorist or school_psych, with their
--  display name + login email. Security-definer so a teacher can
--  see the roster without a SELECT policy on user_roles (which is
--  locked to auth.uid() = user_id). Returns ONLY specialists —
--  never teachers, never admins, never any student data.
--
--  Single-district (v1): returns all specialists in the app. When
--  the district/org layer lands (Goal 4), add a district filter
--  here (e.g. join a district_members table and filter to the
--  caller's district_id) — the app-side dropdown needs no change.
-- ============================================================

create or replace function public.list_specialists()
returns table (
  user_id      uuid,
  email        text,
  display_name text,
  role         text
)
language sql
security definer
set search_path = public
as $$
  select
    ur.user_id,
    lower((select u.email::text from auth.users u where u.id = ur.user_id)) as email,
    coalesce(
      nullif(ud.data->>'_displayName', ''),
      (select u.email::text from auth.users u where u.id = ur.user_id)
    ) as display_name,
    ur.role
  from public.user_roles ur
  left join public.user_data ud on ud.user_id = ur.user_id
  where ur.role in ('behaviorist', 'school_psych')
  order by display_name;
$$;

grant execute on function public.list_specialists() to authenticated;

-- Verify (optional):
-- select * from public.list_specialists();
