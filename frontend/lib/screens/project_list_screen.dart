import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  String _error = '';
  List<ProjectItem> _projects = const [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
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
    final locationController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Project Name *'),
              ),
              TextField(
                controller: clientController,
                decoration: const InputDecoration(labelText: 'Client Name'),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final projectName = nameController.text.trim();
                if (projectName.isEmpty) {
                  return;
                }
                await _api.createProject(
                  projectName: projectName,
                  clientName: clientController.text.trim().isEmpty ? null : clientController.text.trim(),
                  location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(context, true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    clientController.dispose();
    locationController.dispose();

    if (created == true) {
      await _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            onPressed: _createProjectDialog,
            icon: const Icon(Icons.add),
            tooltip: 'New Project',
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
                    itemCount: _projects.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _projects[index];
                      return ListTile(
                        title: Text(p.projectName),
                        subtitle: Text(
                          [
                            if ((p.clientName ?? '').isNotEmpty) p.clientName!,
                            if ((p.location ?? '').isNotEmpty) p.location!,
                          ].join(' • '),
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
                      );
                    },
                  ),
                ),
    );
  }
}
