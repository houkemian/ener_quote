# EnerQuote 会话热启动快照（1页）

更新时间：2026-04-09

## 一句话现状
- 项目已转为移动端优先（Flutter App），线上运行仅保留 `backend + postgres + redis`，前端容器已移除。

## 当前核心能力
- 登录：邮箱格式前置校验；401 全局拦截已修复误触发。
- 注册：已切换为邮箱 6 位 OTP 流程（App 内闭环）。
- 忘记密码：邮件验证码流程可用。
- 部署：GitHub Actions 仅构建后端镜像，SSH 执行 `docker compose up -d`。

## OTP 注册关键链路（必须记住）
- `POST /api/v1/auth/send-otp`
  - 生成 6 位验证码并写入 Redis `register_otp:{email}`，TTL=300 秒。
  - 异步 SMTP 发邮件。
- `POST /api/v1/auth/verify-otp-and-register`
  - 校验 OTP -> 创建用户 -> 签发 JWT。
  - 成功后立即删除 Redis OTP（防重放）。

## 快速回忆入口文件
- 后端：
  - `backend/app/modules/iam/router.py`
  - `backend/app/modules/iam/schemas.py`
  - `backend/app/utils/email_sender.py`
  - `backend/app/core/config.py`
- 前端：
  - `frontend/lib/core/network/api_client.dart`
  - `frontend/lib/screens/register_screen.dart`
  - `frontend/lib/screens/register_otp_screen.dart`
  - `frontend/lib/screens/login_screen.dart`

## 关键配置（最易忘）
- API Base URL：`https://api.dothings.one/api/v1`
- Compose 后端端口映射：`8000:${BACKEND_PORT}`
- 服务器 `.env` 路径：`/home/ubuntu/ener_quote/.env`
- SMTP：`SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASSWORD/SMTP_FROM_NAME/SMTP_USE_TLS`
- Redis：`REDIS_HOST/REDIS_PORT/REDIS_DB/REDIS_PASSWORD`
- 配置模板：`backend/.env.example`

## 常用命令
- 后端本地：`cd backend && uvicorn app.main:app --reload`
- 前端本地：`cd frontend && flutter run`
- 服务器部署：`docker compose pull && docker compose up -d`

## 下一步待办（优先）
- Google 登录
- Outlook（Microsoft）登录
- OTP 集成测试：重发限制、过期行为、成功即销毁验证码
