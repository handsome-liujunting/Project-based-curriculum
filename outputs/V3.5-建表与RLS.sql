-- ============================================================================
--  个人主页 V3.5 —— 建表脚本（Supabase / PostgreSQL）
--
--  本文件一次建好两张表：
--    · public.feedback —— 反馈表，**私密**：访客只能插入，读不到别人的反馈
--    · public.messages —— 留言板，**公开**：访客能读也能写（页面上的留言板）
--
--  用法：打开 Supabase 控制台 → 你的项目 → 左侧 SQL Editor → New query
--        → 把本文件全文粘进去 → Run
--        跑完应该显示 Success. No rows returned.
--
--  设计原则（对应课件「发布反馈与持续改进」那一节）：
--    1) 反馈表：访客只能"插入"这一件事：不能读、不能改、不能删 → 反馈不会公开
--    2) 留言板：访客可以"读 + 插入"，但依然不能改、不能删
--    3) 两张表都用 RLS + 显式策略管权限，不靠"关掉 RLS"来消错
--    4) 前端只用 publishable key（旧称 anon key），它本来就是公开的
--    5) secret key（旧称 service_role key）与数据库密码**永不进前端**
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
-- 下面只开"插入"这一扇门。
--
-- 为什么是 anon + authenticated（对应课件「角色 × 权限对照」那一页）：
--   · anon（publishable key，未登录访客）→ 允许提交    ← 本站访客全部属于这一类
--   · authenticated（已登录用户）        → 也允许提交
--   · 两者都**不能**读取/修改/删除 → 因为下面只有 INSERT 策略，
--     没有 select / update / delete 策略，而 RLS 的默认就是拒绝。
--     这就是课件说的"按策略决定"：不去关 RLS、也不放开全部权限。
drop policy if exists feedback_anon_insert on public.feedback;
create policy feedback_anon_insert
  on public.feedback
  for insert
  to anon, authenticated
  with check (true);

-- 注意：这里**没有** select / update / delete 策略。
--       所以访客只能提交，无法读取别人的反馈 → 满足"反馈不会公开"。
--       红线：不要为了"消掉报错"而关闭 RLS，也不要加 using (true) 的读策略。


-- ---------------------------------------------------------------------------
-- 3) 显式授权（Supabase 一般会自动授权，写出来更稳、也更好读）
-- ---------------------------------------------------------------------------
grant usage on schema public to anon;
grant insert on table public.feedback to anon;                 -- 只给 insert
revoke select, update, delete on table public.feedback from anon;

-- identity 主键要取一次序列的下一个值，因此需要序列的使用权
grant usage on sequence public.feedback_id_seq to anon;

-- 已登录用户同样只给 insert（对应上面的 anon + authenticated 策略）
grant usage on schema public to authenticated;
grant insert on table public.feedback to authenticated;
revoke select, update, delete on table public.feedback from authenticated;
grant usage on sequence public.feedback_id_seq to authenticated;


-- ---------------------------------------------------------------------------
-- 4) 让你自己看反馈更方便
-- ---------------------------------------------------------------------------
create index if not exists feedback_created_at_idx
  on public.feedback (created_at desc);


-- ---------------------------------------------------------------------------
-- 5) 留言板表 messages —— 和 feedback 正好相反：这张表是**公开可读**的
--    需求原话："用户现在还是不能正式反馈，最后再给我加一个留言板"，
--    形态已确认：公开留言板，访客写下的话直接展示在页面上，所有人可见。
--    因此策略里必须有 select；而 update / delete 一律不开。
-- ---------------------------------------------------------------------------

-- 5.1 建表（只放"公开也没关系"的字段：昵称 + 内容 + 时间）
create table if not exists public.messages (
  id         bigint generated always as identity primary key,
  name       text,                                  -- 昵称，可选；前端留空时显示"匿名"
  message    text not null,                         -- 留言内容，必填
  created_at timestamptz not null default now(),    -- 服务端时间，访客改不了

  -- 长度护栏：前端 maxlength=280，这里放到 300 留一点余量，
  -- 保证正常提交永远不会被数据库打回，同时挡住恶意塞进几十万字的请求。
  constraint messages_message_len check (char_length(message) between 1 and 300),
  constraint messages_name_len    check (name is null or char_length(name) <= 20)
);

-- 5.2 打开 RLS，然后放行"读"和"写"两扇门
alter table public.messages enable row level security;

-- 读：所有人都能看留言。这就是留言板的全部意义，所以 using (true)。
drop policy if exists messages_public_read on public.messages;
create policy messages_public_read
  on public.messages
  for select
  to anon, authenticated
  using (true);

-- 写：所有人都能留一条。
-- 注意这里**没有** update / delete 策略 → 访客既改不了、也删不掉留言，
-- 连自己刚留的那条都删不了；要删只能你（表所有者）在控制台里删。
drop policy if exists messages_public_insert on public.messages;
create policy messages_public_insert
  on public.messages
  for insert
  to anon, authenticated
  with check (true);

