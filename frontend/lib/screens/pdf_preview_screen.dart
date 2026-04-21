import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io' show Platform;
import '../l10n/app_localizations.dart'; // 👈 新增这行
import '../core/network/api_client.dart';
import '../core/billing/revenuecat_service.dart';
import '../theme/app_colors.dart';
import '../utils/pdf_export.dart';
import 'paddle_checkout_webview.dart';

class PdfPreviewScreen extends StatefulWidget {
  final bool isProUser;
  final String companyName;
  final String logoUrl;
  final double pvCapacity;
  final double batteryCapacity;
  final double totalCapex;
  final double npv;
  final double irr;
  final double payback;
  final List<dynamic> fullCashFlowData;

  const PdfPreviewScreen({
    super.key,
    required this.isProUser,
    required this.companyName,
    required this.logoUrl,
    required this.pvCapacity,
    required this.batteryCapacity,
    required this.totalCapex,
    required this.npv,
    required this.irr,
    required this.payback,
    required this.fullCashFlowData,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isUpgrading = false;
  bool _isPurchasing = false;
  late bool _isProUser;

  @override
  void initState() {
    super.initState();
    _isProUser = widget.isProUser;
  }

  String _currency(dynamic value) {
    final num amount = (value is num) ? value : 0;
    return '\$${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pdfPreviewTitle,
          style: const TextStyle(fontSize: 16, color: AppColors.onSurface),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isProUser ? () => _exportPdf() : _showExportOptions,
            icon: const Icon(Icons.download_rounded, color: AppColors.secondary),
            label: Text(l10n.exportProposal, style: const TextStyle(color: AppColors.secondary)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
        color: AppColors.background,
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.onSurface.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isProUser ? widget.companyName : 'EnerQuote System',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.pdfDate(DateTime.now().toString().split(' ')[0]),
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  const Divider(height: 24),
                  Text(
                    l10n.pdfProposalTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.pdfSystemConfig,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 10),
                  Text('${l10n.pdfPvArray}: ${widget.pvCapacity.toStringAsFixed(1)} kWp'),
                  Text('${l10n.pdfEssBattery}: ${widget.batteryCapacity.toStringAsFixed(1)} kWh'),
                  Text(l10n.pdfGridPolicy),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.pdfTotalCapex}: \$${widget.totalCapex.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 22),
                  if (_isProUser) ...[
                    Text(
                      l10n.pdfFinancialHighlights,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 8),
                    Text('${l10n.pdfNpv}: \$${widget.npv.toStringAsFixed(0)}'),
                    Text('${l10n.pdfIrr}: ${widget.irr.toStringAsFixed(1)}%'),
                    Text('${l10n.pdfPayback}: ${widget.payback.toStringAsFixed(1)} ${l10n.pdfYears}'),
                    const SizedBox(height: 16),
                    Text(
                      l10n.pdfCashFlowTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 8),
                    _buildCashFlowPreviewTable(l10n),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E0),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: (_isUpgrading || _isPurchasing) ? null : _showProPaywall,
                        child: const Text(
                          '🔒 Upgrade to PRO to unlock Payback Period & IRR analysis',
                          style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Estimated Year 1 Total Savings: \$9559.16'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    _isProUser ? l10n.pdfConfidential : 'Generated by EnerQuote',
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowPreviewTable(AppLocalizations l10n) {
    if (widget.fullCashFlowData.isEmpty) {
      return Text(
        '${l10n.pdfCashFlowTitle}: 0',
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surfaceMuted),
          columns: [
            DataColumn(label: Text(l10n.pdfCfYear)),
            DataColumn(label: Text(l10n.pdfCfEnergySavings)),
            DataColumn(label: Text(l10n.pdfCfBackupValue)),
            DataColumn(label: Text(l10n.pdfCfOmBattery)),
            DataColumn(label: Text(l10n.pdfCfDebtService)),
            DataColumn(label: Text(l10n.pdfCfNetCashFlow)),
            DataColumn(label: Text(l10n.pdfCfCumulative)),
          ],
          rows: widget.fullCashFlowData.map((row) {
            return DataRow(cells: [
              DataCell(Text('${row['year'] ?? '-'}')),
              DataCell(Text(_currency(row['energy_savings_revenue']))),
              DataCell(Text(_currency(row['backup_power_value']))),
              DataCell(Text('-${_currency(row['opex_and_replacement'])}')),
              DataCell(Text('-${_currency(row['debt_service'])}')),
              DataCell(Text(_currency(row['net_cash_flow']))),
              DataCell(Text(_currency(row['cumulative_cash_flow']))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showExportOptions() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: AppColors.onSurfaceVariant),
                  title: Text(l10n.pdfExportFreeOptionTitle),
                  subtitle: Text(l10n.pdfExportFreeOptionSubtitle),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _exportPdf();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.workspace_premium, color: AppColors.secondary),
                  title: Text(l10n.pdfExportProOptionTitle),
                  subtitle: Text(l10n.pdfExportProOptionSubtitle),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showProPaywall();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context)!;
    final bytes = await PdfExport.generateAndPrintProposal(
      l10n: l10n,
      companyName: widget.companyName,
      logoUrl: widget.logoUrl,
      isProUser: _isProUser,
      pvCapacity: widget.pvCapacity,
      batteryCapacity: widget.batteryCapacity,
      totalCapex: widget.totalCapex,
      npv: widget.npv,
      irr: widget.irr,
      payback: widget.payback,
      fullCashFlowData: widget.fullCashFlowData,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'PV_ESS_Proposal_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  void _showProPaywall() {
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
                    l10n.upgradeToProSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  _buildProFeatureRow(l10n.proFeatureLogo),
                  _buildProFeatureRow(l10n.proFeatureCost),
                  _buildProFeatureRow(l10n.proFeatureROI),
                  _buildProFeatureRow(l10n.proFeatureNoWatermark),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_isUpgrading || _isPurchasing)
                        ? null
                        : () => _startCheckoutFromPaywall(buildContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        : Text(
                            l10n.unlockProBtn,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
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

  Future<void> _startCheckoutFromPaywall(BuildContext bottomSheetContext) async {
    final l10n = AppLocalizations.of(context)!;
    if (!kIsWeb && Platform.isAndroid) {
      await _purchaseWithRevenueCatOnAndroid(bottomSheetContext);
      return;
    }
    if (!kIsWeb) {
      Navigator.pop(bottomSheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentError('This platform does not support checkout yet.')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.pop(bottomSheetContext);
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
        MaterialPageRoute(builder: (_) => PaddleCheckoutWebView(checkoutUrl: urlStr)),
      );
      if (!mounted || ptxn == null || ptxn.isEmpty) return;
      final newTier = await ApiClient().refreshUserTierWithRetry();
      if (!mounted) return;
      if (newTier == "PRO") {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_tier', 'PRO');
        setState(() {
          _isProUser = true;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newTier == "PRO" ? l10n.paymentSuccessPro : l10n.paymentPending),
          backgroundColor: newTier == "PRO" ? AppColors.success : Colors.orange,
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

  Future<void> _purchaseWithRevenueCatOnAndroid(BuildContext paywallContext) async {
    if (_isPurchasing) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isPurchasing = true;
    });
    try {
      await RevenueCatService.ensureInitialized();
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const <Package>[];
      if (packages.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Android subscription package is currently available.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final purchaseResult = await Purchases.purchasePackage(packages.first);
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
      if (!mounted) return;
      setState(() {
        _isProUser = true;
      });
      if (mounted) {
        Navigator.pop(paywallContext);
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
}