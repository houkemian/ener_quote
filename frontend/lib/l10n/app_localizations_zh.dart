// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'EnerQuote V1.0';

  @override
  String get appSubtitle => '企业级 SaaS 报价系统';

  @override
  String get emailLabel => '企业邮箱';

  @override
  String get passwordLabel => '密码 (Password)';

  @override
  String get confirmPasswordLabel => '确认密码';

  @override
  String get secureLoginBtn => '安全登录';

  @override
  String get dividerOr => '或';

  @override
  String get loginWithGoogle => '使用 Google 登录';

  @override
  String get loginWithMicrosoft => '使用 Microsoft 登录';

  @override
  String get errOAuthNotConfigured =>
      '未配置第三方登录。请使用编译参数 GOOGLE_SERVER_CLIENT_ID 与 MICROSOFT_OAUTH_CLIENT_ID。';

  @override
  String get errGoogleSignIn12500 =>
      'Google 登录失败 (12500)：在 Google Cloud「凭据」中，Android 类型 OAuth 客户端的包名须为 one.dothings.enerquote，且 SHA-1 必须与当前安装包的实际签名证书一致（flutter run / 本地调试用 debug.keystore；从 Google Play 安装须在 Play 控制台「应用完整性」查看「应用签名」证书指纹并添加到 Cloud）。Web 客户端 ID 须与 GOOGLE_SERVER_CLIENT_ID 一致且与 Android 客户端在同一 GCP 项目。';

  @override
  String get registerPrompt => '还没有账号？点击这里免费注册';

  @override
  String get registerTitle => '创建您的账号';

  @override
  String get registerSubtitle => '加入EnerQuote，解锁企业级测算引擎';

  @override
  String get freeRegisterBtn => '免费注册';

  @override
  String get errEmpty => '邮箱和密码不能为空';

  @override
  String get errPasswordLength => '密码长度至少需要 6 位';

  @override
  String get errPasswordMatch => '两次输入的密码不一致';

  @override
  String get msgRegisterSuccess => '🎉 账号注册成功！请使用新账号登录。';

  @override
  String get errAuthFailed401 => '账号或密码错误 (401)';

  @override
  String errNetwork(String message) {
    return '网络错误：$message';
  }

  @override
  String errSystem(String error) {
    return '系统异常: $error';
  }

  @override
  String get errRegisterFailedFallback => '注册失败，请检查输入';

  @override
  String get unauthorized => '未授权，请重新登录';

  @override
  String simulateFailed(String error) {
    return '测算失败: $error';
  }

  @override
  String get parseError => '数据格式解析异常，请查看控制台日志';

  @override
  String get dashboardTitle => 'EnerQuote PV+ESS';

  @override
  String get exportProposal => '导出建议书 (Export Proposal)';

  @override
  String get pdfExportFreeOptionTitle => '[免费导出]';

  @override
  String get pdfExportFreeOptionSubtitle => '带有巨大的 EnerQuote 水印，且不包含 ROI 财务分析';

  @override
  String get pdfExportProOptionTitle => '[⭐ 升级 Pro 导出纯净专业版]';

  @override
  String get pdfExportProOptionSubtitle => '一键解锁无水印与完整财报';

  @override
  String get kpiTotalCapex => '系统总造价 (CAPEX)';

  @override
  String get kpiIrr => '内部收益率 (IRR)';

  @override
  String get kpiFirstYearGen => '首年发电量';

  @override
  String get kpiPayback => '投资回收期';

  @override
  String get clientEnvProfile => '客户环境与用电模型';

  @override
  String factoryPeakLoad(String val) {
    return '工厂白天峰值功率: $val kW';
  }

  @override
  String get hardwareConfig => '硬件资产配置';

  @override
  String pvCapacity(String val) {
    return 'PV 光伏容量: $val kWp';
  }

  @override
  String essCapacity(String val) {
    return 'ESS 电池容量: $val kWh';
  }

  @override
  String get cashFlowChartTitle => '20年生命周期 净现金流预测';

  @override
  String get connectingPvgis => '正在连接 PVGIS 气象卫星...';

  @override
  String get citySaoPaulo => '🇧🇷 São Paulo (巴西 - 拉美区)';

  @override
  String get cityMunich => '🇩🇪 Munich (德国 - 欧洲区)';

  @override
  String get cityHaikou => '🇨🇳 Haikou (中国 - 海南)';

  @override
  String get cityLinfen => '🇨🇳 Linfen (中国 - 山西)';

  @override
  String yearFormat(String year) {
    return 'Yr $year';
  }

  @override
  String get upgradeToProTitle => '升级到 PRO 专业版';

  @override
  String get upgradeToProSubtitle =>
      '解锁品牌白标、自定义成本与利润率、25 年 ROI 现金流图表，以及无水印的专业级 PDF 建议书。';

  @override
  String get proFeatureLogo => '自定义企业 Logo 与品牌专属色';

  @override
  String get proFeatureCost => '自定义底层采购成本与隐形利润率';

  @override
  String get proFeatureROI => '解锁 25 年投资回报率 (ROI) 与现金流图表';

  @override
  String get proFeatureNoWatermark => '移除所有平台水印，生成纯净专业 PDF';

  @override
  String get proFeaturePvgis => '解锁 8760 小时 PVGIS 卫星气候数据';

  @override
  String get redirectingToPayment => '正在为您准备安全收银台，请在下一页完成支付。';

  @override
  String get unlockProBtn => '立刻解锁 (\$19.9/月)';

  @override
  String get settingsTitle => '工作台设置';

  @override
  String get advancedCostCalculatorTitle => '高级成本与利润率计算器';

  @override
  String get tapToExpandCostSettings => '点击展开成本与利润率设置';

  @override
  String get proBrandingPaywallSubtitle => '升级 Pro，让每一份报价单都成为您的专属品牌资产';

  @override
  String get proProfitPaywallSubtitle => '升级 Pro，精准掌控每一单的隐性利润空间';

  @override
  String get brandingSection => '企业品牌与 Logo';

  @override
  String get companyNameLabel => '公司名称';

  @override
  String get logoUrlLabel => 'Logo 图片链接 (URL / Base64)';

  @override
  String get costSection => '采购成本与利润率';

  @override
  String get pvCostLabel => '光伏单瓦底价 (\$/W)';

  @override
  String get essCostLabel => '储能单瓦时底价 (\$/Wh)';

  @override
  String get marginLabel => '期望利润率 (%)';

  @override
  String get saveSettingsBtn => '保存配置';

  @override
  String get saveSuccess => '✅ 工作台设置已成功保存。';

  @override
  String get pdfProposalTitle => '工商业光储投资收益建议书';

  @override
  String get pdfSystemConfig => '1. 系统硬件配置';

  @override
  String get pdfPvArray => '光伏阵列装机容量';

  @override
  String get pdfEssBattery => '储能系统额定容量';

  @override
  String get pdfGridPolicy => '并网策略：防逆流 (零上网)';

  @override
  String get pdfTotalCapex => '项目总投资 (CAPEX)';

  @override
  String get pdfFinancialHighlights => '2. 核心财务指标';

  @override
  String get pdfNpv => '项目净现值 (NPV)';

  @override
  String get pdfIrr => '内部收益率 (IRR)';

  @override
  String get pdfPayback => '投资回收期';

  @override
  String get pdfYears => '年';

  @override
  String get pdfEmsStrategyTitle => '2.5 EMS 策略与首年收益拆解';

  @override
  String get pdfEmsStrategyDesc =>
      '能量管理系统 (EMS) 默认开启削峰填谷与夜间谷电套利策略，最大化降低工厂峰值电费。';

  @override
  String get pdfRevDirectSolar => '1. 光伏自发自用收益';

  @override
  String get pdfRevDirectSolarDesc => '直供工厂白天基础负载';

  @override
  String get pdfRevTou => '2. 峰谷套利收益';

  @override
  String get pdfRevTouDesc => '利用夜间谷电充电，白天峰电放电';

  @override
  String get pdfRevPeakShaving => '3. 削峰填谷收益';

  @override
  String get pdfRevPeakShavingDesc => '削减工厂最大需量电费 (\$/kW)';

  @override
  String get pdfRevBackup => '4. 备用电源 (UPS) 价值';

  @override
  String get pdfRevBackupDesc => '挽回停电导致的工厂产能损失';

  @override
  String get pdfCashFlowTitle => '3. 20年项目生命周期现金流明细';

  @override
  String get pdfCfYear => '年份';

  @override
  String get pdfCfEnergySavings => '节省电费';

  @override
  String get pdfCfBackupValue => '挽回停电损失';

  @override
  String get pdfCfOmBattery => '运维与电池重置';

  @override
  String get pdfCfDebtService => '偿还贷款';

  @override
  String get pdfCfNetCashFlow => '当年净现金流';

  @override
  String get pdfCfCumulative => '累计净现金流';

  @override
  String pdfDate(String date) {
    return '日期: $date';
  }

  @override
  String pdfPageOf(String current, String total) {
    return '第 $current 页，共 $total 页';
  }

  @override
  String get pdfConfidential => '商业机密，严禁外传';

  @override
  String get logoutTooltip => '登出 (Logout)';

  @override
  String get logoutTitle => '退出登录';

  @override
  String get logoutMessage => '确定要退出当前账号吗？';

  @override
  String get cancel => '取消';

  @override
  String get confirmLogout => '退出';

  @override
  String get tierFree => '当前版本：基础免费版';

  @override
  String get tierPro => '👑 尊贵的 PRO 订阅会员';

  @override
  String get accountEmailLabel => '账号邮箱：';

  @override
  String get proExpireDateLabel => '到期时间：';

  @override
  String get upgradeNow => '立即升级';

  @override
  String get forgotPasswordTitle => '重置密码';

  @override
  String get enterEmailPrompt => '请输入您注册时的邮箱地址';

  @override
  String get sendCodeBtn => '发送验证码';

  @override
  String codeSentMsg(Object email) {
    return '验证码已发送至 $email';
  }

  @override
  String get codeInputHint => '输入 6 位验证码';

  @override
  String get newPasswordLabel => '设置新密码';

  @override
  String get confirmResetBtn => '确认重置';

  @override
  String get resendPrompt => '没收到？重新填写邮箱';

  @override
  String get sessionExpired => '登录状态已过期，请重新登录！';

  @override
  String get paymentConfirmTitle => '等待支付确认';

  @override
  String get paymentConfirmDesc => '如果您已在浏览器中完成付款，请点击下方按钮核实状态并激活特权。';

  @override
  String get verifyLater => '稍后核实';

  @override
  String get paymentCompleted => '我已完成支付';

  @override
  String get paymentSuccessPro => '🎉 支付成功！已为您激活 PRO 专属特权！';

  @override
  String get paymentPending => '⏳ 尚未收到款项，请确保支付成功或稍等几秒再试。';

  @override
  String paymentError(String error) {
    return '呼叫收银台失败：$error';
  }

  @override
  String get errInvalidEmail => '请输入有效的邮箱地址';

  @override
  String get msgCodeSent => '✅ 验证码已发送至您的邮箱，请注意查收。';

  @override
  String get errCodeLength => '请输入 6 位验证码';

  @override
  String get errNewPwdLength => '新密码至少 6 位';

  @override
  String get msgResetSuccess => '🎉 密码重置成功！请使用新密码登录。';

  @override
  String get errCodeInvalid => '❌ 验证码错误或已过期';

  @override
  String get msgPayToUpgrade => '✅ 支付完成后，请重新登录账号，即可激活 PRO 专属特权！';

  @override
  String get logoInputHint => '填链接或点击右侧从相册选择 ->';

  @override
  String get msgLogoConverted => '✅ Logo 已成功转为 Base64！请点击保存';

  @override
  String get errSaveFailed => '保存失败，请检查网络！';

  @override
  String get pdfPreviewTitle => '建议书预览';

  @override
  String get appWindowTitle => '报价大师';

  @override
  String get termsOfServiceTitle => '服务条款';

  @override
  String get privacyPolicyTitle => '隐私政策';

  @override
  String get refundPolicyTitle => '退款政策';

  @override
  String get settingsTooltip => '设置';

  @override
  String get emailPlaceholder => 'example@gmail.com';

  @override
  String get contactUs => '联系我们';

  @override
  String get close => '关闭';

  @override
  String get legalLoadFailed => '当前无法加载文档，请稍后重试。';

  @override
  String get footerCopyright => '© 2026 EnerQuote. 保留所有权利。';

  @override
  String openInBrowserMessage(String title) {
    return '请在浏览器中打开 $title。';
  }

  @override
  String get openInBrowser => '在浏览器中打开';
}
