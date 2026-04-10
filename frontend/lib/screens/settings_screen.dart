import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../core/network/api_client.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // 用于 Base64 转换
import '../theme/app_colors.dart';
import 'paddle_checkout_webview.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  String _userTier = "FREE"; // 🌟 新增身份变量
  String _currentAccount = '-';
  bool _isUpgrading = false; // 🌟 新增：是否正在呼叫收银台

  // 控制器
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();
  final TextEditingController _pvCostController = TextEditingController();
  final TextEditingController _essCostController = TextEditingController();
  final TextEditingController _marginController = TextEditingController();

  bool _isLoading = true;

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


      setState(() {
        _userTier = prefs.getString('user_tier') ?? "FREE"; // 🌟 捞出身价
        _currentAccount = account.isEmpty ? '-' : account;
        _companyNameController.text = data['company_name'] ?? '';
        _logoUrlController.text = data['logo_url'] ?? '';
        _pvCostController.text = data['pv_cost_per_kw']?.toString() ?? '800.0';
        _essCostController.text = data['ess_cost_per_kwh']?.toString() ?? '350.0';
        _marginController.text = data['margin_pct']?.toString() ?? '20.0';
        _isLoading = false;
      });

      // 顺手备份到本地，给主页测算用
      await prefs.setString('company_name', _companyNameController.text);
      await prefs.setDouble('pv_cost', double.tryParse(_pvCostController.text) ?? 800.0);
      await prefs.setDouble('ess_cost', double.tryParse(_essCostController.text) ?? 350.0);
      await prefs.setDouble('margin_pct', double.tryParse(_marginController.text) ?? 20.0);

    } catch (e) {
      print("拉取云端配置失败: $e");
      // 如果断网或失败，降级使用本地缓存 (保持你原有的逻辑不变)
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userTier = prefs.getString('user_tier') ?? "FREE";
        _currentAccount = '-';
        _companyNameController.text = prefs.getString('company_name') ?? '';
        _pvCostController.text = prefs.getDouble('pv_cost')?.toString() ?? '800.0';
        _logoUrlController.text = prefs.getString('logo_url') ?? '';
        _essCostController.text = prefs.getDouble('ess_cost')?.toString() ?? '350.0'; // 默认 350
        _marginController.text = prefs.getDouble('margin_pct')?.toString() ?? '20.0'; // 默认 20%
        _isLoading = false;
      });
    }
  }

  // 🌟 点击保存，将数据写入本地缓存
  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
  FocusScope.of(context).unfocus();

  try {
    // 1. 推送到云端
    await ApiClient().dio.put('/settings/me', data: {
      "company_name": _companyNameController.text.trim(),
      "logo_url": _logoUrlController.text.trim(),
      "pv_cost_per_kw": double.tryParse(_pvCostController.text) ?? 800.0,
      "ess_cost_per_kwh": double.tryParse(_essCostController.text) ?? 350.0,
      "margin_pct": double.tryParse(_marginController.text) ?? 20.0,
    });

    // 2. 备份到本地 (主页需要用到)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', _companyNameController.text.trim());
    await prefs.setString('logo_url', _logoUrlController.text.trim());
    print("👉 [1. 存入设置] 准备存入本地的 Logo 长度: ${_logoUrlController.text.trim().length}");
    await prefs.setDouble('pv_cost', double.tryParse(_pvCostController.text) ?? 800.0);
    await prefs.setDouble('ess_cost', double.tryParse(_essCostController.text) ?? 350.0);
    await prefs.setDouble('margin_pct', double.tryParse(_marginController.text) ?? 20.0);

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
                        ],
                      ),
                    ),
                    if (_userTier != "PRO")
                      ElevatedButton(
                        // 🌟 防连点：正在加载时按钮变灰并禁用
                        onPressed: _isUpgrading ? null : () async {
                          setState(() {
                            _isUpgrading = true;
                          });

                          try {
                            // 1. 向后端索要支付链接
                            final urlStr = await ApiClient().getPaddleCheckoutUrl();

                            if (urlStr != null) {
                              final ptxn = await Navigator.of(context).push<String>(
                                MaterialPageRoute(
                                  builder: (_) => PaddleCheckoutWebView(checkoutUrl: urlStr),
                                ),
                              );

                              if (!mounted) return;
                              if (ptxn == null || ptxn.isEmpty) {
                                return;
                              }

                              final newTier = await ApiClient().refreshUserToken();
                              if (newTier == "PRO") {
                                setState(() {
                                  _userTier = "PRO";
                                });
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newTier == "PRO" ? l10n.paymentSuccessPro : l10n.paymentPending,
                                  ),
                                  backgroundColor: newTier == "PRO" ? AppColors.success : Colors.orange,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
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
                        },
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
              // 🎨 品牌设置卡片
              _buildSectionHeader(Icons.branding_watermark, l10n.brandingSection),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildTextField(_companyNameController, l10n.companyNameLabel, Icons.business),
                const SizedBox(height: 16),
          _buildTextField(
            _logoUrlController,
            l10n.logoUrlLabel,
            Icons.image,
            hintText: l10n.logoInputHint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.photo_library, color: AppColors.secondary),
              onPressed: () async {
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
                } catch (e) {
                  print("选取图片失败: $e");
                }
              },
            ),
          ),
              ]),

              const SizedBox(height: 32),

              // 💰 成本设置卡片
              _buildSectionHeader(Icons.attach_money, l10n.costSection),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildTextField(_pvCostController, l10n.pvCostLabel, Icons.solar_power, isNumber: true),
                const SizedBox(height: 16),
                _buildTextField(_essCostController, l10n.essCostLabel, Icons.battery_charging_full, isNumber: true),
                const SizedBox(height: 16),
                _buildTextField(_marginController, l10n.marginLabel, Icons.percent, isNumber: true),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // UI 辅助方法：段落标题
  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
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
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, String? hintText, Widget? suffixIcon}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.75)),
        prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
        suffixIcon: suffixIcon, // 🌟 挂载右侧的相册按钮
      ),
    );
  }
}