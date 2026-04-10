import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'EnerQuote V1.0'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'企业级 SaaS 报价系统'**
  String get appSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In zh, this message translates to:
  /// **'企业邮箱'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码 (Password)'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPasswordLabel;

  /// No description provided for @secureLoginBtn.
  ///
  /// In zh, this message translates to:
  /// **'安全登录'**
  String get secureLoginBtn;

  /// No description provided for @registerPrompt.
  ///
  /// In zh, this message translates to:
  /// **'还没有账号？点击这里免费注册'**
  String get registerPrompt;

  /// No description provided for @registerTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建您的账号'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'加入EnerQuote，解锁企业级测算引擎'**
  String get registerSubtitle;

  /// No description provided for @freeRegisterBtn.
  ///
  /// In zh, this message translates to:
  /// **'免费注册'**
  String get freeRegisterBtn;

  /// No description provided for @errEmpty.
  ///
  /// In zh, this message translates to:
  /// **'邮箱和密码不能为空'**
  String get errEmpty;

  /// No description provided for @errPasswordLength.
  ///
  /// In zh, this message translates to:
  /// **'密码长度至少需要 6 位'**
  String get errPasswordLength;

  /// No description provided for @errPasswordMatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get errPasswordMatch;

  /// No description provided for @msgRegisterSuccess.
  ///
  /// In zh, this message translates to:
  /// **'🎉 账号注册成功！请使用新账号登录。'**
  String get msgRegisterSuccess;

  /// No description provided for @errAuthFailed401.
  ///
  /// In zh, this message translates to:
  /// **'账号或密码错误 (401)'**
  String get errAuthFailed401;

  /// 网络请求失败时的报错
  ///
  /// In zh, this message translates to:
  /// **'网络错误：{message}'**
  String errNetwork(String message);

  /// 捕获到未知系统异常时的报错
  ///
  /// In zh, this message translates to:
  /// **'系统异常: {error}'**
  String errSystem(String error);

  /// No description provided for @errRegisterFailedFallback.
  ///
  /// In zh, this message translates to:
  /// **'注册失败，请检查输入'**
  String get errRegisterFailedFallback;

  /// No description provided for @unauthorized.
  ///
  /// In zh, this message translates to:
  /// **'未授权，请重新登录'**
  String get unauthorized;

  /// No description provided for @simulateFailed.
  ///
  /// In zh, this message translates to:
  /// **'测算失败: {error}'**
  String simulateFailed(String error);

  /// No description provided for @parseError.
  ///
  /// In zh, this message translates to:
  /// **'数据格式解析异常，请查看控制台日志'**
  String get parseError;

  /// No description provided for @dashboardTitle.
  ///
  /// In zh, this message translates to:
  /// **'EnerQuote PV+ESS'**
  String get dashboardTitle;

  /// No description provided for @exportProposal.
  ///
  /// In zh, this message translates to:
  /// **'导出建议书 (Export Proposal)'**
  String get exportProposal;

  /// No description provided for @pdfExportFreeOptionTitle.
  ///
  /// In zh, this message translates to:
  /// **'[免费导出]'**
  String get pdfExportFreeOptionTitle;

  /// No description provided for @pdfExportFreeOptionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'带有巨大的 EnerQuote 水印，且不包含 ROI 财务分析'**
  String get pdfExportFreeOptionSubtitle;

  /// No description provided for @pdfExportProOptionTitle.
  ///
  /// In zh, this message translates to:
  /// **'[⭐ 升级 Pro 导出纯净专业版]'**
  String get pdfExportProOptionTitle;

  /// No description provided for @pdfExportProOptionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'一键解锁无水印与完整财报'**
  String get pdfExportProOptionSubtitle;

  /// No description provided for @kpiTotalCapex.
  ///
  /// In zh, this message translates to:
  /// **'系统总造价 (CAPEX)'**
  String get kpiTotalCapex;

  /// No description provided for @kpiIrr.
  ///
  /// In zh, this message translates to:
  /// **'内部收益率 (IRR)'**
  String get kpiIrr;

  /// No description provided for @kpiFirstYearGen.
  ///
  /// In zh, this message translates to:
  /// **'首年发电量'**
  String get kpiFirstYearGen;

  /// No description provided for @kpiPayback.
  ///
  /// In zh, this message translates to:
  /// **'投资回收期'**
  String get kpiPayback;

  /// No description provided for @clientEnvProfile.
  ///
  /// In zh, this message translates to:
  /// **'客户环境与用电模型'**
  String get clientEnvProfile;

  /// No description provided for @factoryPeakLoad.
  ///
  /// In zh, this message translates to:
  /// **'工厂白天峰值功率: {val} kW'**
  String factoryPeakLoad(String val);

  /// No description provided for @hardwareConfig.
  ///
  /// In zh, this message translates to:
  /// **'硬件资产配置'**
  String get hardwareConfig;

  /// No description provided for @pvCapacity.
  ///
  /// In zh, this message translates to:
  /// **'PV 光伏容量: {val} kWp'**
  String pvCapacity(String val);

  /// No description provided for @essCapacity.
  ///
  /// In zh, this message translates to:
  /// **'ESS 电池容量: {val} kWh'**
  String essCapacity(String val);

  /// No description provided for @cashFlowChartTitle.
  ///
  /// In zh, this message translates to:
  /// **'20年生命周期 净现金流预测'**
  String get cashFlowChartTitle;

  /// No description provided for @connectingPvgis.
  ///
  /// In zh, this message translates to:
  /// **'正在连接 PVGIS 气象卫星...'**
  String get connectingPvgis;

  /// No description provided for @citySaoPaulo.
  ///
  /// In zh, this message translates to:
  /// **'🇧🇷 São Paulo (巴西 - 拉美区)'**
  String get citySaoPaulo;

  /// No description provided for @cityMunich.
  ///
  /// In zh, this message translates to:
  /// **'🇩🇪 Munich (德国 - 欧洲区)'**
  String get cityMunich;

  /// No description provided for @cityHaikou.
  ///
  /// In zh, this message translates to:
  /// **'🇨🇳 Haikou (中国 - 海南)'**
  String get cityHaikou;

  /// No description provided for @cityLinfen.
  ///
  /// In zh, this message translates to:
  /// **'🇨🇳 Linfen (中国 - 山西)'**
  String get cityLinfen;

  /// No description provided for @yearFormat.
  ///
  /// In zh, this message translates to:
  /// **'Yr {year}'**
  String yearFormat(String year);

  /// No description provided for @upgradeToProTitle.
  ///
  /// In zh, this message translates to:
  /// **'升级到 PRO 专业版'**
  String get upgradeToProTitle;

  /// No description provided for @upgradeToProSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'解锁品牌白标、自定义成本与利润率、25 年 ROI 现金流图表，以及无水印的专业级 PDF 建议书。'**
  String get upgradeToProSubtitle;

  /// No description provided for @proFeatureLogo.
  ///
  /// In zh, this message translates to:
  /// **'自定义企业 Logo 与品牌专属色'**
  String get proFeatureLogo;

  /// No description provided for @proFeatureCost.
  ///
  /// In zh, this message translates to:
  /// **'自定义底层采购成本与隐形利润率'**
  String get proFeatureCost;

  /// No description provided for @proFeatureROI.
  ///
  /// In zh, this message translates to:
  /// **'解锁 25 年投资回报率 (ROI) 与现金流图表'**
  String get proFeatureROI;

  /// No description provided for @proFeatureNoWatermark.
  ///
  /// In zh, this message translates to:
  /// **'移除所有平台水印，生成纯净专业 PDF'**
  String get proFeatureNoWatermark;

  /// No description provided for @proFeaturePvgis.
  ///
  /// In zh, this message translates to:
  /// **'解锁 8760 小时 PVGIS 卫星气候数据'**
  String get proFeaturePvgis;

  /// No description provided for @redirectingToPayment.
  ///
  /// In zh, this message translates to:
  /// **'正在为您准备安全收银台，请在下一页完成支付。'**
  String get redirectingToPayment;

  /// No description provided for @unlockProBtn.
  ///
  /// In zh, this message translates to:
  /// **'立刻解锁 (\$19.9/月)'**
  String get unlockProBtn;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'工作台设置'**
  String get settingsTitle;

  /// No description provided for @advancedCostCalculatorTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级成本与利润率计算器'**
  String get advancedCostCalculatorTitle;

  /// No description provided for @tapToExpandCostSettings.
  ///
  /// In zh, this message translates to:
  /// **'点击展开成本与利润率设置'**
  String get tapToExpandCostSettings;

  /// No description provided for @proBrandingPaywallSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'升级 Pro，让每一份报价单都成为您的专属品牌资产'**
  String get proBrandingPaywallSubtitle;

  /// No description provided for @proProfitPaywallSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'升级 Pro，精准掌控每一单的隐性利润空间'**
  String get proProfitPaywallSubtitle;

  /// No description provided for @brandingSection.
  ///
  /// In zh, this message translates to:
  /// **'企业品牌与 Logo'**
  String get brandingSection;

  /// No description provided for @companyNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'公司名称'**
  String get companyNameLabel;

  /// No description provided for @logoUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'Logo 图片链接 (URL / Base64)'**
  String get logoUrlLabel;

  /// No description provided for @costSection.
  ///
  /// In zh, this message translates to:
  /// **'采购成本与利润率'**
  String get costSection;

  /// No description provided for @pvCostLabel.
  ///
  /// In zh, this message translates to:
  /// **'光伏单瓦底价 (\$/W)'**
  String get pvCostLabel;

  /// No description provided for @essCostLabel.
  ///
  /// In zh, this message translates to:
  /// **'储能单瓦时底价 (\$/Wh)'**
  String get essCostLabel;

  /// No description provided for @marginLabel.
  ///
  /// In zh, this message translates to:
  /// **'期望利润率 (%)'**
  String get marginLabel;

  /// No description provided for @saveSettingsBtn.
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get saveSettingsBtn;

  /// No description provided for @saveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'✅ 工作台设置已成功保存。'**
  String get saveSuccess;

  /// No description provided for @pdfProposalTitle.
  ///
  /// In zh, this message translates to:
  /// **'工商业光储投资收益建议书'**
  String get pdfProposalTitle;

  /// No description provided for @pdfSystemConfig.
  ///
  /// In zh, this message translates to:
  /// **'1. 系统硬件配置'**
  String get pdfSystemConfig;

  /// No description provided for @pdfPvArray.
  ///
  /// In zh, this message translates to:
  /// **'光伏阵列装机容量'**
  String get pdfPvArray;

  /// No description provided for @pdfEssBattery.
  ///
  /// In zh, this message translates to:
  /// **'储能系统额定容量'**
  String get pdfEssBattery;

  /// No description provided for @pdfGridPolicy.
  ///
  /// In zh, this message translates to:
  /// **'并网策略：防逆流 (零上网)'**
  String get pdfGridPolicy;

  /// No description provided for @pdfTotalCapex.
  ///
  /// In zh, this message translates to:
  /// **'项目总投资 (CAPEX)'**
  String get pdfTotalCapex;

  /// No description provided for @pdfFinancialHighlights.
  ///
  /// In zh, this message translates to:
  /// **'2. 核心财务指标'**
  String get pdfFinancialHighlights;

  /// No description provided for @pdfNpv.
  ///
  /// In zh, this message translates to:
  /// **'项目净现值 (NPV)'**
  String get pdfNpv;

  /// No description provided for @pdfIrr.
  ///
  /// In zh, this message translates to:
  /// **'内部收益率 (IRR)'**
  String get pdfIrr;

  /// No description provided for @pdfPayback.
  ///
  /// In zh, this message translates to:
  /// **'投资回收期'**
  String get pdfPayback;

  /// No description provided for @pdfYears.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get pdfYears;

  /// No description provided for @pdfEmsStrategyTitle.
  ///
  /// In zh, this message translates to:
  /// **'2.5 EMS 策略与首年收益拆解'**
  String get pdfEmsStrategyTitle;

  /// No description provided for @pdfEmsStrategyDesc.
  ///
  /// In zh, this message translates to:
  /// **'能量管理系统 (EMS) 默认开启削峰填谷与夜间谷电套利策略，最大化降低工厂峰值电费。'**
  String get pdfEmsStrategyDesc;

  /// No description provided for @pdfRevDirectSolar.
  ///
  /// In zh, this message translates to:
  /// **'1. 光伏自发自用收益'**
  String get pdfRevDirectSolar;

  /// No description provided for @pdfRevDirectSolarDesc.
  ///
  /// In zh, this message translates to:
  /// **'直供工厂白天基础负载'**
  String get pdfRevDirectSolarDesc;

  /// No description provided for @pdfRevTou.
  ///
  /// In zh, this message translates to:
  /// **'2. 峰谷套利收益'**
  String get pdfRevTou;

  /// No description provided for @pdfRevTouDesc.
  ///
  /// In zh, this message translates to:
  /// **'利用夜间谷电充电，白天峰电放电'**
  String get pdfRevTouDesc;

  /// No description provided for @pdfRevPeakShaving.
  ///
  /// In zh, this message translates to:
  /// **'3. 削峰填谷收益'**
  String get pdfRevPeakShaving;

  /// No description provided for @pdfRevPeakShavingDesc.
  ///
  /// In zh, this message translates to:
  /// **'削减工厂最大需量电费 (\$/kW)'**
  String get pdfRevPeakShavingDesc;

  /// No description provided for @pdfRevBackup.
  ///
  /// In zh, this message translates to:
  /// **'4. 备用电源 (UPS) 价值'**
  String get pdfRevBackup;

  /// No description provided for @pdfRevBackupDesc.
  ///
  /// In zh, this message translates to:
  /// **'挽回停电导致的工厂产能损失'**
  String get pdfRevBackupDesc;

  /// No description provided for @pdfCashFlowTitle.
  ///
  /// In zh, this message translates to:
  /// **'3. 20年项目生命周期现金流明细'**
  String get pdfCashFlowTitle;

  /// No description provided for @pdfCfYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get pdfCfYear;

  /// No description provided for @pdfCfEnergySavings.
  ///
  /// In zh, this message translates to:
  /// **'节省电费'**
  String get pdfCfEnergySavings;

  /// No description provided for @pdfCfBackupValue.
  ///
  /// In zh, this message translates to:
  /// **'挽回停电损失'**
  String get pdfCfBackupValue;

  /// No description provided for @pdfCfOmBattery.
  ///
  /// In zh, this message translates to:
  /// **'运维与电池重置'**
  String get pdfCfOmBattery;

  /// No description provided for @pdfCfDebtService.
  ///
  /// In zh, this message translates to:
  /// **'偿还贷款'**
  String get pdfCfDebtService;

  /// No description provided for @pdfCfNetCashFlow.
  ///
  /// In zh, this message translates to:
  /// **'当年净现金流'**
  String get pdfCfNetCashFlow;

  /// No description provided for @pdfCfCumulative.
  ///
  /// In zh, this message translates to:
  /// **'累计净现金流'**
  String get pdfCfCumulative;

  /// No description provided for @pdfDate.
  ///
  /// In zh, this message translates to:
  /// **'日期: {date}'**
  String pdfDate(String date);

  /// No description provided for @pdfPageOf.
  ///
  /// In zh, this message translates to:
  /// **'第 {current} 页，共 {total} 页'**
  String pdfPageOf(String current, String total);

  /// No description provided for @pdfConfidential.
  ///
  /// In zh, this message translates to:
  /// **'商业机密，严禁外传'**
  String get pdfConfidential;

  /// No description provided for @logoutTooltip.
  ///
  /// In zh, this message translates to:
  /// **'登出 (Logout)'**
  String get logoutTooltip;

  /// No description provided for @logoutTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logoutTitle;

  /// No description provided for @logoutMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出当前账号吗？'**
  String get logoutMessage;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirmLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get confirmLogout;

  /// No description provided for @tierFree.
  ///
  /// In zh, this message translates to:
  /// **'当前版本：基础免费版'**
  String get tierFree;

  /// No description provided for @tierPro.
  ///
  /// In zh, this message translates to:
  /// **'👑 尊贵的 PRO 订阅会员'**
  String get tierPro;

  /// No description provided for @accountEmailLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号邮箱：'**
  String get accountEmailLabel;

  /// No description provided for @proExpireDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'到期时间：'**
  String get proExpireDateLabel;

  /// No description provided for @upgradeNow.
  ///
  /// In zh, this message translates to:
  /// **'立即升级'**
  String get upgradeNow;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get forgotPasswordTitle;

  /// No description provided for @enterEmailPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请输入您注册时的邮箱地址'**
  String get enterEmailPrompt;

  /// No description provided for @sendCodeBtn.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCodeBtn;

  /// No description provided for @codeSentMsg.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送至 {email}'**
  String codeSentMsg(Object email);

  /// No description provided for @codeInputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入 6 位验证码'**
  String get codeInputHint;

  /// No description provided for @newPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'设置新密码'**
  String get newPasswordLabel;

  /// No description provided for @confirmResetBtn.
  ///
  /// In zh, this message translates to:
  /// **'确认重置'**
  String get confirmResetBtn;

  /// No description provided for @resendPrompt.
  ///
  /// In zh, this message translates to:
  /// **'没收到？重新填写邮箱'**
  String get resendPrompt;

  /// No description provided for @sessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录状态已过期，请重新登录！'**
  String get sessionExpired;

  /// No description provided for @paymentConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'等待支付确认'**
  String get paymentConfirmTitle;

  /// No description provided for @paymentConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'如果您已在浏览器中完成付款，请点击下方按钮核实状态并激活特权。'**
  String get paymentConfirmDesc;

  /// No description provided for @verifyLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后核实'**
  String get verifyLater;

  /// No description provided for @paymentCompleted.
  ///
  /// In zh, this message translates to:
  /// **'我已完成支付'**
  String get paymentCompleted;

  /// No description provided for @paymentSuccessPro.
  ///
  /// In zh, this message translates to:
  /// **'🎉 支付成功！已为您激活 PRO 专属特权！'**
  String get paymentSuccessPro;

  /// No description provided for @paymentPending.
  ///
  /// In zh, this message translates to:
  /// **'⏳ 尚未收到款项，请确保支付成功或稍等几秒再试。'**
  String get paymentPending;

  /// No description provided for @paymentError.
  ///
  /// In zh, this message translates to:
  /// **'呼叫收银台失败：{error}'**
  String paymentError(String error);

  /// No description provided for @errInvalidEmail.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的邮箱地址'**
  String get errInvalidEmail;

  /// No description provided for @msgCodeSent.
  ///
  /// In zh, this message translates to:
  /// **'✅ 验证码已发送至您的邮箱，请注意查收。'**
  String get msgCodeSent;

  /// No description provided for @errCodeLength.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位验证码'**
  String get errCodeLength;

  /// No description provided for @errNewPwdLength.
  ///
  /// In zh, this message translates to:
  /// **'新密码至少 6 位'**
  String get errNewPwdLength;

  /// No description provided for @msgResetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'🎉 密码重置成功！请使用新密码登录。'**
  String get msgResetSuccess;

  /// No description provided for @errCodeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'❌ 验证码错误或已过期'**
  String get errCodeInvalid;

  /// No description provided for @msgPayToUpgrade.
  ///
  /// In zh, this message translates to:
  /// **'✅ 支付完成后，请重新登录账号，即可激活 PRO 专属特权！'**
  String get msgPayToUpgrade;

  /// No description provided for @logoInputHint.
  ///
  /// In zh, this message translates to:
  /// **'填链接或点击右侧从相册选择 ->'**
  String get logoInputHint;

  /// No description provided for @msgLogoConverted.
  ///
  /// In zh, this message translates to:
  /// **'✅ Logo 已成功转为 Base64！请点击保存'**
  String get msgLogoConverted;

  /// No description provided for @errSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请检查网络！'**
  String get errSaveFailed;

  /// No description provided for @pdfPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'建议书预览'**
  String get pdfPreviewTitle;

  /// No description provided for @appWindowTitle.
  ///
  /// In zh, this message translates to:
  /// **'报价大师'**
  String get appWindowTitle;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get termsOfServiceTitle;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicyTitle;

  /// No description provided for @refundPolicyTitle.
  ///
  /// In zh, this message translates to:
  /// **'退款政策'**
  String get refundPolicyTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTooltip;

  /// No description provided for @emailPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'example@gmail.com'**
  String get emailPlaceholder;

  /// No description provided for @contactUs.
  ///
  /// In zh, this message translates to:
  /// **'联系我们'**
  String get contactUs;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @legalLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'当前无法加载文档，请稍后重试。'**
  String get legalLoadFailed;

  /// No description provided for @footerCopyright.
  ///
  /// In zh, this message translates to:
  /// **'© 2026 EnerQuote. 保留所有权利。'**
  String get footerCopyright;

  /// No description provided for @openInBrowserMessage.
  ///
  /// In zh, this message translates to:
  /// **'请在浏览器中打开 {title}。'**
  String openInBrowserMessage(String title);

  /// No description provided for @openInBrowser.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中打开'**
  String get openInBrowser;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
