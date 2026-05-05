import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/billing/revenuecat_service.dart';
import '../theme/app_colors.dart';

class PaywallFeatureItem {
  final String title;
  final String description;
  const PaywallFeatureItem({required this.title, required this.description});
}

enum PaywallTriggerSource {
  projectLimit,
  exportPdf,
  customCost,
  general,
}

class _PaywallHeaderText {
  final String title;
  final String subtitle;
  const _PaywallHeaderText({required this.title, required this.subtitle});
}

_PaywallHeaderText _headerBySource(PaywallTriggerSource source) {
  switch (source) {
    case PaywallTriggerSource.projectLimit:
      return const _PaywallHeaderText(
        title: 'Pipeline Full. Time to Scale.',
        subtitle: "You've reached the 2-project free limit. Upgrade to save unlimited client quotes.",
      );
    case PaywallTriggerSource.exportPdf:
      return const _PaywallHeaderText(
        title: 'Win the Deal with Branded PDFs',
        subtitle: 'Stop sending screenshots. Export professional quotes with your company logo.',
      );
    case PaywallTriggerSource.customCost:
      return const _PaywallHeaderText(
        title: 'Need Custom Costs for This Deal?',
        subtitle: 'Unlock independent hardware and labor cost profiles for individual projects.',
      );
    case PaywallTriggerSource.general:
      return const _PaywallHeaderText(
        title: 'Unlock the Ultimate Sales Toolkit',
        subtitle: 'Manage unlimited projects, export branded proposals, and customize costs per deal.',
      );
  }
}

Future<void> showProPaywallSheet({
  required BuildContext context,
  PaywallTriggerSource triggerSource = PaywallTriggerSource.general,
  required String ctaBaseText,
  required bool isPurchasing,
  required Future<void> Function(BuildContext bottomSheetContext, Package? selectedPackage) onPurchase,
  List<PaywallFeatureItem> featureRows = const [
    PaywallFeatureItem(
      title: 'Unlimited Project Pipeline',
      description: 'Bypass the 2-project limit and save all client data.',
    ),
    PaywallFeatureItem(
      title: 'Branded PDF Proposals',
      description: 'Export professional quotes with your company logo.',
    ),
    PaywallFeatureItem(
      title: 'Project-Specific Cost Profiles',
      description: 'Set independent costs for individual projects.',
    ),
    PaywallFeatureItem(
      title: 'Advanced ROI & ESS Analytics',
      description: 'Full access to complex storage and financial models.',
    ),
  ],
  String annualBadge = 'SAVE 20%',
  String debugTag = 'Shared',
}) async {
  final header = _headerBySource(triggerSource);
  await RevenueCatService.ensureInitialized();
  Package? selectedPackage;

  Package? byType(List<Package> packages, PackageType type) {
    for (final p in packages) {
      if (p.packageType == type) return p;
    }
    return null;
  }

  Package? byIdentifierKeywords(List<Package> packages, List<String> keywords) {
    for (final p in packages) {
      final id = p.identifier.toLowerCase();
      final storeId = p.storeProduct.identifier.toLowerCase();
      final productTitle = p.storeProduct.title.toLowerCase();
      final matched = keywords.any((k) => id.contains(k) || storeId.contains(k) || productTitle.contains(k));
      if (matched) return p;
    }
    return null;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (bottomSheetContext) {
      return FutureBuilder<Offerings>(
        future: Purchases.getOfferings(),
        builder: (context, snapshot) {
          final packages = snapshot.data?.current?.availablePackages ?? const <Package>[];
          if (kDebugMode && snapshot.data != null) {
            debugPrint('[Paywall][$debugTag] offering=${snapshot.data!.current?.identifier} packageCount=${packages.length}');
            for (final p in packages) {
              debugPrint(
                '[Paywall][$debugTag] id=${p.identifier} type=${p.packageType.name} '
                'storeId=${p.storeProduct.identifier} price=${p.storeProduct.priceString}',
              );
            }
          }

          final annual = byType(packages, PackageType.annual) ?? byIdentifierKeywords(packages, const ['annual', 'year', 'yearly']);
          final monthly = byType(packages, PackageType.monthly) ?? byIdentifierKeywords(packages, const ['month', 'monthly']);
          selectedPackage ??= annual ?? monthly;

          return SafeArea(
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  Widget buildPackageCard({
                    required Package pkg,
                    required bool selected,
                    required String planTitle,
                    String? badge,
                    String? subline,
                  }) {
                    return InkWell(
                      onTap: () => setModalState(() => selectedPackage = pkg),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? const Color(0xFF1F6FEB) : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    planTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface),
                                  ),
                                ),
                                if (badge != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F6FEB),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      badge,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              pkg.storeProduct.priceString,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (subline != null) ...[
                              const SizedBox(height: 4),
                              Text(subline, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  final annualMonthlyEquivalent = annual != null ? annual.storeProduct.price / 12.0 : null;
                  final annualEquivalentText = annualMonthlyEquivalent == null
                      ? null
                      : '\$${annualMonthlyEquivalent.toStringAsFixed(2)} / mo, billed annually';

                  String? ctaPriceSuffix;
                  String? ctaText;
                  if (selectedPackage != null) {
                    final isAnnualSelected = annual != null && selectedPackage!.identifier == annual.identifier;
                    final selectedPriceText = selectedPackage!.storeProduct.priceString;
                    if (selectedPriceText.isNotEmpty) {
                      ctaText = isAnnualSelected
                          ? 'Subscribe for $selectedPriceText/yr'
                          : 'Subscribe for $selectedPriceText/mo';
                    } else {
                      ctaPriceSuffix = isAnnualSelected && annualMonthlyEquivalent != null
                          ? '(\$${annualMonthlyEquivalent.toStringAsFixed(2)}/mo)'
                          : null;
                    }
                  }

                  ctaText ??= ctaPriceSuffix == null ? ctaBaseText : '$ctaBaseText $ctaPriceSuffix';

                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.workspace_premium, size: 28, color: AppColors.secondary),
                        const SizedBox(height: 8),
                        Text(
                          header.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: 0.2,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          header.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        if (annual != null && monthly != null) ...[
                          buildPackageCard(
                            pkg: annual,
                            selected: selectedPackage?.identifier == annual.identifier,
                            planTitle: 'Annual Plan',
                            badge: annualBadge,
                            subline: annualEquivalentText,
                          ),
                          const SizedBox(height: 10),
                          buildPackageCard(
                            pkg: monthly,
                            selected: selectedPackage?.identifier == monthly.identifier,
                            planTitle: 'Monthly Plan',
                          ),
                          const SizedBox(height: 16),
                        ],
                        for (final feature in featureRows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        feature.title,
                                        style: const TextStyle(
                                          color: AppColors.onSurface,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        feature.description,
                                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (featureRows.isNotEmpty) const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: isPurchasing ? null : () => onPurchase(bottomSheetContext, selectedPackage),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.onSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: isPurchasing
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
                                  ctaText,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    },
  );
}
