# 任务目标：在 EnerQuote 中集成“三道墙”付费墙拦截逻辑 (基于 RevenueCat)

## 1. 背景上下文
我们已经重构了项目管理逻辑。现在需要根据用户的订阅状态 (Pro vs Free)，在三个核心环节实施功能拦截。
- 逻辑判断函数：`bool isProUser = checkSubscriptionStatus();`

## 2. 第一道墙：项目容量拦截 (The Capacity Wall)
**场景**：用户在首页点击“新建项目 (Create Project)”时。
**逻辑**：
- 如果 `isProUser == false` 且当前已存在项目数 `>= 2`。
- 拦截操作，弹出 RevenueCat Paywall。
- 提示文案： "You've reached the free limit of 2 projects. Upgrade to Pro to manage your entire sales pipeline."

## 3. 第二道墙：专业导出拦截 (The Export Wall)
**场景**：用户在项目详情页点击“导出 PDF (Export PDF)”或“生成报告 (Generate Report)”时。
**逻辑**：
- 如果 `isProUser == false`。
- 拦截操作，显示 Pro 预览水印或直接弹出 Paywall。
- 提示文案："Win more deals with branded proposals. Upgrade to Pro to export professional PDF quotes with your company logo."

## 4. 第三道墙：项目化成本设置拦截 (The Project-Specific Cost Wall)
**场景**：在项目测算页面修改“成本配置 (Cost Settings)”时。
**逻辑优化**：
- **数据流**：在数据库中，所有用户都有一个 `global_default_costs`。
- **Free 用户**：所有项目强制读取并同步更新 `global_default_costs`。当用户在 A 项目中修改成本，B 项目的成本也会跟着变。
- **Pro 用户**：可以为当前 `project_id` 开启 "Independent Costs" 模式，将参数持久化在 `project_calculations` 的 `parameters` JSONB 字段中，不影响全局。
- **拦截点**：当 Free 用户试图开启 "Independent Costs" 开关或在项目内点击“为此项目单独设置成本”时，弹出 Paywall。
- 提示文案："Efficiency for Pros. Upgrade to manage independent cost profiles for each project instead of one global setting."

## 5. UI/UX 要求
- 使用 RevenueCat 的 `PaywallFooterWidget` 或自定义半屏弹窗。
- 拦截时伴随轻微的震动反馈 (Haptic Feedback)。
- 确保拦截逻辑不崩溃，且在用户支付成功后能立即解锁（利用监听 Entitlements 变化）。

## 6. 执行任务
请帮我：
1. 修改 `ProjectService` 中的创建项目方法，加入数量检查。
2. 修改 `CalculationScreen` 的参数读取逻辑，根据 `isProUser` 决定是读取全局 JSON 还是项目 JSON。
3. 在导出按钮处添加权限检查装饰器。