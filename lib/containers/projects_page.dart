import 'dart:convert';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/servers/server_providers.dart';

import 'deployment_project_models.dart';
import 'project_repository.dart';

/// Catalog of managed deployment projects. Each project is a portable
/// collection of resources (servers, stacks, services, etc.).
@RoutePage()
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  DeploymentResourceKind? _kindFilter;
  _ProjectSort _sort = _ProjectSort.updatedDesc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final draft = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => const _ProjectEditorDialog(),
    );
    if (draft == null) return;
    final id = await ref
        .read(projectRepositoryProvider)
        .createProject(name: draft.name, description: draft.description);
    if (!mounted) return;
    context.router.push(ProjectDetailRoute(projectId: id));
  }

  Future<void> _edit(DeploymentProject project) async {
    final draft = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => _ProjectEditorDialog(
        title: 'Edit project',
        initialName: project.name,
        initialDescription: project.description,
        confirmLabel: 'Save',
      ),
    );
    if (draft == null) return;
    await ref
        .read(projectRepositoryProvider)
        .updateProject(
          projectId: project.id,
          name: draft.name,
          description: draft.description,
        );
  }

  Future<void> _delete(DeploymentProject project, int resourceCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          resourceCount == 0
              ? 'Delete “${project.name}”? This cannot be undone.'
              : 'Delete “${project.name}” and its $resourceCount resource'
                    '${resourceCount == 1 ? '' : 's'}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(projectRepositoryProvider).deleteProject(project.id);
  }

  Future<void> _export() async {
    try {
      final source = await ref.read(projectRepositoryProvider).exportToml();
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export deployment catalog',
        fileName: 'maidkit-projects.toml',
        type: FileType.custom,
        allowedExtensions: const ['toml'],
        bytes: utf8.encode(source),
      );
      if (path != null && mounted) {
        showStyledSnackBar(
          message: 'Catalog exported.',
          title: 'Export complete',
          icon: Symbols.check_circle,
        );
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: '$error',
          title: 'Could not export catalog',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['toml'],
      );
      final path = result?.files.singleOrNull?.path;
      if (path == null) return;
      final count = await ref
          .read(projectRepositoryProvider)
          .importToml(await File(path).readAsString());
      if (mounted) {
        showStyledSnackBar(
          message: count == 1
              ? 'Imported 1 project.'
              : 'Imported $count projects.',
          title: 'Import complete',
          icon: Symbols.check_circle,
        );
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: '$error',
          title: 'Could not import catalog',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  List<DeploymentProject> _filterSort(
    List<DeploymentProject> projects,
    List<DeploymentResource> resources,
  ) {
    final query = _query.trim().toLowerCase();
    var items = projects.where((project) {
      final projectResources = resources
          .where((r) => r.projectId == project.id)
          .toList();
      if (_kindFilter != null) {
        final hasKind = projectResources.any(
          (r) => deploymentResourceKindFromId(r.kind) == _kindFilter,
        );
        if (!hasKind) return false;
      }
      if (query.isEmpty) return true;
      if (project.name.toLowerCase().contains(query)) return true;
      if ((project.description ?? '').toLowerCase().contains(query)) {
        return true;
      }
      return projectResources.any(
        (r) => r.name.toLowerCase().contains(query) || r.kind.contains(query),
      );
    }).toList();

    int compare(DeploymentProject a, DeploymentProject b) {
      return switch (_sort) {
        _ProjectSort.nameAsc => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _ProjectSort.nameDesc => b.name.toLowerCase().compareTo(
          a.name.toLowerCase(),
        ),
        _ProjectSort.updatedDesc => b.updatedAt.compareTo(a.updatedAt),
        _ProjectSort.updatedAsc => a.updatedAt.compareTo(b.updatedAt),
        _ProjectSort.resourceCountDesc =>
          resources
              .where((r) => r.projectId == b.id)
              .length
              .compareTo(resources.where((r) => r.projectId == a.id).length),
      };
    }

    items.sort(compare);
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(deploymentProjectsProvider);
    final resources = ref.watch(deploymentResourcesProvider);
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final theme = Theme.of(context);
    final serverNames = {for (final s in servers) s.id: s.name};

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load projects: $error')),
        data: (items) {
          final allResources =
              resources.asData?.value ?? const <DeploymentResource>[];
          final filtered = _filterSort(items, allResources);
          final presentKinds = <DeploymentResourceKind>{
            for (final r in allResources) deploymentResourceKindFromId(r.kind),
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deployment projects',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items.isEmpty
                                ? 'Collections of servers, stacks, and services'
                                : '${items.length} project${items.length == 1 ? '' : 's'} · ${allResources.length} resource${allResources.length == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Import or export TOML catalog',
                      onSelected: (value) =>
                          value == 'import' ? _import() : _export(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'import',
                          child: Text('Import TOML catalog'),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: Text('Export TOML catalog'),
                        ),
                      ],
                      icon: const Icon(Symbols.import_export),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Symbols.add, size: 18),
                      label: const Text('New project'),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search projects and resources',
                            prefixIcon: const Icon(Symbols.search, size: 20),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear',
                                    icon: const Icon(Symbols.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PopupMenuButton<_ProjectSort>(
                        tooltip: 'Sort projects',
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _ProjectSort.updatedDesc,
                            child: Text('Recently updated'),
                          ),
                          PopupMenuItem(
                            value: _ProjectSort.updatedAsc,
                            child: Text('Least recently updated'),
                          ),
                          PopupMenuItem(
                            value: _ProjectSort.nameAsc,
                            child: Text('Name A–Z'),
                          ),
                          PopupMenuItem(
                            value: _ProjectSort.nameDesc,
                            child: Text('Name Z–A'),
                          ),
                          PopupMenuItem(
                            value: _ProjectSort.resourceCountDesc,
                            child: Text('Most resources'),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.sort,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _sort.label,
                                style: theme.textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (presentKinds.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _kindFilter == null,
                          onSelected: (_) => setState(() => _kindFilter = null),
                        ),
                        const SizedBox(width: 8),
                        for (final kind in DeploymentResourceKind.values)
                          if (presentKinds.contains(kind)) ...[
                            FilterChip(
                              avatar: Icon(
                                deploymentResourceKindIcon(kind),
                                size: 16,
                              ),
                              label: Text(deploymentResourceKindLabel(kind)),
                              selected: _kindFilter == kind,
                              onSelected: (selected) => setState(
                                () => _kindFilter = selected ? kind : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                      ],
                    ),
                  ),
              ],
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(onCreate: _create, onImport: _import)
                    : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.search_off,
                              size: 36,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No projects match',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try a different search or clear filters.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _kindFilter = null;
                                });
                              },
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 380,
                              mainAxisExtent: 188,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final project = filtered[index];
                          final projectResources = allResources
                              .where((r) => r.projectId == project.id)
                              .toList();
                          return ContextMenuWidget(
                            menuProvider: (_) => Menu(
                              children: [
                                MenuAction(
                                  title: 'Open',
                                  callback: () => context.router.push(
                                    ProjectDetailRoute(projectId: project.id),
                                  ),
                                ),
                                MenuAction(
                                  title: 'Edit',
                                  callback: () => _edit(project),
                                ),
                                MenuSeparator(),
                                MenuAction(
                                  title: 'Delete',
                                  attributes: const MenuActionAttributes(
                                    destructive: true,
                                  ),
                                  callback: () =>
                                      _delete(project, projectResources.length),
                                ),
                              ],
                            ),
                            child: _ProjectCard(
                              project: project,
                              resources: projectResources,
                              serverNames: serverNames,
                              onOpen: () => context.router.push(
                                ProjectDetailRoute(projectId: project.id),
                              ),
                              onEdit: () => _edit(project),
                              onDelete: () =>
                                  _delete(project, projectResources.length),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _ProjectSort {
  updatedDesc,
  updatedAsc,
  nameAsc,
  nameDesc,
  resourceCountDesc,
}

extension on _ProjectSort {
  String get label => switch (this) {
    _ProjectSort.updatedDesc => 'Updated',
    _ProjectSort.updatedAsc => 'Oldest',
    _ProjectSort.nameAsc => 'Name A–Z',
    _ProjectSort.nameDesc => 'Name Z–A',
    _ProjectSort.resourceCountDesc => 'Resources',
  };
}

class _ProjectDraft {
  const _ProjectDraft({required this.name, this.description});
  final String name;
  final String? description;
}

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({
    this.title = 'New deployment project',
    this.initialName = '',
    this.initialDescription,
    this.confirmLabel = 'Create',
  });

  final String title;
  final String initialName;
  final String? initialDescription;
  final String confirmLabel;

  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final description = _descriptionController.text.trim();
    Navigator.pop(
      context,
      _ProjectDraft(
        name: name,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Project name',
              helperText: 'A collection of related deployment resources.',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
    ],
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.resources,
    required this.serverNames,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final DeploymentProject project;
  final List<DeploymentResource> resources;
  final Map<int, String> serverNames;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final kindCounts = <DeploymentResourceKind, int>{};
    for (final resource in resources) {
      final kind = deploymentResourceKindFromId(resource.kind);
      kindCounts[kind] = (kindCounts[kind] ?? 0) + 1;
    }
    final orderedKinds = kindCounts.keys.toList()
      ..sort((a, b) => kindCounts[b]!.compareTo(kindCounts[a]!));
    final serverIds = {
      for (final r in resources)
        if (r.serverId != null) r.serverId!,
    };
    final serverLabel = serverIds.isEmpty
        ? null
        : serverIds.length == 1
        ? serverNames[serverIds.first] ?? '1 server'
        : '${serverIds.length} servers';

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.deployed_code, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Project actions',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    icon: Icon(
                      Symbols.more_vert,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (project.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              if (resources.isEmpty)
                Text(
                  'Empty collection — add resources',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final kind in orderedKinds.take(4))
                      _KindChip(
                        icon: deploymentResourceKindIcon(kind),
                        label:
                            '${deploymentResourceKindLabel(kind)}${kindCounts[kind]! > 1 ? ' ×${kindCounts[kind]}' : ''}',
                      ),
                    if (orderedKinds.length > 4)
                      _KindChip(
                        icon: Symbols.more_horiz,
                        label: '+${orderedKinds.length - 4}',
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    resources.isEmpty
                        ? '0 resources'
                        : '${resources.length} resource${resources.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (serverLabel != null) ...[
                    Text(
                      ' · ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(Symbols.dns, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        serverLabel,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Symbols.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate, required this.onImport});
  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.deployed_code,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No managed projects yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'A project is a portable collection of resources — servers, '
              'Compose stacks, folders, services, and more.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Symbols.add, size: 18),
                  label: const Text('New project'),
                ),
                OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Symbols.upload, size: 18),
                  label: const Text('Import TOML'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
