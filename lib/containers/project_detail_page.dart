import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/servers/server_connection_actions.dart';
import 'package:maid_kit/servers/server_models.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/cloud_file_picker.dart';
import 'container_models.dart';
import 'container_list_tile.dart';
import 'compose_project_actions.dart';
import 'deployment_project_models.dart';
import 'project_repository.dart';

/// Detail view for a stored deployment project — a collection of resources.
/// [linkId] remains for links opened from the server container view.
@RoutePage()
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, this.projectId, this.linkId});

  final int? projectId;
  final int? linkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(deploymentProjectsProvider);
    final resources = ref.watch(deploymentResourcesProvider);
    return projects.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Could not load project: $error'))),
      data: (allProjects) {
        final allResources =
            resources.asData?.value ?? const <DeploymentResource>[];
        final resolvedId =
            projectId ?? _projectForComposeLink(allResources, linkId);
        final project = allProjects
            .where((item) => item.id == resolvedId)
            .firstOrNull;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('This managed project is no longer available.'),
            ),
          );
        }
        return _ProjectDetail(
          project: project,
          resources: allResources
              .where((item) => item.projectId == project.id)
              .toList(),
        );
      },
    );
  }
}

int? _projectForComposeLink(List<DeploymentResource> resources, int? linkId) {
  if (linkId == null) return null;
  for (final resource in resources) {
    final config = _configuration(resource.configuration);
    if (config['compose_link_id'] == linkId) return resource.projectId;
  }
  return null;
}

class _ProjectDetail extends ConsumerStatefulWidget {
  const _ProjectDetail({required this.project, required this.resources});
  final DeploymentProject project;
  final List<DeploymentResource> resources;

  @override
  ConsumerState<_ProjectDetail> createState() => _ProjectDetailState();
}

