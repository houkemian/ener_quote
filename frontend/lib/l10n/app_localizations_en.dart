// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EnerQuote V1.0';

  @override
  String get appSubtitle => 'Enterprise SaaS Quoting System';

  @override
  String get emailLabel => 'Work Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get secureLoginBtn => 'Secure Login';

  @override
  String get registerPrompt => 'Don\'t have an account? Sign up free';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle => 'Join EnerQuote, unlock enterprise engine';

  @override
  String get freeRegisterBtn => 'Sign Up Free';

  @override
  String get errEmpty => 'Email and password cannot be empty';

  @override
  String get errPasswordLength => 'Password must be at least 6 characters';

  @override
  String get errPasswordMatch => 'Passwords do not match';

  @override
  String get msgRegisterSuccess =>
      '🎉 Account created successfully! Please log in.';

  @override
  String get errAuthFailed401 => 'Incorrect account or password (401)';

  @override
  String errNetwork(String message) {
    return 'Network Error: $message';
  }

  @override
  String errSystem(String error) {
    return 'System Error: $error';
  }

  @override
  String get errRegisterFailedFallback =>
      'Registration failed, please check your input';

  @override
  String get unauthorized => 'Unauthorized, please log in again';

  @override
  String simulateFailed(String error) {
    return 'Simulation failed: $error';
  }

  @override
  String get parseError => 'Data parsing exception, please check logs';

  @override
  String get dashboardTitle => 'EnerQuote PV+ESS';

  @override
  String get exportProposal => 'Export Proposal';

  @override
  String get pdfExportFreeOptionTitle => '[Free Export]';

  @override
  String get pdfExportFreeOptionSubtitle =>
      'Includes a large EnerQuote watermark and excludes ROI financial analysis';

  @override
  String get pdfExportProOptionTitle =>
      '[⭐ Upgrade to Pro for clean professional export]';

  @override
  String get pdfExportProOptionSubtitle =>
      'Unlock watermark-free export and full financial report in one tap';

  @override
  String get kpiTotalCapex => 'Total CAPEX';

  @override
  String get kpiIrr => 'Internal Rate of Return (IRR)';

  @override
  String get kpiFirstYearGen => '1st Year Generation';

  @override
  String get kpiPayback => 'Payback Period';

  @override
  String get clientEnvProfile => 'Client Environment & Load Profile';

  @override
  String factoryPeakLoad(String val) {
    return 'Factory Peak Load: $val kW';
  }

  @override
  String get hardwareConfig => 'Hardware Configuration';

  @override
  String pvCapacity(String val) {
    return 'PV Capacity: $val kWp';
  }

  @override
  String essCapacity(String val) {
    return 'ESS Capacity: $val kWh';
  }

  @override
  String get cashFlowChartTitle => '20-Year Net Cash Flow Forecast';

  @override
  String get connectingPvgis => 'Connecting to PVGIS...';

  @override
  String get citySaoPaulo => '🇧🇷 São Paulo (Brazil - LATAM)';

  @override
  String get cityMunich => '🇩🇪 Munich (Germany - EU)';

  @override
  String get cityHaikou => '🇨🇳 Haikou (China - Hainan)';

  @override
  String get cityLinfen => '🇨🇳 Linfen (China - Shanxi)';

  @override
  String yearFormat(String year) {
    return 'Yr $year';
  }

  @override
  String get upgradeToProTitle => 'Upgrade to PRO';

  @override
  String get upgradeToProSubtitle =>
      'Unlock custom branding, editable cost & margin settings, full 25-year ROI cash flow charts, and watermark-free professional PDFs.';

  @override
  String get proFeatureLogo => 'Custom company logo and branding';

  @override
  String get proFeatureCost => 'Custom base procurement costs and margins';

  @override
  String get proFeatureROI => 'Unlock 25-year ROI & cash flow charts';

  @override
  String get proFeatureNoWatermark =>
      'Remove all watermarks for pure professional PDFs';

  @override
  String get proFeaturePvgis => 'Unlock 8760-hour PVGIS satellite weather data';

  @override
  String get redirectingToPayment =>
      'Preparing secure checkout... Please complete payment in the next screen.';

  @override
  String get unlockProBtn => 'Unlock Now (\$19.9/mo)';

  @override
  String get settingsTitle => 'Workspace Settings';

  @override
  String get advancedCostCalculatorTitle => 'Advanced Cost & Margin Calculator';

  @override
  String get tapToExpandCostSettings =>
      'Tap to expand cost and margin settings';

  @override
  String get proBrandingPaywallSubtitle =>
      'Upgrade to Pro and turn every proposal into your own branded asset.';

  @override
  String get proProfitPaywallSubtitle =>
      'Upgrade to Pro and precisely control hidden profit margins on every deal.';

  @override
  String get brandingSection => 'Branding & Logo';

  @override
  String get companyNameLabel => 'Company Name';

  @override
  String get logoUrlLabel => 'Logo Image URL / Base64';

  @override
  String get costSection => 'Procurement Costs & Margins';

  @override
  String get pvCostLabel => 'PV Base Cost (\$/W)';

  @override
  String get essCostLabel => 'ESS Base Cost (\$/Wh)';

  @override
  String get marginLabel => 'Target Margin (%)';

  @override
  String get saveSettingsBtn => 'Save Configuration';

  @override
  String get saveSuccess => '✅ Workspace settings saved successfully.';

  @override
  String get pdfProposalTitle =>
      'Commercial Energy Storage Investment Proposal';

  @override
  String get pdfSystemConfig => '1. System Configuration';

  @override
  String get pdfPvArray => 'PV Array Capacity';

  @override
  String get pdfEssBattery => 'ESS Battery Capacity';

  @override
  String get pdfGridPolicy => 'Grid Policy: Zero Export (Anti-backflow)';

  @override
  String get pdfTotalCapex => 'Total System CAPEX';

  @override
  String get pdfFinancialHighlights => '2. Financial Highlights';

  @override
  String get pdfNpv => 'Net Present Value (NPV)';

  @override
  String get pdfIrr => 'Internal Rate of Return';

  @override
  String get pdfPayback => 'Payback Period';

  @override
  String get pdfYears => 'Years';

  @override
  String get pdfEmsStrategyTitle =>
      '2.5 EMS Strategy & Year 1 Revenue Stacking';

  @override
  String get pdfEmsStrategyDesc =>
      'Energy Management System (EMS) is configured for aggressive Peak Shaving and Time-of-Use (TOU) arbitrage, maximizing grid savings.';

  @override
  String get pdfRevDirectSolar => '1. Direct Solar Consumption (PV)';

  @override
  String get pdfRevDirectSolarDesc => 'Offset daytime base load';

  @override
  String get pdfRevTou => '2. TOU Arbitrage';

  @override
  String get pdfRevTouDesc => 'Grid charge at night, discharge at peak';

  @override
  String get pdfRevPeakShaving => '3. Peak Shaving';

  @override
  String get pdfRevPeakShavingDesc => 'Demand charge reduction (\$/kW)';

  @override
  String get pdfRevBackup => '4. Backup Power Value';

  @override
  String get pdfRevBackupDesc => 'Avoided lost load during outages';

  @override
  String get pdfCashFlowTitle => '3. 20-Year Cash Flow Projection';

  @override
  String get pdfCfYear => 'Year';

  @override
  String get pdfCfEnergySavings => 'Energy Savings';

  @override
  String get pdfCfBackupValue => 'Backup Value';

  @override
  String get pdfCfOmBattery => 'O&M / Battery';

  @override
  String get pdfCfDebtService => 'Debt Service';

  @override
  String get pdfCfNetCashFlow => 'Net Cash Flow';

  @override
  String get pdfCfCumulative => 'Cumulative';

  @override
  String pdfDate(String date) {
    return 'Date: $date';
  }

  @override
  String pdfPageOf(String current, String total) {
    return 'Page $current of $total';
  }

  @override
  String get pdfConfidential => 'Confidential & Proprietary';

  @override
  String get logoutTooltip => 'Logout';

  @override
  String get logoutTitle => 'Logout';

  @override
  String get logoutMessage =>
      'Are you sure you want to log out of the current account?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmLogout => 'Logout';

  @override
  String get tierFree => 'Current Plan: FREE Edition';

  @override
  String get tierPro => '👑 PRO Subscription Member';

  @override
  String get accountEmailLabel => 'Account Email: ';

  @override
  String get proExpireDateLabel => 'Expires on: ';

  @override
  String get upgradeNow => 'Upgrade Now';

  @override
  String get forgotPasswordTitle => 'Reset Password';

  @override
  String get enterEmailPrompt => 'Enter your registered email address';

  @override
  String get sendCodeBtn => 'Send Code';

  @override
  String codeSentMsg(Object email) {
    return 'Code sent to $email';
  }

  @override
  String get codeInputHint => 'Enter 6-digit code';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmResetBtn => 'Confirm Reset';

  @override
  String get resendPrompt => 'Didn\'t receive it? Re-enter email';

  @override
  String get sessionExpired => 'Session expired, please log in again!';

  @override
  String get paymentConfirmTitle => 'Waiting for Payment';

  @override
  String get paymentConfirmDesc =>
      'If you have completed the payment in the browser, click the button below to verify and activate PRO.';

  @override
  String get verifyLater => 'Verify Later';

  @override
  String get paymentCompleted => 'I have paid';

  @override
  String get paymentSuccessPro =>
      '🎉 Payment successful! PRO features activated!';

  @override
  String get paymentPending =>
      '⏳ Payment not received yet. Please wait a few seconds and try again.';

  @override
  String paymentError(String error) {
    return 'Payment gateway error: $error';
  }

  @override
  String get errInvalidEmail => 'Please enter a valid email address';

  @override
  String get msgCodeSent => '✅ Code sent to your email, please check.';

  @override
  String get errCodeLength => 'Please enter a 6-digit code';

  @override
  String get errNewPwdLength => 'New password must be at least 6 characters';

  @override
  String get msgResetSuccess => '🎉 Password reset successful! Please log in.';

  @override
  String get errCodeInvalid => '❌ Invalid or expired code';

  @override
  String get msgPayToUpgrade =>
      '✅ After payment, please re-login to activate PRO features!';

  @override
  String get logoInputHint =>
      'Enter URL or click right to pick from gallery ->';

  @override
  String get msgLogoConverted =>
      '✅ Logo converted to Base64! Please click save.';

  @override
  String get errSaveFailed => 'Save failed, please check your network!';

  @override
  String get pdfPreviewTitle => 'Proposal Preview';

  @override
  String get appWindowTitle => 'Quote Master';

  @override
  String get termsOfServiceTitle => 'Terms of Service';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get refundPolicyTitle => 'Refund Policy';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get emailPlaceholder => 'example@gmail.com';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get close => 'Close';

  @override
  String get legalLoadFailed =>
      'Unable to load document right now. Please try again later.';

  @override
  String get footerCopyright => '© 2026 EnerQuote. All rights reserved.';

  @override
  String openInBrowserMessage(String title) {
    return 'Open $title in your browser.';
  }

  @override
  String get openInBrowser => 'Open in browser';
}
