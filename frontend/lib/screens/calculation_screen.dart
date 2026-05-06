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
  String _versionName = '';
  bool _loading = false;
  bool _restoring = false;
  String _error = '';
  Map<String, dynamic>? _latestResult;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    if (widget.calculationId != null && widget.projectId != null) {
      _restoreFromCalculation();
    }
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

      setState(() {
        _versionName = currentCalc.versionName;
        _versionController.text = _versionName;
        _pvCapacity = (pv['pv_dc_capacity_kwp'] as num?)?.toDouble() ?? _pvCapacity;
        _batteryCapacity = (ess['batt_nominal_capacity_kwh'] as num?)?.toDouble() ?? _batteryCapacity;
        final load = (env['load_profile_8760'] as List?)?.cast<num>();
        _factoryPeakLoad = load == null || load.isEmpty ? _factoryPeakLoad : load.reduce((a, b) => a > b ? a : b).toDouble();
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

  Map<String, dynamic> _buildPayload() {
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
        "total_capex": (_pvCapacity * 1000) + (_batteryCapacity * 400),
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
  }

  Future<void> _runSimulation() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final payload = _buildPayload();
      final response = await _api.dio
          .post('/simulate', data: payload)
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
          totalCapex: (_buildPayload()['financial_params']?['total_capex'] as num?)?.toDouble() ?? 0.0,
          npv: (finance['project_npv'] as num?)?.toDouble() ?? (finance['npv'] as num?)?.toDouble() ?? 0.0,
          irr: (finance['project_irr'] as num?)?.toDouble() ?? (finance['irr'] as num?)?.toDouble() ?? 0.0,
          payback: (finance['project_payback_years'] as num?)?.toDouble() ??
              (finance['payback_period_years'] as num?)?.toDouble() ??
              0.0,
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
