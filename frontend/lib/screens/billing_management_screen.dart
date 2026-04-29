import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/billing/revenuecat_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class BillingManagementScreen extends StatefulWidget {
  const BillingManagementScreen({super.key});

  @override
  State<BillingManagementScreen> createState() => _BillingManagementScreenState();
}

class _BillingManagementScreenState extends State<BillingManagementScreen> {
  late Future<_BillingViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBillingData();
  }

  Future<_BillingViewData> _loadBillingData() async {
    await RevenueCatService.ensureInitialized();
    final customerInfo = await Purchases.getCustomerInfo();
    return _BillingViewData.fromCustomerInfo(customerInfo);
  }

  Future<void> _openManagementUrl(_BillingViewData data) async {
    final uri = data.managementUri;
    if (uri == null) {
      _showManageHint();
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _showManageHint();
      }
    } catch (_) {
      if (mounted) {
        _showManageHint();
      }
    }
  }

  void _showManageHint() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.billingManageDialogTitle),
        content: Text(l10n.billingManageDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy-MM-dd').format(dt.toLocal());
  }

  Widget _buildCurrentPlanCard(_BillingViewData data) {
    final l10n = AppLocalizations.of(context)!;
    final active = data.activeEntitlement;
    final isPro = active != null;
    final subtitle = isPro
        ? l10n.billingRenewExpireOn(_formatDate(active.expirationDate))
        : l10n.billingFreePlanHint;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPro ? AppColors.secondary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPro ? Icons.workspace_premium : Icons.person_outline,
                color: isPro ? AppColors.secondary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.billingCurrentPlanTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isPro ? l10n.billingProPlanName : l10n.billingFreePlanName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isPro ? AppColors.secondary : AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          if (!isPro) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
              ),
              child: Text(l10n.billingUpgradeCta),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManageCard(_BillingViewData data) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.billingManageTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.billingManageHint,
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openManagementUrl(data),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.billingManageButton),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(_BillingViewData data) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.billingHistoryTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          if (data.history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, color: AppColors.onSurfaceVariant),
                  SizedBox(height: 8),
                  Text(
                    l10n.billingHistoryEmpty,
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ...data.history.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.productId),
                subtitle: Text(
                  l10n.billingPurchaseExpire(
                    _formatDate(item.purchaseDate),
                    _formatDate(item.expirationDate),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Icon(
                  item.isActive ? Icons.check_circle : Icons.history_toggle_off,
                  color: item.isActive ? AppColors.success : AppColors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billingManagementTitle),
      ),
      body: FutureBuilder<_BillingViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                    const SizedBox(height: 10),
                    Text(
                      l10n.billingLoadFailed(snapshot.error.toString()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _future = _loadBillingData();
                        });
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _loadBillingData();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCurrentPlanCard(data),
                const SizedBox(height: 14),
                _buildManageCard(data),
                const SizedBox(height: 14),
                _buildHistoryCard(data),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BillingViewData {
  _BillingViewData({
    required this.activeEntitlement,
    required this.history,
    required this.managementUri,
  });

  final _BillingHistoryItem? activeEntitlement;
  final List<_BillingHistoryItem> history;
  final Uri? managementUri;

  factory _BillingViewData.fromCustomerInfo(CustomerInfo info) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    Uri? parseUri(dynamic value) {
      if (value == null) return null;
      if (value is Uri) return value;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return Uri.tryParse(raw);
    }

    final allItems = <String, _BillingHistoryItem>{};

    for (final entry in info.entitlements.all.entries) {
      final ent = entry.value;
      final key = ent.productIdentifier.isNotEmpty ? ent.productIdentifier : entry.key;
      allItems[key] = _BillingHistoryItem(
        productId: key,
        purchaseDate: parseDate(ent.latestPurchaseDate),
        expirationDate: parseDate(ent.expirationDate),
        isActive: ent.isActive,
      );
    }

    final purchaseDates = info.allPurchaseDates;
    final expireDates = info.allExpirationDates;
    for (final productId in info.allPurchasedProductIdentifiers) {
      allItems.putIfAbsent(
        productId,
        () => _BillingHistoryItem(
          productId: productId,
          purchaseDate: parseDate(purchaseDates[productId]),
          expirationDate: parseDate(expireDates[productId]),
          isActive: false,
        ),
      );
    }

    final history = allItems.values.toList()
      ..sort((a, b) {
        final aTime = a.purchaseDate?.millisecondsSinceEpoch ?? 0;
        final bTime = b.purchaseDate?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

    _BillingHistoryItem? active;
    for (final item in history) {
      if (item.isActive) {
        active = item;
        break;
      }
    }

    return _BillingViewData(
      activeEntitlement: active,
      history: history,
      managementUri: parseUri(info.managementURL),
    );
  }
}

class _BillingHistoryItem {
  const _BillingHistoryItem({
    required this.productId,
    required this.purchaseDate,
    required this.expirationDate,
    required this.isActive,
  });

  final String productId;
  final DateTime? purchaseDate;
  final DateTime? expirationDate;
  final bool isActive;
}
