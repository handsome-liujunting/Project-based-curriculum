-- ============================================================
-- step 2 / 2 : RLS + policies + grants + indexes
-- run this AFTER step 1 succeeded.
-- expected result: "Success. No rows returned"
--
-- diagnostic: if this fails with   role "anon" does not exist
-- then you are NOT in a Supabase project (Supabase has the roles
-- anon and authenticated built in). Tell me where you are running this.
-- ============================================================

alter table public.feedback enable row level security;
alter table public.messages enable row level security;

drop policy if exists feedback_anon_insert on public.feedback;
create policy feedback_anon_insert on public.feedback
  for insert to anon, authenticated with check (true);

drop policy if exists messages_public_read on public.messages;
create policy messages_public_read on public.messages
  for select to anon, authenticated using (true);

drop policy if exists messages_public_insert on public.messages;
create policy messages_public_insert on public.messages
  for insert to anon, authenticated with check (true);

grant usage on schema public to anon;
grant insert on table public.feedback to anon;
revoke select, update, delete on table public.feedback from anon;
grant usage on sequence public.feedback_id_seq to anon;

grant usage on schema public to authenticated;
grant insert on table public.feedback to authenticated;
revoke select, update, delete on table public.feedback from authenticated;
grant usage on sequence public.feedback_id_seq to authenticated;

grant select, insert on table public.messages to anon;
revoke update, delete on table public.messages from anon;
grant usage on sequence public.messages_id_seq to anon;

grant select, insert on table public.messages to authenticated;
revoke update, delete on table public.messages from authenticated;
grant usage on sequence public.messages_id_seq to authenticated;

create index if not exists feedback_created_at_idx on public.feedback (created_at desc);
create index if not exists messages_created_at_idx on public.messages (created_at desc);
