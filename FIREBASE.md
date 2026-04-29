Firebase 控制台最小配置清单（Google + Microsoft 一次联调）
1) Firebase 项目基础
创建/选择项目
添加 Android App（包名与当前一致）
下载并放置 google-services.json（你仓库里已有）
启用 Authentication 模块
2) 启用登录提供商
Google：Authentication -> Sign-in method -> 启用 Google
Microsoft：Firebase 没有“原生 Microsoft provider”，用 OIDC 提供商
在 Microsoft Entra 注册应用（Web 平台）
回调 URI 使用 Firebase 给的 OIDC redirect URI
在 Firebase Authentication -> Sign-in method -> OpenID Connect 新增 provider
Provider ID 建议：microsoft.com（与你前端 OAuthProvider('microsoft.com') 对齐）
填 issuer：https://login.microsoftonline.com/<tenant-id>/v2.0
填 client id / client secret
3) 后端环境变量
FIREBASE_PROJECT_ID=<你的firebase项目ID>
DATABASE_URL=<你的Neon连接串>
4) 前端依赖与初始化（已完成）
firebase_core、firebase_auth 已接入
main.dart 已 Firebase.initializeApp()
登录页已走 Firebase（Google + Microsoft）并调用 POST /api/v1/auth/firebase
5) 联调验收（最小）
Google 登录成功后，/settings/me 返回 200 且有 tier
Microsoft 登录成功后，同一邮箱能自动合并到同一业务账号
未验证邮箱用户被后端拒绝（403）
付费后通过 /settings/me 看到 tier 变化（不再依赖 /auth/refresh）
如果你要，我下一步可以直接给你一份 Entra + Firebase OIDC 的逐字段填写模板（把每个输入框该填什么写死）。



Azure: Firebase Auth Value:<REDACTED_CLIENT_SECRET>
                     SecretId:<REDACTED_SECRET_ID>