/* =========================================================
   V3.5 —— 反馈功能配置（唯一需要你手动填写的文件）

   怎么填（对接 Supabase 时）：
     1. 打开 Supabase 控制台 → 你的项目 → Settings → API
     2. 复制 Project URL          → 填到下面的 url
     3. 复制 publishable key      → 填到下面的 anonKey
        （旧项目里叫 anon key / anon public key，作用相同）

   安全红线（课件第 21 页）：
     · publishable / anon key 本来就是要公开给浏览器的，放这里没问题；
     · secret key（旧称 service_role key）和数据库密码**绝对不能**填进来，
       也不能出现在这个仓库的任何文件里 —— 它们能绕过 RLS，等于把后台
       交给了所有访客。如果哪天不小心泄露，立刻去控制台轮换（重置）密钥。

   没填之前：页面照常打开，反馈表单会显示"通道待接入"，点提交也不会报错。
   ========================================================= */

window.FEEDBACK_CONFIG = {
  /* Supabase 项目地址，形如 https://abcdefghijklmn.supabase.co（结尾不要带 /） */
  url: "",

  /* publishable key（可以公开） */
  anonKey: "",

  /* 数据表名：与建表脚本保持一致 */
  table: "feedback",

  /* 网站版本：提交时自动附带，访客不用填 */
  siteVersion: "V3.5",

  /* 单次请求超时（毫秒） */
  timeoutMs: 12000
};
