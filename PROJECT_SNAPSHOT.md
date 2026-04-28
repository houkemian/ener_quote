# EnerQuote 会话热启动快照（1页）

更新时间：2026-04-27

## 一句话现状
- 项目已进入“移动端优先 + 订阅闭环”阶段：认证、支付提权、设置页权益展示、账号删除主链路已跑通，可用于持续迭代增长功能。

## 数据库口径（已统一）
- 当前后端运行数据库为 **PostgreSQL**（`backend/app/db/database.py` 通过 `DATABASE_URL` 或 `DB_*` 变量连接）。
- ORM 使用 SQLAlchemy，当前主链路模型为 `iam_users`、`user_settings`、`payment_orders`、`paddle_webhook_events`。
- 历史文档中出现的 SQLite / `pv_ess.db` 口径已废弃，不再作为对外说明与实施基线。

## 当前已落地能力（以代码为准）
- 账号体系
  - 邮箱密码登录（邮箱格式前置校验）。
  - 邮箱 OTP 注册（发送验证码 + 校验注册 + 成功即销毁 OTP）。
  - 忘记密码（邮件验证码找回）。
  - OAuth 登录：Google / Microsoft 均已接入（前后端均有实现）。
- 会话与权限
  - JWT 携带 `tier`，并支持 `POST /api/v1/auth/refresh` 无感刷新权限。
  - 后端按 `tier + pro_expire_date` 计算有效权益，过期自动回落 `FREE`。
  - 前端全局 401 拦截，避免误拦截 `/auth/*`。
- 支付与提权
  - Paddle：`/api/v1/payment/checkout` 创建交易，Webhook 验签后提权/降权。
  - RevenueCat：`/api/v1/payment/webhook/revenuecat` 处理 `INITIAL_PURCHASE/RENEWAL/BILLING_ISSUE/CANCELLATION/EXPIRATION`。
  - 支付事件已落库（`PaymentOrder`）并做 event_id 幂等去重。
  - 前端支持支付后短轮询刷新 token/tier，降低 webhook 延迟导致的“假 pending”。
- 设置与付费墙
  - 设置页展示账号邮箱、当前 tier、PRO 到期时间。
  - PRO 权限控制：品牌配置和成本参数（`pv_cost_per_kw`、`ess_cost_per_kwh`、`margin_pct`）已在后端鉴权。
  - Android 端走 RevenueCat 订阅流；Web 端走 Paddle WebView 托管结账。
- 账号删除
  - App 内支持删除账号（调用 `DELETE /api/v1/auth/logout`）。
  - 同时提供网页账户删除入口（`/account-deletion` + OTP 验证流程）。

## 关键接口速记
- 认证与注册
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/auth/send-otp`
  - `POST /api/v1/auth/verify-otp-and-register`
  - `POST /api/v1/auth/forgot-password`
  - `POST /api/v1/auth/reset-password`
  - `POST /api/v1/auth/oauth/google`
  - `POST /api/v1/auth/oauth/microsoft`
  - `DELETE|POST /api/v1/auth/logout`
- 支付
  - `POST /api/v1/payment/checkout`
  - `POST /api/v1/payment/webhook`
  - `POST /api/v1/payment/webhook/revenuecat`
  - `GET /api/v1/payment/checkout-ui`
- 设置
  - `GET /api/v1/settings/me`
  - `PUT /api/v1/settings/me`

## 快速回忆入口文件
- 后端
  - `backend/app/main.py`
  - `backend/app/api/v1/auth.py`
  - `backend/app/api/v1/payment.py`
  - `backend/app/api/v1/settings.py`
  - `backend/app/modules/iam/router.py`
  - `backend/app/modules/iam/models.py`
- 前端
  - `frontend/lib/core/network/api_client.dart`
  - `frontend/lib/screens/login_screen.dart`
  - `frontend/lib/screens/register_screen.dart`
  - `frontend/lib/screens/register_otp_screen.dart`
  - `frontend/lib/screens/settings_screen.dart`
  - `frontend/lib/core/billing/revenuecat_service.dart`

## 关键配置（最易忘）
- API Base URL：`https://api.dothings.one/api/v1`
- OAuth（前端编译注入）
  - `GOOGLE_SERVER_CLIENT_ID`
  - `MICROSOFT_OAUTH_CLIENT_ID`
  - `MICROSOFT_TENANT`（可选，默认 `common`）
- Paddle（后端）
  - `PADDLE_API_KEY`
  - `PADDLE_PRICE_ID`
  - `PADDLE_CLIENT_TOKEN`
  - `PADDLE_WEBHOOK_SECRET`
  - `PADDLE_CHECKOUT_SUCCESS_REDIRECT_URL`
  - `PADDLE_CHECKOUT_CLOSED_REDIRECT_URL`
- RevenueCat（后端）
  - `REVENUECAT_WEBHOOK_AUTH`
- 通用
  - SMTP：`SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASSWORD/SMTP_FROM_NAME/SMTP_USE_TLS`
  - Redis：`REDIS_HOST/REDIS_PORT/REDIS_DB/REDIS_PASSWORD`
  - 配置模板：`backend/.env.example`

## 常用命令
- 后端本地：`cd backend && uvicorn app.main:app --reload`
- 前端本地：`cd frontend && flutter run`
- 服务端部署：`docker compose pull && docker compose up -d`

## 下一步待办（按优先级）
- P0（稳定性）
  - 补齐 OTP、支付 Webhook、OAuth 的集成测试和回归脚本。
  - 修正前端仍存在的少量硬编码英文文案（统一走 `l10n`）。
  - 为支付/鉴权关键链路补充结构化日志字段（`request_id/user_id/route/event_id`）。
- P1（增长与订阅运营）
  - 扩展订阅模型：从纯 `FREE/PRO` 升级为 `status + period + cancel_at_period_end`。
  - 增加“管理订阅（Customer Portal）”入口与审计日志。
  - 明确 Android（RevenueCat）与 Web（Paddle）跨端权益对账策略。
- P2（账号与产品）
  - Apple 登录。
  - 游客模式（只读/受限功能）。
  - Feature Flag 网关（后端统一 `has_feature(user, feature_key)`）。
