import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/pdf_export.dart';
import '../core/network/api_client.dart';
import 'package:dio/dio.dart';
// 🌟 引入刚生成的实体多语言文件
import '../l10n/app_localizations.dart';
import 'settings_screen.dart';
import 'pdf_preview_screen.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sentry/sentry.dart';
import '../theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _pvCapacity = 60.0;
  double _batteryCapacity = 50.0;
  double _factoryPeakLoad = 80.0;
  double _totalCapex = 0.0;

  // 🌟 核心架构升级：解耦！
  // 这个字典只存物理坐标和纯净的 ID（永远不变）
  // final Map<String, Map<String, double>> _cityCoordinates = {
  //   'sao_paulo': {'lat': -23.5505, 'lon': -46.6333},
  //   'munich': {'lat': 48.1351, 'lon': 11.5820},
  //   'haikou': {'lat': 20.0311, 'lon': 110.3312},
  //   'linfen': {'lat': 36.0880, 'lon': 111.5190},
  // };

  // 🌟 动态存储从云端拉取下来的城市列表
  List<dynamic> _cloudCities = [];
// 选中的值依然只存 ID
  String _selectedCityId = 'sao_paulo';
  // 动态保存当前选中的经纬度（传给后端测算用）
  double _currentLat = -23.5505;
  double _currentLon = -46.6333;

  List<double> _cashFlowData = List.filled(20, 0.0);
  List<dynamic> _fullCashFlowData = [];

  double _npv = 0.0;
  double _irr = 0.0;
  double _payback = 0.0;
  double _annualGeneration = 0.0;

  bool _isLoading = false;
  String _errorMessage = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 页面初始化时延迟一帧执行，以确保能拿到安全的 context 用于多语言
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRealData();
    });
  }

  Future<void> _onCityChanged(String? newCityId) async {
    if (newCityId == null) return;

    // 🌟 1. 从本地掏出他在登录时拿到的真实权限卡
    final prefs = await SharedPreferences.getInstance();
    String currentUserTier = prefs.getString('user_tier') ?? "FREE";

    // 🌟 2. 核心逼单逻辑：如果他是免费用户，且想选择非默认城市 (比如慕尼黑)
    if (currentUserTier != "PRO" && newCityId != 'sao_paulo') {
      // 🚫 拒绝切换城市，并弹出我们刚写好的付费墙！
      _showProPaywall();
      return;
    }

    // ✅ 3. 权限校验通过（或者选的就是免费城市），放行并重新拉取测算数据
    setState(() => _selectedCityId = newCityId);
    _fetchRealData();
  }

  void _onSliderChanged(VoidCallback stateUpdate) {
    setState(stateUpdate);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
          () => _fetchRealData(),
    );
  }

  List<double> _generateFactoryLoadProfile(double peakLoad) {
    return List.generate(8760, (index) {
      int hour = index % 24;
      if (hour >= 8 && hour < 18) {
        return peakLoad;
      } else {
        return peakLoad * 0.2;
      }
    });
  }

  Future<void> _fetchRealData() async {
    // 提前在同步上下文中抓取语言包
    final l10n = AppLocalizations.of(context)!;

    // 🌟 如果本地还没有城市列表，先去云端拉取！
    if (_cloudCities.isEmpty) {
      final cities = await ApiClient().getSupportedCities();
      if (cities.isNotEmpty) {
        setState(() {
          _cloudCities = cities;
        });
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = l10n.unauthorized; // 🌟 多语言提示
        _isLoading = false;
      });
      return;
    }

    // 🌟 1. 从本地缓存动态读取销售的专属成本与利润率
    // 如果缓存没有（第一次登录），则使用后备默认值
    double pvCostPerKw = prefs.getDouble('pv_cost') ?? 800.0;
    double essCostPerKwh = prefs.getDouble('ess_cost') ?? 350.0;
    double marginPct = prefs.getDouble('margin_pct') ?? 20.0;

    // 🌟 2. 商业逻辑：计算底层硬成本 (Hard Cost)
    // 假设固定施工费 5000 刀
    double baseCost = (_pvCapacity * pvCostPerKw) + (_batteryCapacity * essCostPerKwh) + 5000.0;

    // 🌟 3. 商业逻辑：计算最终面向客户的报价 (Customer Price / CAPEX)
    double currentCapex = baseCost * (1 + (marginPct / 100.0));

    final payload = {
      "physics_params": {
        "env": {
          // 🌟 通过安全解耦的 ID 获取坐标
          "lat": _currentLat,
          "lon": _currentLon,
          "irradiance_8760": List.filled(8760, 600.0),
          "load_profile_8760": _generateFactoryLoadProfile(_factoryPeakLoad),
          "grid_status_8760": List.generate(8760, (index) => index % 24 == 18 ? 0 : 1),
        },
        "pv": {
          "pv_dc_capacity_kwp": _pvCapacity,
          "inverter_ac_capacity_kw": _pvCapacity * 0.8,
          "system_loss_factor": 0.15,
        },
        "ess": {
          "batt_nominal_capacity_kwh": _batteryCapacity,
          "dod_limit": 0.1,
          "max_charge_discharge_kw": _batteryCapacity * 0.5,
          "rte_efficiency": 0.90,
          "initial_soc": 1.0,
        },
        "grid": {"export_limit_kw": 0.0},
      },
      "financial_params": {
        "total_capex": currentCapex,
        "annual_opex": 150.0 + (_pvCapacity * 2),
        "battery_replacement_cost": _batteryCapacity * 200,
        "battery_replacement_year": 10,
        "current_electricity_price": 0.25,
        "electricity_inflation_rate": 0.08,
        "voll_price": 2.0,
        "system_degradation_rate": 0.015,
        "down_payment_pct": 0.20,
        "loan_term_years": 5,
        "loan_interest_rate": 0.12,
        "discount_rate": 0.10,
        "project_lifespan": 20,
      },
    };

    try {
      final response = await ApiClient().dio.post(
        '/simulate',
        data: payload,
      );

      final data = response.data;

      setState(() {
        final financial = data['finance_result'] ?? {};
        final physics = data['physics_result'] ?? {};
        final physicsKpis = physics['kpis'] ?? {};

        _annualGeneration = (physicsKpis['total_generation_kwh'] as num?)?.toDouble() ?? 0.0;
        _totalCapex = (financial['total_capex'] as num?)?.toDouble() ?? currentCapex;
        _irr = (financial['irr'] as num?)?.toDouble() ?? 0.0;
        _npv = (financial['npv'] as num?)?.toDouble() ?? 0.0;
        _payback = (financial['payback_period_years'] as num?)?.toDouble() ?? 0.0;

        if (financial['cash_flow_statement'] != null) {
          _cashFlowData = (financial['cash_flow_statement'] as List)
              .skip(1)
              .map((e) => (e['net_cash_flow'] as num).toDouble())
              .toList();
        }

        _fullCashFlowData = financial['cash_flow_statement'] ?? [];
      });

    } on DioException catch (e, stackTrace) {
      print("🔴 Dio Error: ${e.response?.data}");

      // 🌟 主动把这种非致命错误也传给 Sentry 控制台
      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
      );

      setState(() {
        final errorMsg = e.response?.data['detail'] ?? e.message ?? "Error";
        _errorMessage = l10n.simulateFailed(errorMsg); // 🌟 动态抛错
      });
    } catch (e, stacktrace) {
      print("🔥 Parse Error: $e");
      print(stacktrace);

    // 🌟 主动把这种非致命错误也传给 Sentry 控制台
    await Sentry.captureException(
    e,
    stackTrace: stacktrace,
    );

      setState(() {
        _errorMessage = l10n.parseError; // 🌟 兜底报错
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 🌟 动态映射字典：根据当前语言环境，把纯净 ID 映射成带国旗的超长显示名字
    final Map<String, String> cityDisplayNames = {
      'sao_paulo': l10n.citySaoPaulo,
      'munich': l10n.cityMunich,
      'haikou': l10n.cityHaikou,
      'linfen': l10n.cityLinfen,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.dashboardTitle, // 🌟
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.onSurface),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [


          IconButton(
            tooltip: l10n.exportProposal, // 🌟
            icon: Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.primary),
            onPressed: _isLoading
                ? null
                : () async {

              // 🌟 1. 拿取真实的权限等级和自定义公司名
              final prefs = await SharedPreferences.getInstance();
              String currentUserTier = prefs.getString('user_tier') ?? "FREE";
              String customCompanyName = prefs.getString('company_name') ?? "PV+ESS QUOTE MASTER";
              String customLogoUrl = prefs.getString('logo_url') ?? ""; // 👈 获取 Logo 链接
              print("👉 [2. 主页读取] 导出 PDF 前，从本地拿到的 Logo 长度: ${customLogoUrl.length}");

              // 🌟 2. 终极付费墙拦截！
              if (currentUserTier != "PRO") {
                _showProPaywall();
              } else {
                // ✅ PRO 用户：直接放行！把他的定制公司名传给 PDF 引擎

                // 1. 拿到生成的 PDF 字节流
                final bytes = await PdfExport.generateAndPrintProposal(
                  l10n: l10n,
                  companyName: customCompanyName,
                  logoUrl: customLogoUrl,        // 👈 传入 Logo
                  pvCapacity: _pvCapacity,
                  batteryCapacity: _batteryCapacity,
                  totalCapex: _totalCapex,
                  npv: _npv,
                  irr: _irr,
                  payback: _payback,
                  fullCashFlowData: _fullCashFlowData,
                );

                if (!mounted) return;

                // 🌟 2. 跳转到高大上的预览页！
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(pdfBytes: bytes),
                  ),
                );

              }
            },
          ),
          // 🌟 新增的设置齿轮按钮
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: AppColors.onSurfaceVariant),
            onPressed: () async {
              // 🌟 1. 加上 await，等待用户从设置页返回
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );

              // 🌟 2. 用户返回后，立刻触发重新测算，应用他刚改的成本和利润率！
              if (mounted) {
                _fetchRealData();
              }
            },
          ),
          // 🌟 1. 国际化版本的登出按钮
          IconButton(
            tooltip: l10n.logoutTooltip, // 👈 替换 Tooltip
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              // 弹出确认对话框
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.logoutTitle, style: const TextStyle(color: AppColors.onSurface)), // 👈 替换标题
                  content: Text(l10n.logoutMessage, style: const TextStyle(color: AppColors.onSurfaceVariant)), // 👈 替换内容
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel, style: const TextStyle(color: AppColors.onSurfaceVariant)), // 👈 替换取消
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.confirmLogout, style: const TextStyle(color: Colors.redAccent)), // 👈 替换确认
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // 1. 撕毁本地门禁卡
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('jwt_token');
                await prefs.remove('user_tier');

                if (!mounted) return;

                // 2. 踢回登录页，并摧毁之前的全部路由记录
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _buildKpiCard(
                  l10n.kpiTotalCapex, // 🌟
                  '\$${_totalCapex.toStringAsFixed(0)}',
                  Colors.redAccent,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  l10n.kpiIrr, // 🌟
                  '${_irr.toStringAsFixed(1)}%',
                  AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  l10n.kpiFirstYearGen, // 🌟
                  '${(_annualGeneration / 1000).toStringAsFixed(1)} MWh',
                  Colors.amber,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  l10n.kpiPayback, // 🌟
                  '${_payback.toStringAsFixed(1)} Yrs',
                  AppColors.onSurface,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.clientEnvProfile, // 🌟
                              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              // 🌟 核心：极其安全的下拉菜单渲染逻辑
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCityId, // 内部永远用干净的 ID
                                  isExpanded: true,
                                  dropdownColor: AppColors.background,
                                  // 🌟 核心：依靠云端数据动态渲染！
                                  items: _cloudCities.map((cityObj) {
                                    // 自动识别当前手机语言，提取对应的多语言名字
                                    String langCode = Localizations.localeOf(context).languageCode;
                                    String displayName = cityObj['name'][langCode] ?? cityObj['name']['en'];
                                    bool isProOnly = cityObj['is_pro_only'];

                                    return DropdownMenuItem<String>(
                                      value: cityObj['id'],
                                      child: Row(
                                        children: [
                                          Text(displayName, style: const TextStyle(fontSize: 14, color: AppColors.onSurface)),
                                          if (isProOnly) ...[
                                            const SizedBox(width: 8),
                                            const Icon(Icons.workspace_premium, color: Colors.amber, size: 14),
                                          ]
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newCityId) async {
                                    if (newCityId == null) return;

                                    // 在云端列表里找出用户选的这个城市
                                    final selectedCityObj = _cloudCities.firstWhere((c) => c['id'] == newCityId);

                                    // 1. 掏出权限卡
                                    final prefs = await SharedPreferences.getInstance();
                                    String currentUserTier = prefs.getString('user_tier') ?? "FREE";

                                    // 2. 🌟 云端级防黑客拦截：如果云端标记这个城市是 PRO，且用户是免费的，直接拦截！
                                    if (selectedCityObj['is_pro_only'] == true && currentUserTier != "PRO") {
                                      _showProPaywall();
                                      return;
                                    }

                                    // 3. 放行，更新当前坐标并重新测算
                                    setState(() {
                                      _selectedCityId = newCityId;
                                      _currentLat = selectedCityObj['lat'];
                                      _currentLon = selectedCityObj['lon'];
                                    });
                                    _fetchRealData();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            Text(
                              l10n.factoryPeakLoad(_factoryPeakLoad.toStringAsFixed(0)), // 🌟
                              style: const TextStyle(fontSize: 14, color: Color(0xFF0EA5E9)),
                            ),
                            Slider(
                              value: _factoryPeakLoad,
                              min: 10.0,
                              max: 200.0,
                              divisions: 38,
                              activeColor: const Color(0xFF0EA5E9),
                              inactiveColor: AppColors.border,
                              onChanged: (v) => _onSliderChanged(() => _factoryPeakLoad = v),
                            ),

                            const Divider(color: AppColors.border, height: 16),
                            Text(
                              l10n.hardwareConfig, // 🌟
                              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                            ),
                            const SizedBox(height: 6),

                            Text(
                              l10n.pvCapacity(_pvCapacity.toStringAsFixed(0)), // 🌟
                              style: const TextStyle(fontSize: 14, color: AppColors.secondary),
                            ),
                            Slider(
                              value: _pvCapacity,
                              min: 0.0,
                              max: 200.0,
                              divisions: 40,
                              activeColor: AppColors.secondary,
                              inactiveColor: AppColors.border,
                              onChanged: (v) => _onSliderChanged(() => _pvCapacity = v),
                            ),

                            Text(
                              l10n.essCapacity(_batteryCapacity.toStringAsFixed(0)), // 🌟
                              style: const TextStyle(fontSize: 14, color: AppColors.success),
                            ),
                            Slider(
                              value: _batteryCapacity,
                              min: 0.0,
                              max: 200.0,
                              divisions: 40,
                              activeColor: AppColors.success,
                              inactiveColor: AppColors.border,
                              onChanged: (v) => _onSliderChanged(() => _batteryCapacity = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start, // 🌟 顶部对齐
                          children: [
                            Expanded( // 🌟 核心修复：套上 Expanded，强制它在规定范围内
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  maxLines: 2, // 这里顺便也改成 2 行，防止报错信息过长
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (_errorMessage.isNotEmpty)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Stack(
                            children: [
                              BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (group) => AppColors.onSurface,
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          '\$${rod.toY.toStringAsFixed(0)}',
                                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          if (value % 5 == 0 || value == 1) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                l10n.yearFormat(value.toInt().toString()), // 🌟 动态年份
                                                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.chartGrid, strokeWidth: 1),
                                  ),
                                  barGroups: _cashFlowData.asMap().entries.map((entry) {
                                    bool isPositive = entry.value >= 0;
                                    return BarChartGroupData(
                                      x: entry.key + 1,
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value,
                                          width: 14,
                                          color: isPositive ? AppColors.success : AppColors.danger,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                                swapAnimationDuration: const Duration(milliseconds: 350),
                                swapAnimationCurve: Curves.easeOutCubic,
                              ),
                              if (_isLoading)
                                Container(
                                  color: AppColors.overlayScrim,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(color: AppColors.primary),
                                        const SizedBox(height: 16),
                                        Text(
                                          l10n.connectingPvgis, // 🌟
                                          style: const TextStyle(color: AppColors.primary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // 🌟 核心：触发国际化版本的付费墙弹窗 (已修复溢出问题)
  void _showProPaywall() {
    final l10n = AppLocalizations.of(context)!; // 召唤多语言

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🌟 1. 突破默认半屏的高度限制！
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext buildContext) {
        // 🌟 2. 套上 SafeArea 防止被底部小白条遮挡
        return SafeArea(
          // 🌟 3. 套上 SingleChildScrollView，高度不够时自动变成可滑动，彻底告别溢出！
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.workspace_premium, size: 64, color: AppColors.secondary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.upgradeToProTitle, // 🌟 动态标题
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.upgradeToProSubtitle, // 🌟 动态副标题
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  // 🌟 动态权益列表
                  _buildProFeatureRow(Icons.check_circle, l10n.proFeatureLogo, AppColors.secondary),
                  _buildProFeatureRow(Icons.check_circle, l10n.proFeatureCost, AppColors.secondary),
                  // _buildProFeatureRow(Icons.check_circle, l10n.proFeaturePvgis, Colors.amber),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    // 🌟 核心修复：注入 Paddle 托管结账唤起逻辑
                    onPressed: () async {
                      // 1. 先关闭当前的付费墙弹窗
                      Navigator.pop(buildContext);

                      // 2. 告诉用户稍等
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.redirectingToPayment)),
                      );

                      try {
                        // 3. 向云端索要 Paddle 结账链接
                        final urlStr = await ApiClient().getPaddleCheckoutUrl();

                        if (urlStr != null) {
                          final Uri url = Uri.parse(urlStr);

                          // 4. 瞬间打破次元壁，唤起手机原生浏览器！
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            throw Exception('无法唤起原生浏览器');
                          }

                          if (!mounted) return;

                          // 🌟 5. 商业级交互：弹出一个不可关闭的确认框，等待用户从浏览器切回来
                          showDialog(
                            context: context,
                            barrierDismissible: false, // 强制用户必须点按钮
                            builder: (dialogContext) => AlertDialog(
                              title: Text(l10n.paymentConfirmTitle, style: const TextStyle(color: AppColors.onSurface)),
                              content: Text(l10n.paymentConfirmDesc, style: const TextStyle(color: AppColors.onSurfaceVariant)),
                              actions: [
                                TextButton(
                                  child: Text(l10n.verifyLater, style: const TextStyle(color: AppColors.onSurfaceVariant)),
                                  onPressed: () => Navigator.pop(dialogContext),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: AppColors.onSecondary),
                                  child: Text(l10n.paymentCompleted, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    // 🌟 核心逻辑：用户点确认后，向后端请求最新的 Token
                                    final newTier = await ApiClient().refreshUserToken();

                                    if (!mounted) return;

                                    if (newTier == "PRO") {
                                      Navigator.pop(dialogContext); // 关掉确认框

                                      // 触发页面刷新，去掉所有付费墙限制
                                      setState(() {});

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(l10n.paymentSuccessPro), backgroundColor: AppColors.success),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(l10n.paymentPending), backgroundColor: Colors.orange),
                                      );
                                    }
                                  },
                                )
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.paymentError(e.toString())), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      l10n.unlockProBtn, // 🌟 动态按钮文字
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

  Widget _buildProFeatureRow(IconData icon, String text, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.onSurface, fontSize: 14)),
          ),
        ],
      ),
    );
  }

}