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
- ~~Google 登录~~
- ~~Outlook（Microsoft）登录~~
- OTP 集成测试：重发限制、过期行为、成功即销毁验证码

---

## 产品与付费墙完善清单（新增专区）

> 目标：从“可用”升级到“可运营、可增长、可对账”的订阅系统。

### A. 通用能力完善（高优先）
- 鉴权与会话
  - 引入 `refresh token + access token` 双令牌机制。
  - 增加设备会话管理（查看登录设备、远程下线）。
  - 增加登录风控（邮箱/IP 频率限制、异常登录告警）。
- 账号体系
  - 落地 Google / Microsoft 登录（与当前 OTP 流并存）。
  - 增加邮箱验证状态（`email_verified`）与未验证限制策略。
  - 支持账号注销与数据导出（合规项预留）。
- 可观测性
  - 统一结构化日志（建议包含 `request_id`、`user_id`、`route`）。
  - 接入错误上报（如 Sentry）。
  - 埋点关键转化漏斗（注册、支付发起、支付成功、退款）。
- 测试与质量
  - 补齐 OTP 全链路集成测试（重发限制、过期、成功即销毁）。
  - 增加支付 webhook 幂等与延迟到达测试。
  - CI 增加最小 e2e（登录 -> 升级 -> 权限生效）。

### B. 付费墙增强（重点）
- 订阅状态模型
  - 不只 `FREE/PRO`，新增 `subscription_status`：`active/trialing/past_due/canceled/paused`。
  - 新增关键字段：`plan_id`、`current_period_end`、`next_billing_at`、`cancel_at_period_end`。
  - 设置页展示订阅状态与到期时间，降低客服沟通成本。
- 权限网关（Feature Flags）
  - 后端统一 `has_feature(user, feature_key)`，避免前端硬编码 tier。
  - 支持按功能开关：`export_pdf`、`no_watermark`、`advanced_pvgis`、`team_seats`。
- Webhook 工程化
  - 支付事件落库（`payment_events`：`event_id/type/raw/processed_at`）。
  - 幂等处理：同 `event_id` 只处理一次。
  - 失败重试与告警机制，避免“已支付但前端未生效”。
  - 每日对账任务：与 Paddle 订阅状态定时回写本地。
- 用户自助门户（Customer Portal）
  - 在 App 设置页新增“管理订阅”按钮（仅登录用户可见，建议 PRO/FREE 都可见）。
  - 后端调用 Paddle API 生成 Customer Portal 链接并返回前端。
  - 用户点击后跳转网页自助完成：换绑信用卡、下载历史发票、取消订阅。
  - 记录门户跳转审计日志（`user_id`、`portal_url_id`、`created_at`、`ip`）。
- 套餐与增长
  - 免费试用（7/14 天）。
  - 优惠码与活动（首月折扣、限时活动）。
  - 年付折扣、升级/降级流程。
  - 邀请返利（邀请码追踪）。
- 体验层付费墙
  - 在关键功能触发点拦截（导出、去水印、进阶数据）。
  - 拦截页增加价值说明、收益样例、升级理由。
  - 支付回流后增加“状态同步中”进度反馈与自动刷新。

### C. 近两周执行排期（建议）
- 第 1 周
  - 完成 webhook 幂等 + 事件落库。
  - 扩展订阅状态字段（超越单一 `tier`）。
  - 设置页展示订阅状态/到期时间。
- 第 2 周
  - 落地 Feature Flag 权限网关。
  - 接入 Google 登录。
  - 补齐 OTP + 支付链路集成测试。
