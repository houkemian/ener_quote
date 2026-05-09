import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
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

  double _pvCapacity = 60;
  double _batteryCapacity = 50;
  double _factoryPeakLoad = 80;
  double _pvBaseCost = 800.0;
  double _essBaseCost = 350.0;
  double _targetMargin = 20.0;
  double _peakPrice = 0.35;
  double _midPrice = 0.25;
  double _valleyPrice = 0.12;
  double _demandChargePerKw = 10.0;
  String _versionName = '';
  bool _loading = false;
  bool _restoring = false;
  bool _isProUser = false;
  bool _isEditingVersionCosts = false;
  String _error = '';
  Map<String, dynamic>? _latestResult;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _loadUserTier();
    if (widget.calculationId != null && widget.projectId != null) {
      _restoreFromCalculation();
    }
  }

  Future<void> _loadUserTier() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isProUser = (prefs.getString('user_tier') ?? 'FREE') == 'PRO';
      _peakPrice = prefs.getDouble('tariff_peak_price') ?? 0.35;
      _midPrice = prefs.getDouble('tariff_mid_price') ?? 0.25;
      _valleyPrice = prefs.getDouble('tariff_valley_price') ?? 0.12;
      _demandChargePerKw = prefs.getDouble('tariff_demand_charge_per_kw') ?? 10.0;
    });
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
      final tariff = (physics['tariff'] as Map?)?.cast<String, dynamic>() ?? const {};
      final projectCost = (params['project_cost_settings'] as Map?)?.cast<String, dynamic>() ?? const {};

      setState(() {
        _versionName = currentCalc.versionName;
        _versionController.text = _versionName;
        _pvCapacity = (pv['pv_dc_capacity_kwp'] as num?)?.toDouble() ?? _pvCapacity;
        _batteryCapacity = (ess['batt_nominal_capacity_kwh'] as num?)?.toDouble() ?? _batteryCapacity;
        final load = (env['load_profile_8760'] as List?)?.cast<num>();
        _factoryPeakLoad = load == null || load.isEmpty ? _factoryPeakLoad : load.reduce((a, b) => a > b ? a : b).toDouble();
        _pvBaseCost = (projectCost['pv_cost'] as num?)?.toDouble() ?? _pvBaseCost;
        _essBaseCost = (projectCost['ess_cost'] as num?)?.toDouble() ?? _essBaseCost;
        _targetMargin = (projectCost['margin_pct'] as num?)?.toDouble() ?? _targetMargin;
        _peakPrice = (tariff['peak_price'] as num?)?.toDouble() ?? _peakPrice;
        _midPrice = (tariff['mid_price'] as num?)?.toDouble() ?? _midPrice;
        _valleyPrice = (tariff['valley_price'] as num?)?.toDouble() ?? _valleyPrice;
        _demandChargePerKw = (tariff['demand_charge_per_kw'] as num?)?.toDouble() ?? _demandChargePerKw;
        _latestResult = currentCalc.results;
      });
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

  void _showProOnlyTariffHint() {
    if (_isProUser || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PRO only: tariff settings are read-only on Free plan.')),
    );
  }

  Map<String, dynamic> _buildPayload() {
    final baseCost = (_pvCapacity * _pvBaseCost) + (_batteryCapacity * _essBaseCost) + 5000.0;
    final totalCapex = baseCost * (1 + (_targetMargin / 100.0));
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
          "peak_price": _peakPrice,
          "mid_price": _midPrice,
          "valley_price": _valleyPrice,
          "demand_charge_per_kw": _demandChargePerKw,
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
        "loan_term_years": 10,
        "loan_interest_rate": 0.07,
        "discount_rate": 0.10,
        "project_lifespan": 20,
        "annual_cycles": 500,
      },
      "project_cost_settings": {
        "pv_cost": _pvBaseCost,
        "ess_cost": _essBaseCost,
        "margin_pct": _targetMargin,
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
      final response = await _api.dio
          .post(
            '/simulate',
            data: payload,
            options: Options(
              // /simulate may include external irradiance fetch; keep timeout
              // longer than ApiClient's global 10s default.
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
            ),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      final rawData = response.data;
      final result = rawData is Map
          ? rawData.cast<String, dynamic>()
          : <String, dynamic>{'raw_result': rawData};
      setState(() {
        _latestResult = result;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = 'Simulation timeout after 30s, please retry.');
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
    final payload = _buildPayload();
    try {
      if (widget.calculationId != null) {
        await _api.updateProjectCalculation(
          projectId: widget.projectId!,
          calculationId: widget.calculationId!,
          versionName: version,
          parameters: payload,
          results: _latestResult!,
        );
      } else {
        await _api.createProjectCalculation(
          projectId: widget.projectId!,
          versionName: version,
          parameters: payload,
          results: _latestResult!,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Version name already exists in this project.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${e.response?.data ?? e.message}')),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.calculationId != null ? 'Calculation updated.' : 'Calculation saved.')),
    );
  }

  Future<void> _openPdfPreview() async {
    if (_latestResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run calculation before preview.')),
      );
      return;
    }
    final financeMap = (_latestResult?['finance_result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final finance = FinanceResult.fromJson(financeMap);
    final cashFlowData = finance.cashFlowStatement;
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
          totalCapex: (_buildPayload()['financial_params']?['total_capex'] as num?)?.toDouble() ?? 0.0,
          npv: finance.projectNpv ?? 0.0,
          irr: finance.projectIrr ?? 0.0,
          payback: finance.projectPaybackYears ?? 0.0,
          fullCashFlowData: cashFlowData,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  String _formatPercent(double? value) {
    if (value == null) return '-';
    final normalized = value.abs() <= 1 ? value * 100 : value;
    return '${normalized.toStringAsFixed(1)}%';
  }

  String _formatYears(double? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(1)} yrs';
  }

  Map<String, String> _buildSimulationParamsDisplay() {
    final payload = _buildPayload();
    final physics =
        (payload['physics_params'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pv = (physics['pv'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ess = (physics['ess'] as Map?)?.cast<String, dynamic>() ?? const {};
    final grid = (physics['grid'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tariff = (physics['tariff'] as Map?)?.cast<String, dynamic>() ?? const {};
    final projectCost =
        (payload['project_cost_settings'] as Map?)?.cast<String, dynamic>() ?? const {};

    String fmtNum(dynamic v, {int fixed = 2}) {
      final n = (v as num?)?.toDouble();
      if (n == null) return '-';
      return n.toStringAsFixed(fixed);
    }

    return {
      'PV Capacity (kWp)': fmtNum(pv['pv_dc_capacity_kwp'], fixed: 0),
      'Inverter Capacity (kW)': fmtNum(pv['inverter_ac_capacity_kw']),
      'System Loss Factor': fmtNum(pv['system_loss_factor']),
      'ESS Capacity (kWh)': fmtNum(ess['batt_nominal_capacity_kwh'], fixed: 0),
      'DoD Limit': fmtNum(ess['dod_limit']),
      'Max Charge/Discharge (kW)': fmtNum(ess['max_charge_discharge_kw']),
      'Round Trip Efficiency': fmtNum(ess['rte_efficiency']),
      'Initial SOC': fmtNum(ess['initial_soc']),
      'Export Limit (kW)': fmtNum(grid['export_limit_kw']),
      'Peak Price (\$ / kWh)': fmtNum(tariff['peak_price'], fixed: 3),
      'Mid Price (\$ / kWh)': fmtNum(tariff['mid_price'], fixed: 3),
      'Valley Price (\$ / kWh)': fmtNum(tariff['valley_price'], fixed: 3),
      'Demand Charge (\$ / kW)': fmtNum(tariff['demand_charge_per_kw']),
      'PV Base Cost (\$ / kW)': fmtNum(projectCost['pv_cost']),
      'ESS Base Cost (\$ / kWh)': fmtNum(projectCost['ess_cost']),
      'Target Margin (%)': fmtNum(projectCost['margin_pct']),
    };
  }

  void _showSimulationParamsInfo() {
    final params = _buildSimulationParamsDisplay();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 20, color: Color(0xFF1F3B70)),
                  SizedBox(width: 8),
                  Text(
                    'Simulation Parameters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1F3B70).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: params.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.value,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricLine({
    required String label,
    required String value,
    required Color textColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.9),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildReturnCard({
    required String title,
    required String subtitle,
    required String irr,
    required String payback,
    required Color accentColor,
    required Color backgroundColor,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor.withValues(alpha: 0.14),
                    child: Icon(icon, color: accentColor, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: accentColor.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetricLine(label: 'IRR', value: irr, textColor: accentColor),
              const SizedBox(height: 6),
              _buildMetricLine(label: 'Payback', value: payback, textColor: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeMap = (_latestResult?['finance_result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final finance = FinanceResult.fromJson(financeMap);
    final cashFlows = finance.cashFlowStatement
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Version Cost Settings',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ),
                                      if (_isProUser)
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() => _isEditingVersionCosts = !_isEditingVersionCosts);
                                          },
                                          icon: Icon(
                                            _isEditingVersionCosts ? Icons.check : Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          label: Text(_isEditingVersionCosts ? 'Done' : 'Edit'),
                                        )
                                      else
                                        Text(
                                          'PRO only',
                                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    key: ValueKey('pv_base_${_pvBaseCost.toStringAsFixed(2)}'),
                                    initialValue: _pvBaseCost.toStringAsFixed(2),
                                    enabled: _isProUser && _isEditingVersionCosts,
                                    decoration: const InputDecoration(
                                      labelText: 'PV Base Cost (\$ / kW)',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                    ],
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null) setState(() => _pvBaseCost = parsed);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('ess_base_${_essBaseCost.toStringAsFixed(2)}'),
                                    initialValue: _essBaseCost.toStringAsFixed(2),
                                    enabled: _isProUser && _isEditingVersionCosts,
                                    decoration: const InputDecoration(
                                      labelText: 'ESS Base Cost (\$ / kWh)',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                    ],
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null) setState(() => _essBaseCost = parsed);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('margin_${_targetMargin.toStringAsFixed(2)}'),
                                    initialValue: _targetMargin.toStringAsFixed(2),
                                    enabled: _isProUser && _isEditingVersionCosts,
                                    decoration: const InputDecoration(
                                      labelText: 'Target Margin (%)',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                    ],
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null) setState(() => _targetMargin = parsed);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('peak_price_${_peakPrice.toStringAsFixed(3)}'),
                                    initialValue: _peakPrice.toStringAsFixed(3),
                                    enabled: _isProUser && _isEditingVersionCosts,
                                    readOnly: !_isProUser,
                                    decoration: const InputDecoration(
                                      labelText: 'Peak Price (\$ / kWh)',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                    ],
                                    onTap: !_isProUser ? _showProOnlyTariffHint : null,
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null) setState(() => _peakPrice = parsed);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('mid_price_${_midPrice.toStringAsFixed(3)}'),
                                    initialValue: _midPrice.toStringAsFixed(3),
                                    enabled: _isProUser && _isEditingVersionCosts,
                                    readOnly: !_isProUser,
                                    decoration: const InputDecoration(
                                      labelText: 'Mid Price (\$ / kWh)',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                    ],
                                    onTap: !_isProUser ? _showProOnlyTariffHint : null,
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null) setState(() => _midPrice = parsed);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('valley_price_${_valleyPrice.toStringAsFixed(3)}'),
                                    initialValue: _valleyPrice.toStringAsFixed(3),
                                    enabled: _isProUser && _isEditingVersionCosts,
                                    readOnly: !_isProUser,
                                    decoration: const InputDecoration(
                                      labelText: 'Valley Price (\$ / kWh)',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                    ],
                                    onTap: !_isProUser ? _showProOnlyTariffHint : null,
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null) setState(() => _valleyPrice = parsed);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('demand_charge_${_demandChargePerKw.toStringAsFixed(2)}'),
                                    initialValue: _demandChargePerKw.toStringAsFixed(2),
                                    enabled: _isProUser && _isEditingVersionCosts,
                                    readOnly: !_isProUser,
                                    decoration: const InputDecoration(
                                      labelText: 'Demand Charge (\$ / kW)',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                    ],
                                    onTap: !_isProUser ? _showProOnlyTariffHint : null,
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null) setState(() => _demandChargePerKw = parsed);
                                    },
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
                                          label: Text(widget.calculationId != null ? 'Update' : 'Save'),
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
                                    trailing: InkWell(
                                      onTap: _showSimulationParamsInfo,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Latest financial KPIs',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth > 720) {
                                        return _buildReturnCard(
                                          title: 'Project Returns',
                                          subtitle: 'Unlevered (Cash Purchase)',
                                          irr: _formatPercent(finance.projectIrr),
                                          payback: _formatYears(finance.projectPaybackYears),
                                          accentColor: const Color(0xFF1F3B70),
                                          backgroundColor: const Color(0xFFEFF3FB),
                                          icon: Icons.account_balance_wallet_outlined,
                                        );
                                      }
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildReturnCard(
                                            title: 'Project Returns',
                                            subtitle: 'Unlevered (Cash Purchase)',
                                            irr: _formatPercent(finance.projectIrr),
                                            payback: _formatYears(finance.projectPaybackYears),
                                            accentColor: const Color(0xFF1F3B70),
                                            backgroundColor: const Color(0xFFEFF3FB),
                                            icon: Icons.account_balance_wallet_outlined,
                                          ),
                                        ],
                                      );
                                    },
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
                  );
                },
              ),
            ),
    );
  }
}
