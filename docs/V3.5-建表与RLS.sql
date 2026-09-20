-- ============================================================================
--  个人主页 V3.5 —— 反馈表建表脚本（Supabase / PostgreSQL）
--
--  用法：打开 Supabase 控制台 → 你的项目 → 左侧 SQL Editor → New query
--        → 把本文件全文粘进去 → Run
--        跑完应该显示 Success. No rows returned.
--
--  设计原则（对应课件「发布反馈与持续改进」那一节）：
--    1) 访客只能"插入"这一件事：不能读、不能改、不能删 → 反馈不会公开
--    2) 前端只用 publishable key（旧称 anon key），它本来就是公开的
--    3) secret key（旧称 service_role key）与数据库密码**永不进前端**
--
--  红线：本文件里没有任何密钥。不要把数据库密码写进这里、也不要写进仓库。
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1) 建表
-- ---------------------------------------------------------------------------
create table if not exists public.feedback (
  id         bigint generated always as identity primary key,
  name       text,                                  -- 称呼，可选
  relation   text,                                  -- 和我的关系，可选
  device     text,                                  -- 设备，前端已设为必填
  message    text not null,                         -- 内容，必填
  version    text,                                  -- 提交时的网站版本，自动附带
  created_at timestamptz not null default now(),    -- 服务端时间，访客改不了

  -- 长度护栏：与前端 maxlength 对齐，防止误粘贴超长内容把表撑大
  constraint feedback_message_len check (char_length(message) between 1 and 2000),
  constraint feedback_name_len    check (name is null or char_length(name) <= 40)
);

-- 说明：device / relation 故意**不加** in (...) 白名单约束。
--       原因：前端选项一旦增减，白名单会让正常提交直接失败；
--       这类校验放在前端做即可，数据库只守"长度"和"非空"这两条硬底线。


-- ---------------------------------------------------------------------------
-- 2) 打开行级安全（RLS）—— 关键步骤，别漏
-- ---------------------------------------------------------------------------
alter table public.feedback enable row level security;

-- 默认情况下：RLS 打开后没有任何策略 = 谁都读不到、也写不进。
-- 下面只开"插入"这一扇门，且只对匿名访客（anon）开放。
drop policy if exists feedback_anon_insert on public.feedback;
create policy feedback_anon_insert
  on public.feedback
  for insert
  to anon
  with check (true);

-- 注意：这里**没有** select / update / delete 策略。
--       所以匿名访客只能提交，无法读取别人的反馈 → 满足"反馈不会公开"。


-- ---------------------------------------------------------------------------
-- 3) 显式授权（Supabase 一般会自动授权，写出来更稳、也更好读）
-- ---------------------------------------------------------------------------
grant usage on schema public to anon;
grant insert on table public.feedback to anon;                 -- 只给 insert
revoke select, update, delete on table public.feedback from anon;

-- identity 主键要取一次序列的下一个值，因此需要序列的使用权
grant usage on sequence public.feedback_id_seq to anon;


-- ---------------------------------------------------------------------------
-- 4) 让你自己看反馈更方便
-- ---------------------------------------------------------------------------
create index if not exists feedback_created_at_idx
  on public.feedback (created_at desc);


-- ---------------------------------------------------------------------------
-- 5) 自检（可选，逐条跑一遍看结果）
-- ---------------------------------------------------------------------------

-- 5.1 确认表已建好、RLS 已打开（relrowsecurity 应为 true）
-- select relname, relrowsecurity from pg_class where relname = 'feedback';

-- 5.2 确认只有一条策略，且 cmd = INSERT、roles = {anon}
-- select policyname, cmd, roles, with_check from pg_policies where tablename = 'feedback';

-- 5.3 看最近的反馈（按时间倒序）
-- select id, name, relation, device, left(message, 60) as message_head, version, created_at
--   from public.feedback
--  order by created_at desc
--  limit 20;

-- 5.4 从网页提交一条测试反馈后，删掉它
-- delete from public.feedback where message like '%测试%';


-- ---------------------------------------------------------------------------
-- 6) 一个重要提醒：SQL Editor 里验证不了 RLS
-- ---------------------------------------------------------------------------
-- SQL Editor 是以表所有者身份执行的，所有者天然绕过 RLS。
-- 所以在 Editor 里 select * 能查到数据，**不代表**访客也能查到。
-- 想知道匿名访客到底能做什么，只有两个办法：
--   a) 用前端页面真实提交一次（推荐，见《V3.5-反馈后台接入说明.md》第 6 节）
--   b) 用 curl / 浏览器开发者工具，带上 publishable key 打 REST 接口：
--        GET  https://<项目>.supabase.co/rest/v1/feedback?select=*     → 期望空数组 []
--        POST https://<项目>.supabase.co/rest/v1/feedback             → 期望 201
--      两个请求都要带请求头：apikey: <publishable key>


-- ---------------------------------------------------------------------------
-- 7) 交付前的一句话总结（可直接写进作业说明）
-- ---------------------------------------------------------------------------
-- feedback 表开启 RLS，仅授予 anon 角色 INSERT 权限，前端使用 publishable key
-- 直连 PostgREST 插入；数据库中不存在任何面向匿名访客的读取路径，
-- 因此访客提交的反馈除站点作者外无人可见。