class _ProjectDetailState extends ConsumerState<_ProjectDetail> {
  DeploymentResourceKind? _kindFilter;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addResource(List<Server> servers) async {
    final draft = await showModalBottomSheet<_ResourceDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => _LinkResourceSheet(servers: servers),
    );
    if (draft == null) return;
    await ref
        .read(projectRepositoryProvider)
        .addResource(
          projectId: widget.project.id,
          kind: draft.kind.name,
          name: draft.name,
          serverId: draft.serverId,
          configuration: draft.configuration,
        );
    if (mounted) {
      showStyledSnackBar(
        message: '“${draft.name}” added to the project.',
        title: 'Resource added',
        icon: Symbols.check_circle,
      );
    }
  }

  Future<void> _editProject() async {
    final draft = await showDialog<_ProjectEditDraft>(
      context: context,
      builder: (context) => _ProjectEditDialog(
        initialName: widget.project.name,
        initialDescription: widget.project.description,
      ),
    );
    if (draft == null) return;
    await ref
        .read(projectRepositoryProvider)
        .updateProject(
          projectId: widget.project.id,
          name: draft.name,
          description: draft.description,
        );
  }

  Future<void> _deleteProject() async {
    final count = widget.resources.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          count == 0
              ? 'Delete “${widget.project.name}”? This cannot be undone.'
              : 'Delete “${widget.project.name}” and its $count resource'
                    '${count == 1 ? '' : 's'}? This cannot be undone.',
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
    await ref.read(projectRepositoryProvider).deleteProject(widget.project.id);
    if (mounted) context.router.maybePop();
  }

  Future<void> _deleteResource(DeploymentResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove resource?'),
        content: Text(
          'Remove “${resource.name}” from this project? '
          'Remote infrastructure is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(projectRepositoryProvider).deleteResource(resource.id);
  }

  List<DeploymentResource> get _filteredResources {
    final query = _query.trim().toLowerCase();
    return widget.resources.where((resource) {
      final kind = deploymentResourceKindFromId(resource.kind);
      if (_kindFilter != null && kind != _kindFilter) return false;
      if (query.isEmpty) return true;
      if (resource.name.toLowerCase().contains(query)) return true;
      if (resource.kind.toLowerCase().contains(query)) return true;
      final config = resource.configuration.toLowerCase();
      return config.contains(query);
    }).toList();
  }

  Map<DeploymentResourceKind, List<DeploymentResource>> get _grouped {
    final map = <DeploymentResourceKind, List<DeploymentResource>>{};
    for (final resource in _filteredResources) {
      final kind = deploymentResourceKindFromId(resource.kind);
      map.putIfAbsent(kind, () => []).add(resource);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final serverNames = {for (final server in servers) server.id: server.name};
    final serverById = {for (final server in servers) server.id: server};
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kindCounts = <DeploymentResourceKind, int>{};
    for (final resource in widget.resources) {
      final kind = deploymentResourceKindFromId(resource.kind);
      kindCounts[kind] = (kindCounts[kind] ?? 0) + 1;
    }
    final serverIds = {
      for (final r in widget.resources)
        if (r.serverId != null) r.serverId!,
    };
    final grouped = _grouped;
    final orderedKinds = DeploymentResourceKind.values
        .where((kind) => grouped.containsKey(kind))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            tooltip: 'Edit project',
            icon: const Icon(Symbols.edit),
            onPressed: _editProject,
          ),
          IconButton(
            tooltip: 'Delete project',
            icon: const Icon(Symbols.delete),
            onPressed: _deleteProject,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _addResource(servers),
              icon: const Icon(Symbols.add, size: 18),
              label: const Text('Add resource'),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.project.description?.isNotEmpty ?? false) ...[
                    Text(
                      widget.project.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryPill(
                        icon: Symbols.inventory_2,
                        label:
                            '${widget.resources.length} resource'
                            '${widget.resources.length == 1 ? '' : 's'}',
                      ),
                      if (serverIds.isNotEmpty)
                        _SummaryPill(
                          icon: Symbols.dns,
                          label: serverIds.length == 1
                              ? (serverNames[serverIds.first] ?? '1 server')
                              : '${serverIds.length} servers',
                        ),
                      for (final entry in kindCounts.entries)
                        _SummaryPill(
                          icon: deploymentResourceKindIcon(entry.key),
                          label:
                              '${deploymentResourceKindLabel(entry.key)}'
                              '${entry.value > 1 ? ' ×${entry.value}' : ''}',
                        ),
                    ],
                  ),
                  if (widget.resources.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filter resources',
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
                    if (kindCounts.length > 1) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: _kindFilter == null,
                              onSelected: (_) =>
                                  setState(() => _kindFilter = null),
                            ),
                            const SizedBox(width: 8),
                            for (final kind in kindCounts.keys) ...[
                              FilterChip(
                                avatar: Icon(
                                  deploymentResourceKindIcon(kind),
                                  size: 16,
                                ),
                                label: Text(
                                  '${deploymentResourceKindLabel(kind)}'
                                  ' (${kindCounts[kind]})',
                                ),
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
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Resources', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      if (widget.resources.isNotEmpty)
                        Text(
                          _filteredResources.length == widget.resources.length
                              ? '${widget.resources.length} total'
                              : '${_filteredResources.length} of ${widget.resources.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (widget.resources.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              sliver: SliverToBoxAdapter(
                child: _EmptyResources(
                  projectName: widget.project.name,
                  onAdd: () => _addResource(servers),
                ),
              ),
            )
          else if (_filteredResources.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              sliver: const SliverToBoxAdapter(
                child: Center(
                  child: Text('No resources match the current filters.'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final kind = orderedKinds[index];
                  final items = grouped[kind]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (orderedKinds.length > 1 || _kindFilter != null) ...[
                          Row(
                            children: [
                              Icon(
                                deploymentResourceKindIcon(kind),
                                size: 18,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                deploymentResourceKindLabel(kind),
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${items.length}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        for (final resource in items)
                          _ResourceTile(
                            resource: resource,
                            serverName: resource.serverId == null
                                ? null
                                : serverNames[resource.serverId!],
                            server: resource.serverId == null
                                ? null
                                : serverById[resource.serverId!],
                            onDelete: () => _deleteResource(resource),
                          ),
                      ],
                    ),
                  );
                }, childCount: orderedKinds.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
        color: scheme.surfaceContainerLowest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ProjectEditDraft {
  const _ProjectEditDraft({required this.name, this.description});
  final String name;
  final String? description;
}

class _ProjectEditDialog extends StatefulWidget {
  const _ProjectEditDialog({
    required this.initialName,
    this.initialDescription,
  });
  final String initialName;
  final String? initialDescription;

  @override
  State<_ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<_ProjectEditDialog> {
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
      _ProjectEditDraft(
        name: name,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit project'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Project name'),
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
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );
}

class _ResourceTile extends ConsumerWidget {
  const _ResourceTile({
    required this.resource,
    this.serverName,
    this.server,
    required this.onDelete,
  });
  final DeploymentResource resource;
  final String? serverName;
  final Server? server;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final kind = deploymentResourceKindFromId(resource.kind);
    final config = _configuration(resource.configuration);
    final configSummary = deploymentResourceConfigSummary(config);
    final subtitleParts = <String>[
      deploymentResourceKindLabel(kind),
      ?serverName,
      if (configSummary.isNotEmpty) configSummary,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(deploymentResourceKindIcon(kind), color: scheme.primary),
        title: Text(resource.name),
        subtitle: Text(
          subtitleParts.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Remove from project',
          icon: const Icon(Symbols.close),
          onPressed: onDelete,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
        children: [
          if (kind == DeploymentResourceKind.server && server != null)
            _ServerLivePanel(server: server!),
          if (kind == DeploymentResourceKind.compose && server != null)
            _ComposeLivePanel(
              server: server!,
              resource: resource,
              configuration: config,
            ),
          if (config.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Configuration',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: 6),
            ...config.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatConfigValue(entry.value),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else if (kind != DeploymentResourceKind.server)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No portable configuration recorded.'),
              ),
            ),
          if (server != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (kind == DeploymentResourceKind.serverFolder) {
                    pickRemotePaths(
                      context,
                      ref,
                      server!,
                      title: resource.name,
                      initialPath: '${config['path'] ?? '.'}',
                      selection: CloudFilePickerSelection.fileOrFolder,
                    );
                    return;
                  }
                  context.router.root.push(
                    ServerDetailRoute(
                      server: server!,
                      initialTab: _serverTabFor(kind),
                      initialComposeProject:
                          kind == DeploymentResourceKind.compose
                          ? '${config['compose_project'] ?? resource.name}'
                          : null,
                    ),
                  );
                },
                icon: const Icon(Symbols.open_in_new, size: 18),
                label: Text(
                  kind == DeploymentResourceKind.serverFolder
                      ? 'Browse ${server!.name}'
                      : 'Open on ${server!.name}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatConfigValue(Object? value) {
  if (value is List) {
    if (value.isEmpty) return '—';
    if (value.first is Map) {
      return value
          .map((item) {
            if (item is Map) {
              final name = item['name'] ?? item['path'];
              return name?.toString() ?? item.toString();
            }
            return item.toString();
          })
          .join(', ');
    }
    return value.join(', ');
  }
  if (value is Map) {
    return value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
  final text = '$value'.trim();
  return text.isEmpty ? '—' : text;
}

class _ServerLivePanel extends ConsumerWidget {
  const _ServerLivePanel({required this.server});
  final Server server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref
        .watch(sessionsProvider)
        .asData
        ?.value
        .where((item) => item.serverId == server.id)
        .firstOrNull;
    final stats = session?.stats;
    final connected = session?.status == SessionStatus.connected;
    final memoryUsed =
        stats?.memoryTotalKb == null || stats?.memoryAvailableKb == null
        ? null
        : stats!.memoryTotalKb! - stats.memoryAvailableKb!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live server', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _LiveMetric(
                label: connected ? 'Connected' : 'Not connected',
                value: '${server.username}@${server.host}',
              ),
              if (stats?.loadAverage != null)
                _LiveMetric(
                  label: 'Load',
                  value: stats!.loadAverage!.toStringAsFixed(2),
                ),
              if (memoryUsed != null && stats?.memoryTotalKb != null)
                _LiveMetric(
                  label: 'Memory',
                  value:
                      '${(memoryUsed / 1024).toStringAsFixed(0)} / ${(stats!.memoryTotalKb! / 1024).toStringAsFixed(0)} MB',
                ),
              if (stats?.uptime != null)
                _LiveMetric(
                  label: 'Uptime',
                  value: '${stats!.uptime!.inHours}h',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '$label: $value',
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _ComposeLivePanel extends ConsumerStatefulWidget {
  const _ComposeLivePanel({
    required this.server,
    required this.resource,
    required this.configuration,
  });
  final Server server;
  final DeploymentResource resource;
  final Map<String, Object?> configuration;
  @override
  ConsumerState<_ComposeLivePanel> createState() => _ComposeLivePanelState();
}

class _ComposeLivePanelState extends ConsumerState<_ComposeLivePanel> {
  Future<List<ServerContainer>>? _containers;
  String get _name =>
      '${widget.configuration['compose_project'] ?? widget.resource.name}';
  @override
  void initState() {
    super.initState();
    _containers = _load();
  }

  Future<List<ServerContainer>> _load() async {
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(widget.server);
    final environments = await ref
        .read(connectionManagerProvider)
        .listContainers(
          widget.server.id,
          sshUserIsRoot: widget.server.username == 'root',
          sudoPassword: credential.type == CredentialType.password
              ? credential.password
              : null,
        );
    return [
      for (final environment in environments)
        ...environment.containers.where((item) => item.composeProject == _name),
    ];
  }

  Future<void> _run(ComposeProjectAction action) async {
    final directory = '${widget.configuration['directory'] ?? ''}'.trim();
    if (directory.isEmpty) return;
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(widget.server);
    await runComposeProjectActionWithTerminal(
      ref: ref,
      serverId: widget.server.id,
      serverName: widget.server.name,
      runtime: ContainerRuntime.values.byName(
        '${widget.configuration['runtime'] ?? 'docker'}',
      ),
      scope: ContainerScope.values.byName(
        '${widget.configuration['scope'] ?? 'user'}',
      ),
      projectName: _name,
      directory: directory,
      action: action,
      sudoPassword: credential.type == CredentialType.password
          ? credential.password
          : null,
    );
    if (mounted) setState(() => _containers = _load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ServerContainer>>(
    future: _containers,
    builder: (context, snapshot) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Live stack', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (snapshot.connectionState == ConnectionState.done)
                IconButton(
                  tooltip: 'Refresh containers',
                  icon: const Icon(Symbols.refresh, size: 18),
                  onPressed: () => setState(() => _containers = _load()),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator()
          else if (snapshot.hasError)
            Text('Could not load stack: ${snapshot.error}')
          else if (snapshot.data!.isEmpty)
            const Text('No containers currently match this Compose project.')
          else
            ...snapshot.data!.map(
              (item) => ContainerListTile(
                container: item,
                contentPadding: EdgeInsets.zero,
                onOpen: () => context.router.root.push(
                  ServerDetailRoute(
                    server: widget.server,
                    initialTab: 4,
                    initialComposeProject: _name,
                  ),
                ),
              ),
            ),
          if ('${widget.configuration['directory'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final action in [
                  ComposeProjectAction.up,
                  ComposeProjectAction.stop,
                  ComposeProjectAction.restart,
                  ComposeProjectAction.pull,
                ])
                  OutlinedButton(
                    onPressed: () => _run(action),
                    child: Text(action.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _EmptyResources extends StatelessWidget {
  const _EmptyResources({required this.projectName, required this.onAdd});
  final String projectName;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        children: [
          Icon(
            Symbols.add_link,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No resources in $projectName',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Add servers, folders, containers, Compose stacks, '
            'firewall rules, or systemd units to this collection.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Symbols.add, size: 18),
            label: const Text('Add resource'),
          ),
        ],
      ),
    );
  }
}

Map<String, Object?> _configuration(String source) {
  try {
    final value = jsonDecode(source);
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  } catch (_) {}
  return const {};
}

int _serverTabFor(DeploymentResourceKind kind) => switch (kind) {
  DeploymentResourceKind.systemdService => 2,
  DeploymentResourceKind.webServer => 3,
  DeploymentResourceKind.container || DeploymentResourceKind.compose => 4,
  DeploymentResourceKind.firewallRule => 8,
  _ => 0,
};

class _ResourceDraft {
  const _ResourceDraft({
    required this.kind,
    required this.name,
    required this.serverId,
    required this.configuration,
  });

  final DeploymentResourceKind kind;
  final String name;
  final int? serverId;
  final Map<String, Object?> configuration;
}

class _LinkResourceSheet extends ConsumerStatefulWidget {
  const _LinkResourceSheet({required this.servers});
  final List<Server> servers;

  @override
  ConsumerState<_LinkResourceSheet> createState() => _LinkResourceSheetState();
}

class _LinkResourceSheetState extends ConsumerState<_LinkResourceSheet> {
  var _kind = DeploymentResourceKind.server;
  int? _serverId;
  var _name = '';
  var _location = '';
  var _directory = '';
  var _runtime = ContainerRuntime.docker;
  var _scope = ContainerScope.user;
  var _suggestions = const <String>[];
  var _loadingSuggestions = false;
  String? _suggestionError;

  static const _linkableKinds = [
    DeploymentResourceKind.server,
    DeploymentResourceKind.serverFolder,
    DeploymentResourceKind.container,
    DeploymentResourceKind.compose,
    DeploymentResourceKind.firewallRule,
    DeploymentResourceKind.systemdService,
  ];

  String get _locationLabel => switch (_kind) {
    DeploymentResourceKind.serverFolder => 'Folder path',
    DeploymentResourceKind.container => 'Container name or ID',
    DeploymentResourceKind.compose => 'Compose project name',
    DeploymentResourceKind.firewallRule => 'Rule, port, or service',
    DeploymentResourceKind.systemdService => 'Systemd unit name',
    _ => '',
  };

  Map<String, Object?> get _configuration => switch (_kind) {
    DeploymentResourceKind.serverFolder => {'path': _location.trim()},
    DeploymentResourceKind.container => {'container': _location.trim()},
    DeploymentResourceKind.compose => {
      'compose_project': _location.trim(),
      'directory': _directory.trim(),
      'runtime': _runtime.name,
      'scope': _scope.name,
    },
    DeploymentResourceKind.firewallRule => {'rule': _location.trim()},
    DeploymentResourceKind.systemdService => {'unit': _location.trim()},
    _ => const {},
  };

  Future<void> _loadSuggestions() async {
    final serverId = _serverId;
    if (serverId == null || _locationLabel.isEmpty) return;
    final server = widget.servers
        .where((item) => item.id == serverId)
        .firstOrNull;
    if (server == null) return;
    setState(() {
      _loadingSuggestions = true;
      _suggestionError = null;
      _suggestions = const [];
    });
    try {
      final credential = await ref
          .read(serverRepositoryProvider)
          .credentialFor(server);
      final sudoPassword = credential.type == CredentialType.password
          ? credential.password
          : null;
      final manager = ref.read(connectionManagerProvider);
      final values = switch (_kind) {
        DeploymentResourceKind.container ||
        DeploymentResourceKind.compose => () async {
          final environments = await manager.listContainers(
            serverId,
            sshUserIsRoot: server.username == 'root',
            sudoPassword: sudoPassword,
          );
          return _kind == DeploymentResourceKind.compose
              ? {
                  for (final environment in environments)
                    for (final container in environment.containers)
                      if (container.composeProject != null)
                        container.composeProject!,
                }.toList()
              : [
                  for (final environment in environments)
                    for (final container in environment.containers)
                      container.name,
                ];
        }(),
        DeploymentResourceKind.systemdService => () async {
          final snapshot = await manager.listSystemdUnits(
            serverId,
            sshUserIsRoot: server.username == 'root',
            sudoPassword: sudoPassword,
          );
          return [for (final unit in snapshot.units) unit.name];
        }(),
        DeploymentResourceKind.firewallRule => () async {
          final status = await manager.getFirewallStatus(
            serverId,
            sshUserIsRoot: server.username == 'root',
            sudoPassword: sudoPassword,
          );
          return [for (final rule in status.rules) rule.display];
        }(),
        _ => Future.value(const <String>[]),
      };
      final suggestions = await values;
      if (mounted) {
        final unique = suggestions.toSet().toList()..sort();
        setState(() => _suggestions = unique);
      }
    } catch (error) {
      if (mounted) setState(() => _suggestionError = '$error');
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _selectSuggestion(String value) {
    setState(() {
      _location = value;
      if (_name.trim().isEmpty) _name = value;
    });
  }

  Future<void> _pickFolder() async {
    final server = widget.servers
        .where((item) => item.id == _serverId)
        .firstOrNull;
    if (server == null) return;
    final result = await pickRemotePaths(
      context,
      ref,
      server,
      title: 'Choose linked folder',
      initialPath: _location.isEmpty ? '.' : _location,
      selection: CloudFilePickerSelection.folder,
    );
    if (result != null && result.isNotEmpty && mounted) {
      _selectSuggestion(result.first.path);
    }
  }

  void _submit() {
    if (_serverId == null || _name.trim().isEmpty) return;
    if (_locationLabel.isNotEmpty && _location.trim().isEmpty) return;
    if (_kind == DeploymentResourceKind.compose && _directory.trim().isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      _ResourceDraft(
        kind: _kind,
        name: _name.trim(),
        serverId: _serverId,
        configuration: _configuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _serverId != null &&
        _name.trim().isNotEmpty &&
        (_locationLabel.isEmpty || _location.trim().isNotEmpty) &&
        (_kind != DeploymentResourceKind.compose ||
            _directory.trim().isNotEmpty);

    return SheetScaffold(
      titleText: 'Add resource',
      heightFactor: 0.72,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Add an item to this project collection.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DeploymentResourceKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Resource type'),
            items: [
              for (final kind in _linkableKinds)
                DropdownMenuItem(
                  value: kind,
                  child: Row(
                    children: [
                      Icon(deploymentResourceKindIcon(kind), size: 18),
                      const SizedBox(width: 8),
                      Text(deploymentResourceKindLabel(kind)),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _kind = value!;
                _location = '';
              });
              _loadSuggestions();
            },
          ),
          const SizedBox(height: 12),
          if (widget.servers.isEmpty)
            Text(
              'Add a server in the Servers tab before linking resources.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _serverId,
              decoration: const InputDecoration(labelText: 'Server'),
              items: [
                for (final server in widget.servers)
                  DropdownMenuItem(value: server.id, child: Text(server.name)),
              ],
              onChanged: (value) {
                setState(() => _serverId = value);
                _loadSuggestions();
              },
            ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Display name',
              helperText: 'Shown in this project’s resource list.',
            ),
            onChanged: (value) => setState(() => _name = value),
            onFieldSubmitted: (_) {
              if (canSubmit) _submit();
            },
          ),
          if (_locationLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (value) {
                final query = value.text.toLowerCase();
                return _suggestions.where(
                  (item) => query.isEmpty || item.toLowerCase().contains(query),
                );
              },
              onSelected: _selectSuggestion,
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                if (controller.text != _location) {
                  controller.value = TextEditingValue(
                    text: _location,
                    selection: TextSelection.collapsed(
                      offset: _location.length,
                    ),
                  );
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: _locationLabel,
                    suffixIcon: _loadingSuggestions
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Refresh suggestions',
                            icon: const Icon(Symbols.refresh),
                            onPressed: _loadSuggestions,
                          ),
                  ),
                  onChanged: (value) => setState(() => _location = value),
                  onFieldSubmitted: (_) {
                    if (canSubmit) _submit();
                  },
                );
              },
            ),
            if (_suggestionError != null) ...[
              const SizedBox(height: 6),
              Text(
                'Could not load suggestions: $_suggestionError',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ] else if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Detected on this server',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in _suggestions.take(12))
                    ActionChip(
                      label: Text(item),
                      onPressed: () => _selectSuggestion(item),
                    ),
                ],
              ),
            ],
            if (_kind == DeploymentResourceKind.compose) ...[
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Remote project directory',
                ),
                onChanged: (value) => setState(() => _directory = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ContainerRuntime>(
                initialValue: _runtime,
                decoration: const InputDecoration(labelText: 'Runtime'),
                items: [
                  for (final runtime in ContainerRuntime.values)
                    DropdownMenuItem(value: runtime, child: Text(runtime.name)),
                ],
                onChanged: (value) => setState(() => _runtime = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ContainerScope>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: [
                  for (final scope in ContainerScope.values)
                    DropdownMenuItem(value: scope, child: Text(scope.name)),
                ],
                onChanged: (value) => setState(() => _scope = value!),
              ),
            ],
            if (_kind == DeploymentResourceKind.serverFolder) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _serverId == null ? null : _pickFolder,
                  icon: const Icon(Symbols.folder_open, size: 18),
                  label: const Text('Browse server folders'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: const Icon(Symbols.add),
            label: const Text('Add to project'),
          ),
        ],
      ),
    );
  }
}
