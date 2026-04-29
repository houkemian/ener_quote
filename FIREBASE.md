Firebase 登录配置总览（Google + Microsoft）

本文档汇总当前仓库中 Firebase 相关登录配置，避免“控制台、前端、Android、后端”不一致。

## 1) 当前代码中使用到的配置项

### 前端 Dart 编译参数（`String.fromEnvironment`）
- `GOOGLE_SERVER_CLIENT_ID`
  - 代码位置：`frontend/lib/screens/login_screen.dart`
  - 用途：Google 登录时作为 `GoogleSignIn(serverClientId)`（Android 可走 Gradle 注入兜底）
- `MICROSOFT_FIREBASE_PROVIDER_ID`
  - 代码位置：`frontend/lib/screens/login_screen.dart`
  - 默认值：`microsoft.com`
  - 用途：`OAuthProvider(providerId)` 发起 Firebase Microsoft 登录

### Android 本地配置（`frontend/android/gradle.properties`）
- `GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com`
- `MICROSOFT_OAUTH_CLIENT_ID=...`
- `MICROSOFT_TENANT=consumers`

说明：当前 Firebase 方案里，Microsoft 登录主链路是 `firebase_auth` + `OAuthProvider`；`MICROSOFT_OAUTH_CLIENT_ID` / `MICROSOFT_TENANT` 主要用于 Android 原生侧兼容与扩展配置，不是 Firebase Provider 的唯一来源。

### Android 构建注入（`frontend/android/app/build.gradle.kts`）
- 读取 `gradle.properties` 中变量并注入资源：
  - `microsoft_oauth_client_id`
  - `microsoft_oauth_tenant`
- `google-services` 插件已启用：`id("com.google.gms.google-services")`

### Firebase 配置文件（`frontend/android/app/google-services.json`）
- 包名：`one.dothings.enerquote`
- 含 Android OAuth client（`client_type: 1`）与 Web OAuth client（`client_type: 3`）
- 该文件由 Firebase 控制台下载，原则上不手改

## 2) Firebase Console 必配项

### 基础
- 项目：`enerquote-493202`（以控制台实际为准）
- Authentication 已启用
- Android App 已添加，包名与代码一致：`one.dothings.enerquote`
- 已下载 `google-services.json` 并放置到 `frontend/android/app/google-services.json`

### Google 登录
- 路径：Authentication -> Sign-in method -> Google -> Enable
- 与代码一致要求：
  - Web Client ID 要与 `GOOGLE_SERVER_CLIENT_ID` 对齐
  - Android OAuth 客户端包名与 SHA-1 要与安装包签名一致

### Microsoft 登录（Firebase OIDC）
- Firebase 无“内建 Microsoft 按钮”时，使用 OpenID Connect Provider
- 路径：Authentication -> Sign-in method -> OpenID Connect
- 建议配置：
  - Provider ID：`microsoft.com`（必须与 `MICROSOFT_FIREBASE_PROVIDER_ID` 一致）
  - Issuer：`https://login.microsoftonline.com/<tenant>/v2.0`
  - Client ID / Client Secret：来自 Microsoft Entra App Registration
- Entra 应用 `Supported account types` 需与你目标账号类型一致（个人/组织）

## 3) 后端 Firebase 验证配置

### 环境变量
- `FIREBASE_PROJECT_ID=<firebase project id>`
- 代码位置：
  - `backend/app/services/firebase_auth.py`
  - `backend/app/api/v1/auth.py`（`POST /api/v1/auth/firebase`）

### 后端校验逻辑（现状）
- 校验 Firebase ID Token 的 `aud` 必须等于 `FIREBASE_PROJECT_ID`
- 必须存在 `uid/email`
- `email_verified` 必须为 `true`
- 登录成功后执行用户 upsert/合并并返回业务侧数据

## 4) 前端登录链路（现状）

### Google
1. `GoogleSignIn` 获取 Google ID token
2. `FirebaseAuth.signInWithCredential`
3. 取 Firebase ID token
4. 调用后端 `POST /api/v1/auth/firebase`

### Microsoft
1. `OAuthProvider(providerId)`（默认 `microsoft.com`）
2. `FirebaseAuth.signInWithProvider`（Web 用 popup）
3. 取 Firebase ID token
4. 调用后端 `POST /api/v1/auth/firebase`

## 5) 常见不一致排查清单

- `google-services.json` 的项目/包名与当前应用不一致
- Firebase Console 中 Provider ID 与代码里的 `MICROSOFT_FIREBASE_PROVIDER_ID` 不一致
- Google Web client ID 与 `GOOGLE_SERVER_CLIENT_ID` 不一致
- Android SHA-1 未在 Google Cloud/Firebase 中配置
- 后端 `FIREBASE_PROJECT_ID` 与前端 Firebase 项目不一致导致 `audience mismatch`
- Microsoft Entra 账户类型不匹配导致个人账号无法登录

## 6) 建议的统一来源

- Firebase 控制台：`google-services.json`、Google/Microsoft Provider 开关
- `frontend/android/gradle.properties`：Android 本地登录相关常量
- Dart `--dart-define`：跨平台覆盖（CI 或临时环境）
- 后端 `.env`：`FIREBASE_PROJECT_ID`（必须与 Firebase 项目一致）

