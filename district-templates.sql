-- ============================================================
--  BehaviorLog Pro — District document templates
--  Run AFTER districts.sql / rls-districts.sql. Idempotent.
--
--  One official BIP / FBA / Goal template per district, set by a
--  district admin (or founder) and inherited read-only by every
--  specialist in that district. Individual behaviorists can still
--  keep a PERSONAL override in their own user_data blob (handled
--  app-side); this table is only the shared district default.
--
--  Content is the EXTRACTED PLAIN TEXT of the district's template
--  (parsed client-side from .txt/.pdf/.docx) — it is a structure
--  guide for the AI, never student data.
-- ============================================================

create table if not exists public.district_templates (
  district_id uuid not null references public.districts(id) on delete cascade,
  kind        text not null check (kind = any (array['bip','fba','goal'])),
  content     text not null default '',
  file_name   text,
  updated_by  uuid,
  updated_at  timestamptz not null default now(),
  primary key (district_id, kind)
);

alter table public.district_templates enable row level security;

-- READ: every authenticated member of the district (specialists inherit); founders global.
drop policy if exists dt_select on public.district_templates;
create policy dt_select on public.district_templates for select to authenticated
  using (public.is_founder() or district_id = public.get_my_district());

-- WRITE: district admin of that same district, or a founder. (upsert needs insert+update.)
drop policy if exists dt_insert on public.district_templates;
create policy dt_insert on public.district_templates for insert to authenticated
  with check (public.is_founder()
              or (public.get_my_role() = 'admin' and district_id = public.get_my_district()));

drop policy if exists dt_update on public.district_templates;
create policy dt_update on public.district_templates for update to authenticated
  using (public.is_founder()
         or (public.get_my_role() = 'admin' and district_id = public.get_my_district()))
  with check (public.is_founder()
              or (public.get_my_role() = 'admin' and district_id = public.get_my_district()));

drop policy if exists dt_delete on public.district_templates;
create policy dt_delete on public.district_templates for delete to authenticated
  using (public.is_founder()
         or (public.get_my_role() = 'admin' and district_id = public.get_my_district()));

grant select, insert, update, delete on public.district_templates to authenticated;
