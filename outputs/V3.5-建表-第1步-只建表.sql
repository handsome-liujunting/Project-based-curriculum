-- ============================================================
-- step 1 / 2 : create the two tables only (no policies, no grants)
-- paste this WHOLE file into the Supabase SQL Editor and press Run.
-- expected result: "Success. No rows returned"
-- ============================================================

create table if not exists public.feedback (
  id         bigint generated always as identity primary key,
  name       text,
  relation   text,
  device     text,
  message    text not null,
  version    text,
  created_at timestamptz not null default now(),
  constraint feedback_message_len check (char_length(message) between 1 and 2000),
  constraint feedback_name_len    check (name is null or char_length(name) <= 40)
);

create table if not exists public.messages (
  id         bigint generated always as identity primary key,
  name       text,
  message    text not null,
  created_at timestamptz not null default now(),
  constraint messages_message_len check (char_length(message) between 1 and 300),
  constraint messages_name_len    check (name is null or char_length(name) <= 20)
);
