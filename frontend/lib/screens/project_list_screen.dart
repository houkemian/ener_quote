import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import '../core/billing/revenuecat_purchase_helper.dart';
import '../core/billing/revenuecat_service.dart';
import '../core/network/api_client.dart';
import '../widgets/pro_paywall_sheet.dart';
import 'project_detail_screen.dart';
import 'settings_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  bool _purchasing = false;
  String _error = '';
  List<ProjectItem> _projects = const [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    _loadProjects();
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    final isPro = info.entitlements.all['pro']?.isActive == true;
    if (!isPro) return;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('user_tier', 'PRO'));
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final items = await _api.getProjects();
      if (!mounted) return;
      setState(() => _projects = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load projects: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createProjectDialog() async {
    final nameController = TextEditingController();
    final clientController = TextEditingController();

    final cities = await _api.getSupportedCities();
    if (!mounted) return;

    final localeCode = Localizations.localeOf(context).languageCode;
    String cityDisplayName(dynamic city) {
      final nameMap = (city['name'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      return (nameMap[localeCode] ?? nameMap['en'] ?? city['id'] ?? '').toString();
    }

    String? selectedCityId;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                              child: Icon(
                                Icons.work_outline,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Create New Project',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(context, false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use projects to group quote scenarios, compare versions, and keep a clear history.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Project Information',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: nameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Project Name *',
                                  hintText: 'e.g. Texas Walmart Rooftop',
                                  prefixIcon: Icon(Icons.folder_open_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: clientController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Client Name',
                                  hintText: 'Optional',
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: selectedCityId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                  hintText: 'Optional',
                                ),
                                items: cities.map<DropdownMenuItem<String>>((city) {
                                  return DropdownMenuItem<String>(
                                    value: (city['id'] ?? '').toString(),
                                    child: Text(
                                      cityDisplayName(city),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: cities.isEmpty
                                    ? null
                                    : (v) => setDialogState(() => selectedCityId = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '* Required field',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () async {
                                final projectName = nameController.text.trim();
                                if (projectName.isEmpty) {
                                  return;
                                }
                                String? locationArg;
                                if (selectedCityId != null) {
                                  for (final city in cities) {
                                    if ((city['id'] ?? '').toString() == selectedCityId) {
                                      locationArg = cityDisplayName(city);
                                      break;
                                    }
                                  }
                                }
                                try {
                                  await _api.createProject(
                                    projectName: projectName,
                                    clientName:
                                        clientController.text.trim().isEmpty ? null : clientController.text.trim(),
                                    location: locationArg,
                                  );
                                } on PaywallGateException {
                                  if (!context.mounted) return;
                                  Navigator.pop(context, false);
                                  await _showCapacityWallPaywall(PaywallTriggerSource.projectLimit);
                                  return;
                                }
                                if (!context.mounted) return;
                                Navigator.pop(context, true);
                              },
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Create Project'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    clientController.dispose();

    if (created == true) {
      await _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 8),
            const Text('EnerQuote'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Upgrade PRO',
            onPressed: () => _showCapacityWallPaywall(PaywallTriggerSource.general),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6, left: 4),
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _createProjectDialog,
              child: const Text(
                'New Project',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = _projects[index];
                      final metadata = [
                        if ((p.clientName ?? '').isNotEmpty) 'Client: ${p.clientName}',
                        if ((p.location ?? '').isNotEmpty) 'Location: ${p.location}',
                      ].join('  •  ');

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              child: Icon(
                                Icons.folder_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              p.projectName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                metadata.isEmpty ? 'No client or location provided' : metadata,
                                style: TextStyle(color: Colors.grey[600], height: 1.35),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProjectDetailScreen(project: p),
                                ),
                              );
                              if (!mounted) return;
                              await _loadProjects();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _showCapacityWallPaywall(PaywallTriggerSource source) async {
    HapticFeedback.mediumImpact();
    await showProPaywallSheet(
      context: context,
      triggerSource: source,
      ctaBaseText: 'Upgrade to Pro',
      isPurchasing: _purchasing,
      onPurchase: _purchaseProFromPaywall,
      debugTag: 'ProjectList',
    );
  }

  Future<void> _purchaseProFromPaywall(BuildContext bottomSheetContext, Package? selectedPackage) async {
    if (_purchasing) return;
    if (kIsWeb || !Platform.isAndroid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use Android app purchase flow to upgrade.')),
      );
      return;
    }
    setState(() => _purchasing = true);
    try {
      await RevenueCatService.ensureInitialized();
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const <Package>[];
      if (packages.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Android subscription package is currently available.')),
        );
        return;
      }
      final packageToBuy = selectedPackage ?? packages.first;
      final result = await RevenueCatPurchaseHelper.purchasePackage(packageToBuy);
      final isPro = result.customerInfo.entitlements.all['pro']?.isActive == true;
      if (!isPro) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_tier', 'PRO');
      if (mounted) Navigator.pop(bottomSheetContext);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }
}
