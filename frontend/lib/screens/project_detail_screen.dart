import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late ProjectItem _project;
  bool _loading = true;
  String _error = '';
  List<ProjectCalculationItem> _calculations = const [];
  String? _openedCalcId;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _loadCalculations();
  }

  Future<void> _editProjectInfo() async {
    final nameController = TextEditingController(text: _project.projectName);
    final clientController = TextEditingController(text: _project.clientName ?? '');
    try {
      final cities = await _api.getSupportedCities();
      final localeCode = Localizations.localeOf(context).languageCode;
      String cityDisplayName(dynamic city) {
        final nameMap = (city['name'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        return (nameMap[localeCode] ?? nameMap['en'] ?? city['id'] ?? '').toString();
      }

      String? selectedCityId;
      final normalizedLocation = (_project.location ?? '').trim();
      if (normalizedLocation.isNotEmpty) {
        for (final city in cities) {
          final id = (city['id'] ?? '').toString();
          if (id == normalizedLocation || cityDisplayName(city) == normalizedLocation) {
            selectedCityId = id;
            break;
          }
        }
      }

      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit Project'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Project Name *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: clientController,
                      decoration: const InputDecoration(labelText: 'Client Name'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedCityId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Location (from cities)'),
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
                      onChanged: (v) => setDialogState(() => selectedCityId = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;
      final projectName = nameController.text.trim();
      if (projectName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project name cannot be empty.')),
        );
        return;
      }
      String? selectedLocation;
      if (selectedCityId != null) {
        for (final city in cities) {
          if ((city['id'] ?? '').toString() == selectedCityId) {
            selectedLocation = cityDisplayName(city);
            break;
          }
        }
      }
      final updated = await _api.updateProject(
        projectId: _project.id,
        projectName: projectName,
        clientName: clientController.text.trim(),
        location: selectedLocation,
      );
      if (!mounted) return;
      setState(() => _project = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
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

  Future<bool> _confirmDelete(ProjectCalculationItem calc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete calculation?'),
          content: Text('Delete "${calc.versionName}" permanently? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  Future<void> _deleteCalculation(ProjectCalculationItem calc) async {
    final confirmed = await _confirmDelete(calc);
    if (!confirmed) return;

    setState(() {
      _calculations = _calculations.where((e) => e.id != calc.id).toList();
    });
    try {
      await _api.deleteProjectCalculation(
        projectId: widget.project.id,
        calculationId: calc.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${calc.versionName}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
      await _loadCalculations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
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
                    trailing: IconButton(
                      tooltip: 'Edit project',
                      onPressed: _editProjectInfo,
                      icon: const Icon(Icons.edit_outlined, size: 20),
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
                        Text(
                          'Client: ${project.clientName ?? '-'}  •  Location: ${project.location ?? '-'}  •  Created: $createdShort',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
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
                          final isOpen = _openedCalcId == calc.id;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () async => _deleteCalculation(calc),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    label: const Text('Delete'),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  final velocity = details.primaryVelocity ?? 0;
                                  if (velocity < -120) {
                                    setState(() => _openedCalcId = calc.id);
                                  } else if (velocity > 120) {
                                    setState(() => _openedCalcId = null);
                                  }
                                },
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  offset: isOpen ? const Offset(-0.24, 0) : Offset.zero,
                                  child: Card(
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
                                        trailing: Icon(isOpen ? Icons.keyboard_arrow_left : Icons.chevron_right),
                                        onTap: () {
                                          if (isOpen) {
                                            setState(() => _openedCalcId = null);
                                            return;
                                          }
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
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
