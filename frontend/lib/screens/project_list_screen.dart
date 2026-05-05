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
                child: Column(
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
                          TextField(
                            controller: locationController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Location',
                              hintText: 'City / State / Address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
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
                            await _api.createProject(
                              projectName: projectName,
                              clientName: clientController.text.trim().isEmpty ? null : clientController.text.trim(),
                              location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context, true);
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create Project'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    // Visual hierarchy optimization:
    // 1) Add page-level spacing for better breathing room.
    // 2) Encapsulate each project row into a soft card.
    // 3) Promote project name, demote metadata with muted subtitle color.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _createProjectDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Project'),
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
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
}
