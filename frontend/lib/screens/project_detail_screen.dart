import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import 'calculation_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectItem project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  String _error = '';
  List<ProjectCalculationItem> _calculations = const [];

  @override
  void initState() {
    super.initState();
    _loadCalculations();
  }

  Future<void> _loadCalculations() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final list = await _api.getProjectCalculations(widget.project.id);
      if (!mounted) return;
      // Defensive dedupe: avoid accidental duplicate rows if API returns repeated ids.
      final seen = <String>{};
      final unique = <ProjectCalculationItem>[];
      for (final item in list) {
        if (seen.add(item.id)) {
          unique.add(item);
        }
      }
      setState(() => _calculations = unique);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load calculations: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final createdDate = project.createdAt;
    final createdShort =
        '${(createdDate.year % 100).toString().padLeft(2, '0')}-'
        '${createdDate.month.toString().padLeft(2, '0')}-'
        '${createdDate.day.toString().padLeft(2, '0')}';
    // Visual hierarchy optimization:
    // 1) Keep project summary in a prominent top card.
    // 2) Render each calculation version as carded list tile with semantic icon.
    // 3) Increase outer spacing and metadata readability.
    return Scaffold(
      appBar: AppBar(
        title: Text(project.projectName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'New Calculation',
              child: FilledButton.icon(
                icon: const Icon(Icons.addchart, size: 18),
                label: const Text('New Calculation'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CalculationScreen(projectId: project.id),
                    ),
                  );
                  if (!mounted) return;
                  await _loadCalculations();
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
                    contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.business_center_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: const Text(
                      'Project Overview',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        project.projectName,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Client: ${project.clientName ?? '-'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Location: ${project.location ?? '-'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Created: $createdShort', style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _calculations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final calc = _calculations[index];
                          final finance = (calc.results['finance_result'] as Map?)
                                  ?.cast<String, dynamic>() ??
                              const <String, dynamic>{};
                          final roi = finance['irr'];
                          final lcoe = finance['lcoe'];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14),
                                  child: Icon(
                                    Icons.analytics_outlined,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                title: Text(
                                  calc.versionName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'ROI: ${roi ?? '-'}  •  LCOE: ${lcoe ?? '-'}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CalculationScreen(
                                        projectId: project.id,
                                        calculationId: calc.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
