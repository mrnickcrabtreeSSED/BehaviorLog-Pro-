-- ============================================================
--  BehaviorLog Pro — Founder Console data layer, Phase 4
--  Run AFTER rls-districts.sql. Idempotent.
--
--  founder_list_users(): the only thing a founder can't get from
--  plain RLS queries is each user's auth email (auth.users isn't
--  client-readable). This security-definer fn returns the full
--  cross-district roster (guarded to founders only). Districts +
--  per-district counts are derived client-side from this + the
--  districts table (which founders can already read via RLS).
-- ============================================================

create or replace function public.founder_list_users()
returns table (
  user_id       uuid,
  email         text,
  display_name  text,
  role          text,
  district_id   uuid,
  district_name text,
  students      int
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_founder() then
    return;  -- non-founders get nothing
  end if;
  return query
    select
      ur.user_id,
      lower((select u.email::text from auth.users u where u.id = ur.user_id)) as email,
      coalesce(nullif(ud.data->>'_displayName',''),
               (select u.email::text from auth.users u where u.id = ur.user_id)) as display_name,
      ur.role,
      ur.district_id,
      d.name as district_name,
      coalesce(jsonb_array_length(ud.data->'clients'), 0) as students
    from public.user_roles ur
    left join public.user_data ud on ud.user_id = ur.user_id
    left join public.districts d on d.id = ur.district_id
    order by d.name nulls last, ur.role, display_name;
end;
$$;

grant execute on function public.founder_list_users() to authenticated;
