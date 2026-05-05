import 'package:dio/dio.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/billing/revenuecat_service.dart';
import '../core/network/api_client.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/pro_paywall_sheet.dart';
import 'pdf_preview_screen.dart';

class CalculationScreen extends StatefulWidget {
  final String? projectId;
  final String? calculationId;

  const CalculationScreen({super.key, this.projectId, this.calculationId});

  @override
  State<CalculationScreen> createState() => _CalculationScreenState();
}

class _CalculationScreenState extends State<CalculationScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _pvCostController = TextEditingController();
  final TextEditingController _essCostController = TextEditingController();
  final TextEditingController _marginController = TextEditingController();

  double _pvCapacity = 60;
  double _batteryCapacity = 50;
  double _factoryPeakLoad = 80;
  String _versionName = '';
  bool _loading = false;
  bool _restoring = false;
  bool _isProUser = false;
  bool _independentCosts = false;
  bool _isEditingIndependentCosts = false;
  bool _isPurchasing = false;
  String _error = '';
  Map<String, dynamic>? _latestResult;
  double _pvCostPerKw = 800.0;
  double _essCostPerKwh = 350.0;
  double _marginPct = 20.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    _loadTierAndCostDefaults();
    if (widget.calculationId != null && widget.projectId != null) {
      _restoreFromCalculation();
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    final isPro = info.entitlements.all['pro']?.isActive == true;
    if (!isPro || !mounted) return;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('user_tier', 'PRO'));
    setState(() => _isProUser = true);
  }

  Future<void> _loadTierAndCostDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isProUser = (prefs.getString('user_tier') ?? 'FREE') == 'PRO';
      _pvCostPerKw = prefs.getDouble('pv_cost') ?? 800.0;
      _essCostPerKwh = prefs.getDouble('ess_cost') ?? 350.0;
      _marginPct = prefs.getDouble('margin_pct') ?? 20.0;
    });
    _syncCostControllers();
  }

  Future<void> _saveGlobalCosts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pv_cost', _pvCostPerKw);
    await prefs.setDouble('ess_cost', _essCostPerKwh);
    await prefs.setDouble('margin_pct', _marginPct);
  }

  Future<void> _restoreFromCalculation() async {
    setState(() => _restoring = true);
    try {
      final list = await _api.getProjectCalculations(widget.projectId!);
      ProjectCalculationItem? current;
      for (final item in list) {
        if (item.id == widget.calculationId) {
          current = item;
          break;
        }
      }
      if (current == null || !mounted) return;
      final currentCalc = current;
      final params = currentCalc.parameters;
      final physics = (params['physics_params'] as Map?)?.cast<String, dynamic>() ?? const {};
      final pv = (physics['pv'] as Map?)?.cast<String, dynamic>() ?? const {};
      final ess = (physics['ess'] as Map?)?.cast<String, dynamic>() ?? const {};
      final env = (physics['env'] as Map?)?.cast<String, dynamic>() ?? const {};
      final projectCost = (params['project_cost_settings'] as Map?)?.cast<String, dynamic>() ?? const {};
      final prefs = await SharedPreferences.getInstance();
      final globalPv = prefs.getDouble('pv_cost') ?? 800.0;
      final globalEss = prefs.getDouble('ess_cost') ?? 350.0;
      final globalMargin = prefs.getDouble('margin_pct') ?? 20.0;
      final useProjectCosts = _isProUser && (projectCost['independent'] == true);
      final restoredPv = (projectCost['pv_cost'] as num?)?.toDouble() ?? globalPv;
      final restoredEss = (projectCost['ess_cost'] as num?)?.toDouble() ?? globalEss;
      final restoredMargin = (projectCost['margin_pct'] as num?)?.toDouble() ?? globalMargin;

      setState(() {
        _versionName = currentCalc.versionName;
        _versionController.text = _versionName;
        _pvCapacity = (pv['pv_dc_capacity_kwp'] as num?)?.toDouble() ?? _pvCapacity;
        _batteryCapacity = (ess['batt_nominal_capacity_kwh'] as num?)?.toDouble() ?? _batteryCapacity;
        final load = (env['load_profile_8760'] as List?)?.cast<num>();
        _factoryPeakLoad = load == null || load.isEmpty ? _factoryPeakLoad : load.reduce((a, b) => a > b ? a : b).toDouble();
        _latestResult = currentCalc.results;
        _independentCosts = useProjectCosts;
        _isEditingIndependentCosts = false;
        _pvCostPerKw = restoredPv;
        _essCostPerKwh = restoredEss;
        _marginPct = restoredMargin;
      });
      _syncCostControllers();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to restore calculation: $e');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  List<double> _generateFactoryLoadProfile(double peakLoad) {
    return List.generate(8760, (index) {
      final hour = index % 24;
      if (hour >= 8 && hour < 18) {
        return peakLoad;
      }
      return peakLoad * 0.2;
    });
  }

  Map<String, dynamic> _buildPayload() {
    final baseCost = (_pvCapacity * _pvCostPerKw) + (_batteryCapacity * _essCostPerKwh) + 5000.0;
    final totalCapex = baseCost * (1 + (_marginPct / 100.0));
    return {
      "physics_params": {
        "env": {
          "lat": -23.5505,
          "lon": -46.6333,
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
        "tariff": {
          "peak_hours": [18, 19, 20, 21],
          "valley_hours": [0, 1, 2, 3, 4, 5],
          "peak_price": 0.35,
          "mid_price": 0.25,
          "valley_price": 0.12,
          "demand_charge_per_kw": 10.0,
        }
      },
      "financial_params": {
        "total_capex": totalCapex,
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
      "project_cost_settings": {
        "independent": _isProUser && _independentCosts,
        "pv_cost": _pvCostPerKw,
        "ess_cost": _essCostPerKwh,
        "margin_pct": _marginPct,
      },
    };
  }

  Future<void> _runSimulation() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final payload = _buildPayload();
      final response = await _api.dio.post('/simulate', data: payload);
      if (!mounted) return;
      setState(() {
        _latestResult = (response.data as Map).cast<String, dynamic>();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Simulation failed: ${e.response?.data ?? e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Simulation failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCalculation() async {
    if (widget.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please open this screen from a project.')),
      );
      return;
    }
    if (_latestResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run simulation before saving.')),
      );
      return;
    }
    final version = _versionName.trim().isEmpty
        ? 'V${DateTime.now().millisecondsSinceEpoch}'
        : _versionName.trim();
    await _api.createProjectCalculation(
      projectId: widget.projectId!,
      versionName: version,
      parameters: _buildPayload(),
      results: _latestResult!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculation saved.')),
    );
  }

  Future<void> _openPdfPreview() async {
    if (_latestResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run calculation before preview.')),
      );
      return;
    }
    final finance = (_latestResult?['finance_result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cashFlowData = (finance['cash_flow_statement'] as List? ?? const []).whereType<dynamic>().toList();
    final prefs = await SharedPreferences.getInstance();
    final tier = prefs.getString('user_tier') ?? 'FREE';
    final companyName = prefs.getString('company_name') ?? 'PV+ESS QUOTE MASTER';
    final logoUrl = prefs.getString('logo_url') ?? '';
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          isProUser: tier == 'PRO',
          companyName: companyName,
          logoUrl: logoUrl,
          pvCapacity: _pvCapacity,
          batteryCapacity: _batteryCapacity,
          totalCapex: (finance['total_capex'] as num?)?.toDouble() ?? 0.0,
          npv: (finance['npv'] as num?)?.toDouble() ?? 0.0,
          irr: (finance['irr'] as num?)?.toDouble() ?? 0.0,
          payback: (finance['payback_period_years'] as num?)?.toDouble() ?? 0.0,
          fullCashFlowData: cashFlowData,
        ),
      ),
    );
  }

  Future<bool> _runProGuard({required PaywallTriggerSource triggerSource}) async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = (prefs.getString('user_tier') ?? 'FREE') == 'PRO';
    if (isPro) {
      if (!_isProUser && mounted) {
        setState(() => _isProUser = true);
      }
      return true;
    }
    HapticFeedback.mediumImpact();
    await _showPaywall(triggerSource);
    return false;
  }

  Future<void> _showPaywall(PaywallTriggerSource triggerSource) async {
    final l10n = AppLocalizations.of(context)!;
    await showProPaywallSheet(
      context: context,
      triggerSource: triggerSource,
      ctaBaseText: l10n.unlockProBtn,
      isPurchasing: _isPurchasing,
      onPurchase: _purchasePro,
      debugTag: 'Calculation',
    );
  }

  Future<void> _purchasePro(BuildContext paywallContext, Package? selectedPackage) async {
    if (_isPurchasing) return;
    if (kIsWeb || !Platform.isAndroid) return;
    setState(() => _isPurchasing = true);
    try {
      await RevenueCatService.ensureInitialized();
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const <Package>[];
      if (packages.isEmpty) return;
      final packageToBuy = selectedPackage ?? packages.first;
      final purchaseResult = await Purchases.purchasePackage(packageToBuy);
      final isPro = purchaseResult.customerInfo.entitlements.all['pro']?.isActive == true;
      if (!isPro) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_tier', 'PRO');
      if (!mounted) return;
      setState(() => _isProUser = true);
      Navigator.pop(paywallContext);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  void dispose() {
    _versionController.dispose();
    _pvCostController.dispose();
    _essCostController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  void _syncCostControllers() {
    _pvCostController.text = _pvCostPerKw.toStringAsFixed(2);
    _essCostController.text = _essCostPerKwh.toStringAsFixed(2);
    _marginController.text = _marginPct.toStringAsFixed(2);
  }

  static const double _pvCostMin = 300.0;
  static const double _pvCostMax = 2000.0;
  static const double _essCostMin = 100.0;
  static const double _essCostMax = 1200.0;
  static const double _marginMin = 0.0;
  static const double _marginMax = 60.0;

  double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _showInputValidationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _applyCostInputChanges() async {
    final pv = double.tryParse(_pvCostController.text.trim());
    final ess = double.tryParse(_essCostController.text.trim());
    final margin = double.tryParse(_marginController.text.trim());
    if (pv == null || ess == null || margin == null) {
      _showInputValidationMessage('Please enter valid numbers for PV Cost, ESS Cost, and Margin.');
      _syncCostControllers();
      return;
    }
    final validatedPv = _clamp(pv, _pvCostMin, _pvCostMax);
    final validatedEss = _clamp(ess, _essCostMin, _essCostMax);
    final validatedMargin = _clamp(margin, _marginMin, _marginMax);
    final wasClamped = validatedPv != pv || validatedEss != ess || validatedMargin != margin;
    setState(() {
      _pvCostPerKw = validatedPv;
      _essCostPerKwh = validatedEss;
      _marginPct = validatedMargin;
    });
    _syncCostControllers();
    if (wasClamped) {
      _showInputValidationMessage(
        'Costs adjusted to valid ranges: PV $_pvCostMin-$_pvCostMax, ESS $_essCostMin-$_essCostMax, Margin $_marginMin-$_marginMax.',
      );
    }
    if (!_isProUser || !_independentCosts) {
      await _saveGlobalCosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = (_latestResult?['finance_result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cashFlowStatement = (finance['cash_flow_statement'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final cashFlows = cashFlowStatement
        .map((row) => (row['net_cash_flow'] as num?)?.toDouble() ?? 0.0)
        .toList();
    // Visual hierarchy optimization:
    // 1) Separate page into parameter card and result card.
    // 2) Use clear section title + semantic icons for quick scanning.
    // 3) Preserve all interactions while improving density and readability.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation'),
      ),
      body: _restoring
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                      child: Icon(
                                        Icons.tune_outlined,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    title: const Text(
                                      'Input Parameters',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      'Adjust capacities and load assumptions',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    decoration: const InputDecoration(labelText: 'Version Name'),
                                    controller: _versionController,
                                    onChanged: (v) => _versionName = v,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'PV Capacity: ${_pvCapacity.toStringAsFixed(0)} kWp',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Slider(
                                    value: _pvCapacity,
                                    min: 0,
                                    max: 200,
                                    divisions: 40,
                                    onChanged: (v) => setState(() => _pvCapacity = v),
                                  ),
                                  Text(
                                    'ESS Capacity: ${_batteryCapacity.toStringAsFixed(0)} kWh',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Slider(
                                    value: _batteryCapacity,
                                    min: 0,
                                    max: 200,
                                    divisions: 40,
                                    onChanged: (v) => setState(() => _batteryCapacity = v),
                                  ),
                                  Text(
                                    'Factory Peak Load: ${_factoryPeakLoad.toStringAsFixed(0)} kW',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Slider(
                                    value: _factoryPeakLoad,
                                    min: 10,
                                    max: 200,
                                    divisions: 38,
                                    onChanged: (v) => setState(() => _factoryPeakLoad = v),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Independent Costs',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ),
                                      if (_isProUser)
                                        TextButton.icon(
                                          onPressed: () async {
                                            if (_isEditingIndependentCosts) {
                                              await _applyCostInputChanges();
                                            }
                                            if (!mounted) return;
                                            setState(() => _isEditingIndependentCosts = !_isEditingIndependentCosts);
                                          },
                                          icon: Icon(_isEditingIndependentCosts ? Icons.check : Icons.edit_outlined, size: 18),
                                          label: Text(_isEditingIndependentCosts ? 'Done' : 'Edit'),
                                        )
                                      else
                                        IconButton(
                                          tooltip: 'Upgrade to edit',
                                          onPressed: () async {
                                            await _runProGuard(
                                              triggerSource: PaywallTriggerSource.customCost,
                                            );
                                          },
                                          icon: const Icon(Icons.workspace_premium, color: Colors.amber),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _pvCostController,
                                    enabled: _isProUser && _isEditingIndependentCosts,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'PV Cost (\$ / kW)',
                                      prefixIcon: Icon(Icons.solar_power_outlined),
                                    ),
                                    onEditingComplete: () async => _applyCostInputChanges(),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _essCostController,
                                    enabled: _isProUser && _isEditingIndependentCosts,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'ESS Cost (\$ / kWh)',
                                      prefixIcon: Icon(Icons.battery_charging_full_outlined),
                                    ),
                                    onEditingComplete: () async => _applyCostInputChanges(),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _marginController,
                                    enabled: _isProUser && _isEditingIndependentCosts,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Margin (%)',
                                      prefixIcon: Icon(Icons.percent_outlined),
                                    ),
                                    onEditingComplete: () async => _applyCostInputChanges(),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _loading ? null : _runSimulation,
                                          icon: const Icon(Icons.play_arrow_rounded),
                                          label: Text(_loading ? 'Calculating...' : 'Calculation'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _loading ? null : _saveCalculation,
                                          icon: const Icon(Icons.save_outlined),
                                          label: const Text('Save'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _loading ? null : _openPdfPreview,
                                      icon: const Icon(Icons.picture_as_pdf_outlined),
                                      label: const Text('PDF REVIEW'),
                                    ),
                                  ),
                                  if (_error.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _error,
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14),
                                      child: Icon(
                                        Icons.assessment_outlined,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    title: const Text(
                                      'Simulation Results',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      'Latest financial KPIs',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Card(
                                    elevation: 0,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'IRR: ${finance['irr'] ?? '-'}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'NPV: ${finance['npv'] ?? '-'}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Payback: ${finance['payback_period_years'] ?? '-'}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          if (cashFlows.isNotEmpty) ...[
                                            const SizedBox(height: 14),
                                            SizedBox(
                                              height: 160,
                                              child: BarChart(
                                                BarChartData(
                                                  alignment: BarChartAlignment.spaceAround,
                                                  gridData: FlGridData(
                                                    show: true,
                                                    drawVerticalLine: false,
                                                  ),
                                                  borderData: FlBorderData(show: false),
                                                  titlesData: FlTitlesData(
                                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                    bottomTitles: AxisTitles(
                                                      sideTitles: SideTitles(
                                                        showTitles: true,
                                                        reservedSize: 26,
                                                        getTitlesWidget: (value, meta) {
                                                          final idx = value.toInt();
                                                          if (idx < 0 || idx >= cashFlows.length) {
                                                            return const SizedBox.shrink();
                                                          }
                                                          if (idx % 2 != 0 && idx != cashFlows.length - 1) {
                                                            return const SizedBox.shrink();
                                                          }
                                                          return Text(
                                                            'Y${idx + 1}',
                                                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  barGroups: List.generate(cashFlows.length, (index) {
                                                    final y = cashFlows[index];
                                                    return BarChartGroupData(
                                                      x: index,
                                                      barRods: [
                                                        BarChartRodData(
                                                          toY: y,
                                                          width: 7,
                                                          borderRadius: BorderRadius.circular(4),
                                                          color: y >= 0 ? Colors.green : Colors.redAccent,
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