-- 5.3 显式授权（读一份、写一份）
grant usage on schema public to anon;
grant select, insert on table public.messages to anon;          -- 公开读 + 可插入
revoke update, delete on table public.messages from anon;
grant usage on sequence public.messages_id_seq to anon;

grant usage on schema public to authenticated;
grant select, insert on table public.messages to authenticated;
revoke update, delete on table public.messages from authenticated;
grant usage on sequence public.messages_id_seq to authenticated;

-- 5.4 让你按时间看留言更快
create index if not exists messages_created_at_idx
  on public.messages (created_at desc);

-- 5.5 关于安全边界，务必读一遍（这几条会原样写进交付说明）
--   · 留言板是公开的，所以表里只放昵称/内容/时间；
--     不要把邮箱、IP、设备型号、内部备注之类的字段加进来。
--   · 访客能读能写、但不能改不能删 —— 想让哪条消失，只能你在控制台删。
--   · 公开可写 = 谁都能刷。课件的原话是"防误点 ≠ 防恶意刷留言"：
--     真要防刷得靠速率限制 / 验证码，本作业没做，在报告里如实写明。
--   · 前端渲染留言的地方一律用 textContent 逐字插入（见 js/board.js），
--     绝不拼 HTML 字符串 —— 否则有人留一句 <script>… 就成了 XSS。


-- ---------------------------------------------------------------------------
-- 6) 自检（可选，逐条跑一遍看结果）
-- ---------------------------------------------------------------------------

-- 6.1 确认表已建好、RLS 已打开（relrowsecurity 应为 true）
-- select relname, relrowsecurity from pg_class where relname = 'feedback';

-- 6.2 确认只有一条策略，且 cmd = INSERT、roles = {anon,authenticated}
-- select policyname, cmd, roles, with_check from pg_policies where tablename = 'feedback';

-- 6.3 看最近的反馈（按时间倒序）
-- select id, name, relation, device, left(message, 60) as message_head, version, created_at
--   from public.feedback
--  order by created_at desc
--  limit 20;

-- 6.4 从网页提交一条测试反馈后，删掉它
-- delete from public.feedback where message like '%测试%';

-- 6.5 确认留言板表与策略：应该有**两条**策略
--     （SELECT 的 messages_public_read 与 INSERT 的 messages_public_insert）
-- select policyname, cmd, roles, qual, with_check from pg_policies where tablename = 'messages';

-- 6.6 看最近的留言
-- select id, name, left(message, 60) as message_head, created_at
--   from public.messages
--  order by created_at desc
--  limit 20;

-- 6.7 删掉测试留言（留言板你不主动删，它会一直挂在页面上）
-- delete from public.messages where message like '%测试%';


-- ---------------------------------------------------------------------------
-- 7) 一个重要提醒：SQL Editor 里验证不了 RLS
-- ---------------------------------------------------------------------------
-- SQL Editor 是以表所有者身份执行的，所有者天然绕过 RLS。
-- 所以在 Editor 里 select * 能查到数据，**不代表**访客也能查到。
-- 想知道匿名访客到底能做什么，只有两个办法：
--   a) 用前端页面真实提交一次（推荐，见《V3.5-反馈后台接入说明.md》第 6 节）
--   b) 用 curl / 浏览器开发者工具，带上 publishable key 打 REST 接口：
--        GET  https://<项目>.supabase.co/rest/v1/feedback?select=*     → 期望空数组 []
--        POST https://<项目>.supabase.co/rest/v1/feedback             → 期望 201
--        GET  https://<项目>.supabase.co/rest/v1/messages?select=*      → 期望 200 且有留言
--        POST https://<项目>.supabase.co/rest/v1/messages               → 期望 201
--      两个请求都要带请求头：apikey: <publishable key>
--      注意这两行期望值的差别：feedback 是 []（读不到），messages 有内容（公开可读），
--      这一"空"一"有"正好说明两张表的权限是分开设计的、没有互相污染。


-- ---------------------------------------------------------------------------
-- 8) 交付前的一句话总结（可直接写进作业说明）
-- ---------------------------------------------------------------------------
-- feedback 表开启 RLS，仅授予 anon / authenticated 两个角色 INSERT 权限，
-- 前端使用 publishable key 直连 PostgREST 插入；数据库中不存在任何面向
-- 访客的读取路径，因此访客提交的反馈除站点作者外无人可见。
--
-- messages 表同样开启 RLS，但策略是"公开读 + 可插入、不可改不可删"：
-- 页面上的留言板只取最近 30 条展示，任何人都能留一句话，
-- 但任何人都无法修改或删除别人的留言，删除权只属于站点作者。
