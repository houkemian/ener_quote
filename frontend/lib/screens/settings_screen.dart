import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io' show Platform;
import '../l10n/app_localizations.dart';
import '../core/network/api_client.dart';
import '../core/billing/revenuecat_service.dart';
import '../core/auth/token_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // 用于 Base64 转换
import '../theme/app_colors.dart';
import 'paddle_checkout_webview.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _defaultCompanyName = 'EnerQuote';

  String _userTier = "FREE"; // 🌟 新增身份变量
  String _currentAccount = '-';
  String? _proExpireDateText;
  bool _isUpgrading = false; // 🌟 新增：是否正在呼叫收银台
  bool _isRevenueCatLoading = false;
  bool _isPurchasing = false;
  Offerings? _revenueCatOfferings;
  String? _revenueCatError;

  // 控制器
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();
  final TextEditingController _pvCostController = TextEditingController();
  final TextEditingController _essCostController = TextEditingController();
  final TextEditingController _marginController = TextEditingController();

  bool _isLoading = true;
  bool get _canEditCosts => _userTier == "PRO";
  bool get _isAndroidRevenueCatFlow => !kIsWeb && Platform.isAndroid;
  bool _costPanelExpanded = false;
  String? _lastShownBillingGraceKey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 🌟 初始化时从云端拉取配置
  Future<void> _loadSettings() async {
    try {
      // 优先从云端拉取
      final response = await ApiClient().dio.get('/settings/me');
      final data = response.data;
      final prefs = await SharedPreferences.getInstance();
      final account = (data['account_email'] ?? '-').toString().trim();
      final tierFromApi = (data['tier'] ?? "FREE").toString();
      final proExpireText = _formatExpireDate(data['pro_expire_date']);
      final billingIssueGraceUntilRaw = data['billing_issue_grace_until']?.toString();

      setState(() {
        _userTier = tierFromApi; // 🌟 以服务端综合判断结果为准
        _currentAccount = account.isEmpty ? '-' : account;
        _proExpireDateText = tierFromApi == "PRO" ? proExpireText : null;
        _companyNameController.text = (data['company_name'] ?? _defaultCompanyName).toString();
        _logoUrlController.text = data['logo_url'] ?? '';
        _pvCostController.text = data['pv_cost_per_kw']?.toString() ?? '800.0';
        _essCostController.text = data['ess_cost_per_kwh']?.toString() ?? '350.0';
        _marginController.text = data['margin_pct']?.toString() ?? '25.0';
        _isLoading = false;
      });

      // 顺手备份到本地，给主页测算用
      await prefs.setString('user_tier', tierFromApi);
      await prefs.setString('company_name', _companyNameController.text);
      await prefs.setDouble('pv_cost', double.tryParse(_pvCostController.text) ?? 800.0);
      await prefs.setDouble('ess_cost', double.tryParse(_essCostController.text) ?? 350.0);
      await prefs.setDouble('margin_pct', double.tryParse(_marginController.text) ?? 25.0);
      _showBillingIssueNoticeIfNeeded(billingIssueGraceUntilRaw);

    } catch (e) {
      // 如果断网或失败，降级使用本地缓存 (保持你原有的逻辑不变)
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userTier = prefs.getString('user_tier') ?? "FREE";
        _currentAccount = '-';
        _proExpireDateText = null;
        _companyNameController.text = prefs.getString('company_name') ?? _defaultCompanyName;
        _pvCostController.text = prefs.getDouble('pv_cost')?.toString() ?? '800.0';
        _logoUrlController.text = prefs.getString('logo_url') ?? '';
        _essCostController.text = prefs.getDouble('ess_cost')?.toString() ?? '350.0'; // 默认 350
        _marginController.text = prefs.getDouble('margin_pct')?.toString() ?? '25.0'; // 默认 25%
        _isLoading = false;
      });
    }
  }

  void _showBillingIssueNoticeIfNeeded(String? billingIssueGraceUntilRaw) {
    if (!mounted) {
      return;
    }
    final raw = billingIssueGraceUntilRaw?.trim();
    if (raw == null || raw.isEmpty) {
      return;
    }
    final graceUntil = DateTime.tryParse(raw);
    if (graceUntil == null || !graceUntil.isAfter(DateTime.now())) {
      return;
    }
    if (_lastShownBillingGraceKey == raw) {
      return;
    }
    _lastShownBillingGraceKey = raw;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.billingIssueGraceNotice),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // 🌟 点击保存，将数据写入本地缓存
  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
  FocusScope.of(context).unfocus();

  try {
    final Map<String, dynamic> payload = {
      "company_name": _companyNameController.text.trim(),
      "logo_url": _logoUrlController.text.trim(),
    };
    if (_canEditCosts) {
      payload["pv_cost_per_kw"] = double.tryParse(_pvCostController.text) ?? 800.0;
      payload["ess_cost_per_kwh"] = double.tryParse(_essCostController.text) ?? 350.0;
      payload["margin_pct"] = double.tryParse(_marginController.text) ?? 25.0;
    }

    // 1. 推送到云端
    await ApiClient().dio.put('/settings/me', data: payload);

    // 2. 备份到本地 (主页需要用到)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', _companyNameController.text.trim());
    await prefs.setString('logo_url', _logoUrlController.text.trim());
    await prefs.setDouble('pv_cost', double.tryParse(_pvCostController.text) ?? 800.0);
    await prefs.setDouble('ess_cost', double.tryParse(_essCostController.text) ?? 350.0);
    await prefs.setDouble('margin_pct', double.tryParse(_marginController.text) ?? 25.0);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.saveSuccess),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.errSaveFailed), backgroundColor: Colors.red),
    );
  }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🌟 核心：身份卡片渲染！
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: _userTier == "PRO"
                      ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFDE68A)])
                      : const LinearGradient(colors: [AppColors.surfaceMuted, AppColors.surface]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _userTier == "PRO" ? AppColors.secondary : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userTier == "PRO" ? l10n.tierPro : l10n.tierFree,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _userTier == "PRO" ? AppColors.onSecondary : AppColors.onSurfaceVariant,
                            ),
                      ),
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.accountEmailLabel}$_currentAccount',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: _userTier == "PRO" ? AppColors.onSecondary : AppColors.onSurfaceVariant,
                            ),
                          ),
                          if (_userTier == "PRO" && _proExpireDateText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${l10n.proExpireDateLabel}$_proExpireDateText',
                              style: TextStyle(
                                fontSize: 12,
                                color: _userTier == "PRO" ? AppColors.onSecondary : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_userTier != "PRO")
                      ElevatedButton(
                        // 先打开付费墙，再由弹窗按钮进入支付
                        onPressed: _isUpgrading ? null : _showProPaywall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.onSecondary,
                          minimumSize: const Size(80, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        // 🌟 动态 UI：加载时显示转圈圈，平时显示文字
                        child: _isUpgrading
                            ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: const CircularProgressIndicator(strokeWidth: 2)
                        )
                            : Text(l10n.upgradeNow, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              // 🎨 品牌设置卡片（FREE 锁定）
              _buildSectionHeader(
                Icons.branding_watermark,
                l10n.brandingSection,
                showProBadge: true,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildTextField(
                  _companyNameController,
                  l10n.companyNameLabel,
                  Icons.business,
                  enabled: _userTier == "PRO",
                ),
                const SizedBox(height: 16),
          _buildTextField(
            _logoUrlController,
            l10n.logoUrlLabel,
            Icons.image,
            enabled: _userTier == "PRO",
            hintText: l10n.logoInputHint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.photo_library, color: AppColors.secondary),
              onPressed: () async {
                if (_userTier != "PRO") {
                  _showProPaywall(customSubtitle: l10n.proBrandingPaywallSubtitle);
                  return;
                }
                try {
                  final picker = ImagePicker();
                  // 🌟 核心：从相册选图，并强制压缩宽度以防 Base64 太长撑爆数据库！
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 300,
                    imageQuality: 80,
                  );
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    final base64Str = base64Encode(bytes);
                    setState(() {
                      // 瞬间填入转化好的 Base64 密文！
                      _logoUrlController.text = base64Str;
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.msgLogoConverted), backgroundColor: AppColors.success),
                    );
                  }
                } catch (_) {}
              },
            ),
          ),
              ]),

              const SizedBox(height: 32),

              // 💰 高级成本设置（PRO 折叠面板）
              _buildSectionHeader(
                Icons.attach_money,
                '⚙️ ${l10n.advancedCostCalculatorTitle}',
                showProBadge: true,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard([
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _costPanelExpanded = !_costPanelExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.tapToExpandCostSettings,
                            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                        Icon(
                          _costPanelExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_costPanelExpanded) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    _pvCostController,
                    l10n.pvCostLabel,
                    Icons.solar_power,
                    isNumber: true,
                    tooltipMessage: l10n.pvCostCogsHint,
                    enabled: _canEditCosts,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_essCostController, l10n.essCostLabel, Icons.battery_charging_full, isNumber: true, enabled: _canEditCosts),
                  const SizedBox(height: 16),
                  _buildTextField(_marginController, l10n.marginLabel, Icons.percent, isNumber: true, enabled: _canEditCosts),
                ],
              ]),

              const SizedBox(height: 40),

              // 💾 保存按钮
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  l10n.saveSettingsBtn,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _showDeleteAccountDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // UI 辅助方法：段落标题
  Widget _buildSectionHeader(IconData icon, String title, {bool showProBadge = false}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (showProBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD66B),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '[PRO]',
              style: TextStyle(
                color: Color(0xFF5B3A00),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  // UI 辅助方法：设置项卡片
  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  // UI 辅助方法：输入框
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    String? hintText,
    String? helperText,
    String? tooltipMessage,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    final field = TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: tooltipMessage == null || tooltipMessage.trim().isEmpty ? label : null,
        hintText: hintText,
        helperText: helperText,
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.75)),
        prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
        suffixIcon: suffixIcon, // 🌟 挂载右侧的相册按钮
      ),
    );

    if (tooltipMessage == null || tooltipMessage.trim().isEmpty) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: _buildFieldLabel(label, tooltipMessage),
        ),
        field,
      ],
    );
  }

  Widget _buildFieldLabel(String label, String? tooltipMessage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: tooltipMessage,
          triggerMode: TooltipTriggerMode.tap,
          waitDuration: const Duration(milliseconds: 120),
          showDuration: const Duration(seconds: 4),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _formatExpireDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.toString().trim();
    if (value.isEmpty) {
      return null;
    }
    final dt = DateTime.tryParse(value);
    if (dt == null) {
      return value;
    }
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  Future<void> _showProPaywall({String? customSubtitle}) async {
    if (_isAndroidRevenueCatFlow) {
      await _loadRevenueCatOfferings();
    }
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (buildContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium, size: 28, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Text(
                        l10n.upgradeToProTitle,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customSubtitle ?? l10n.upgradeToProSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  _buildProFeatureRow(l10n.proFeatureLogo),
                  _buildProFeatureRow(l10n.proFeatureCost),
                  _buildProFeatureRow(l10n.proFeatureROI),
                  _buildProFeatureRow(l10n.proFeatureNoWatermark),
                  const SizedBox(height: 32),
                  _isAndroidRevenueCatFlow
                      ? _buildRevenueCatSection(buildContext, l10n)
                      : ElevatedButton(
                          onPressed: () => _startCheckoutFromPaywall(buildContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.onSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            l10n.unlockProBtn,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.onSurface, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRevenueCatOfferings() async {
    if (!_isAndroidRevenueCatFlow) {
      return;
    }
    if (_isRevenueCatLoading) {
      return;
    }
    setState(() {
      _isRevenueCatLoading = true;
      _revenueCatError = null;
    });
    try {
      await RevenueCatService.ensureInitialized();
      final offerings = await Purchases.getOfferings();
      setState(() {
        _revenueCatOfferings = offerings;
      });
    } on PlatformException catch (e) {
      setState(() {
        _revenueCatError = e.message ?? e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRevenueCatLoading = false;
        });
      }
    }
  }

  Widget _buildRevenueCatSection(BuildContext bottomSheetContext, AppLocalizations l10n) {
    if (_isRevenueCatLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_revenueCatError != null) {
      return Text(
        _revenueCatError!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
      );
    }

    final packages = _revenueCatOfferings?.current?.availablePackages ?? const <Package>[];
    if (packages.isEmpty) {
      return const Text(
        'No Android subscription package is currently available.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: packages.map((pkg) {
        final product = pkg.storeProduct;
        final title = product.title.trim().isNotEmpty ? product.title : pkg.identifier;
        final subtitle = product.description.trim();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.priceString,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPurchasing
                      ? null
                      : () => _purchaseRevenueCatPackage(pkg, bottomSheetContext, l10n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.onSecondary,
                  ),
                  child: _isPurchasing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Connecting Secure Pay...'),
                          ],
                        )
                      : const Text('Upgrade to PRO'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _purchaseRevenueCatPackage(
    Package package,
    BuildContext bottomSheetContext,
    AppLocalizations l10n,
  ) async {
    if (_isPurchasing) {
      return;
    }
    setState(() {
      _isPurchasing = true;
    });
    try {
      await RevenueCatService.ensureInitialized();
      final purchaseResult = await Purchases.purchasePackage(package);
      final isProActive =
          purchaseResult.customerInfo.entitlements.all['pro']?.isActive == true;
      if (!isProActive) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase completed, waiting entitlement sync.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_tier', 'PRO');
      if (mounted) {
        setState(() {
          _userTier = "PRO";
          _proExpireDateText = null;
        });
      }
      if (mounted) {
        Navigator.pop(bottomSheetContext);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentSuccessPro),
          backgroundColor: AppColors.success,
        ),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentError(e.message ?? e.toString())),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _startCheckoutFromPaywall(BuildContext bottomSheetContext) async {
    final l10n = AppLocalizations.of(context)!;
    Navigator.pop(bottomSheetContext);
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentError('Paddle checkout is only available on Web.')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isUpgrading = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.redirectingToPayment)),
    );

    try {
      final urlStr = await ApiClient().getPaddleCheckoutUrl();
      if (urlStr == null || !mounted) return;
      final ptxn = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PaddleCheckoutWebView(checkoutUrl: urlStr),
        ),
      );
      if (!mounted || ptxn == null || ptxn.isEmpty) return;

      final newTier = await ApiClient().refreshUserTierWithRetry();
      if (!mounted) return;
      if (newTier == "PRO") {
        await _loadSettings();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newTier == "PRO" ? l10n.paymentSuccessPro : l10n.paymentPending),
          backgroundColor: newTier == "PRO" ? AppColors.success : Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paymentError(e.toString())), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpgrading = false;
        });
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (actionContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Account'),
              content: const Text(
                'Are you sure? All your data will be permanently deleted.\n\n'
                '⚠️ IMPORTANT: Deleting your account does NOT cancel your Google Play subscription. '
                'Please manage your subscriptions in the Play Store.',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });
                          await _deleteAccountAndRedirect(actionContext);
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccountAndRedirect(BuildContext context) async {
    try {
      await ApiClient().deleteAccount();
      await Purchases.logOut();

      await TokenManager.clearAccessToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_tier');
      await prefs.remove('company_name');
      await prefs.remove('logo_url');
      await prefs.remove('pv_cost');
      await prefs.remove('ess_cost');
      await prefs.remove('margin_pct');

      if (!context.mounted) {
        return;
      }

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}