-- ============================================================
--  BehaviorLog Pro — Shared behavior library (P4)
--  Run in Supabase SQL Editor. Idempotent.
--
--  A specialist (behaviorist/school psych) who has been shared a
--  student can define behaviors (with operational definitions +
--  measure) FOR that student; the connected teacher (the student's
--  owner) can then use them when recording. Behaviors are denormalized
--  here so the teacher needs no access to the specialist's library.
--  Scoped per (owner, student) — only behaviors applied to that student.
-- ============================================================

create table if not exists public.shared_behaviors (
  id            uuid primary key default uuid_generate_v4(),
  owner_id      uuid not null,          -- teacher who owns the student
  specialist_id uuid not null,          -- specialist who assigned the behavior
  student_id    text not null,          -- client.id inside the owner's user_data
  beh_id        text not null,          -- behavior id (from the specialist's library)
  label         text not null,
  icon          text not null default '',
  op_def        text not null default '',
  measure       text not null default 'duration',
  created_at    timestamptz not null default now(),
  unique(owner_id, student_id, beh_id)
);
alter table public.shared_behaviors enable row level security;
create index if not exists shared_behaviors_owner_idx on public.shared_behaviors(owner_id, student_id);
grant select, insert, update, delete on public.shared_behaviors to authenticated;

-- The specialist manages rows they authored — but only for a student actually
-- shared with them (verified against student_shares by their JWT email).
drop policy if exists "specialist manages shared behaviors" on public.shared_behaviors;
create policy "specialist manages shared behaviors" on public.shared_behaviors for all
  using (specialist_id = auth.uid())
  with check (
    specialist_id = auth.uid()
    and exists (
      select 1 from public.student_shares s
      where s.owner_id = shared_behaviors.owner_id
        and s.student_id = shared_behaviors.student_id
        and lower(s.grantee_email) = lower(coalesce(auth.jwt() ->> 'email',''))
    )
  );

-- The owner (teacher) can read the behaviors assigned to their students.
drop policy if exists "owner reads shared behaviors" on public.shared_behaviors;
create policy "owner reads shared behaviors" on public.shared_behaviors for select
  using (owner_id = auth.uid());

-- Verify (optional):
-- select owner_id, student_id, label, measure from public.shared_behaviors;
