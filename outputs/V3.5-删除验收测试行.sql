-- V3.5 cleanup: remove the two test rows that carry the check markers.
-- How to run: Supabase dashboard -> SQL Editor -> New query -> paste all -> Run.
-- Why you have to do it: the anon role only has INSERT (no DELETE / no UPDATE),
-- which is on purpose, so these two rows can only be removed from the dashboard.

-- Step 1: look at them first (this is also the eyeball check from slide P28)
select id, name, message, created_at
from public.feedback
where message = 'SELFCHECK-20260921-A';

select id, name, message, created_at
from public.messages
where message = 'SELFCHECK-20260921-B';

-- Step 2: delete
delete from public.messages where message = 'SELFCHECK-20260921-B';
delete from public.feedback where message = 'SELFCHECK-20260921-A';

-- Step 3: both counts must be 0
select count(*) as feedback_test_rows from public.feedback where message = 'SELFCHECK-20260921-A';
select count(*) as message_test_rows  from public.messages where message = 'SELFCHECK-20260921-B';
