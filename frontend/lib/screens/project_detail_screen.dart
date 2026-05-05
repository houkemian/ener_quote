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
      setState(() => _calculations = list);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(project.projectName),
        actions: [
          IconButton(
            tooltip: 'New Calculation',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CalculationScreen(projectId: project.id),
                ),
              );
              if (!mounted) return;
              await _loadCalculations();
            },
            icon: const Icon(Icons.addchart),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client: ${project.clientName ?? '-'}'),
                    Text('Location: ${project.location ?? '-'}'),
                    Text('Created: ${project.createdAt.toLocal()}'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error))
                    : ListView.separated(
                        itemCount: _calculations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final calc = _calculations[index];
                          final roi = calc.results['irr'];
                          final lcoe = calc.results['lcoe'];
                          return ListTile(
                            title: Text(calc.versionName),
                            subtitle: Text('ROI: ${roi ?? '-'}  LCOE: ${lcoe ?? '-'}'),
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
