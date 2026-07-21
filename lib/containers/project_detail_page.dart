import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/servers/server_models.dart';
import 'package:maid_kit/servers/server_connection_actions.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/cloud_file_picker.dart';
import 'container_models.dart';
import 'container_list_tile.dart';
import 'compose_project_actions.dart';
import 'deployment_project_models.dart';
import 'project_repository.dart';

/// Detail view for a stored deployment project, independent of remote runtime
/// state. [linkId] remains for links opened from the server container view.
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

class _ProjectDetail extends ConsumerWidget {
  const _ProjectDetail({required this.project, required this.resources});
  final DeploymentProject project;
  final List<DeploymentResource> resources;

  Future<void> _linkResource(
    BuildContext context,
    WidgetRef ref,
    List<Server> servers,
  ) async {
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
          projectId: project.id,
          kind: draft.kind.name,
          name: draft.name,
          serverId: draft.serverId,
          configuration: draft.configuration,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final serverNames = {for (final server in servers) server.id: server.name};
    final serverById = {for (final server in servers) server.id: server};
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: 'Link resource',
            icon: const Icon(Symbols.add_link),
            onPressed: () => _linkResource(context, ref, servers),
          ),
          IconButton(
            tooltip: 'Delete project',
            icon: const Icon(Symbols.delete),
            onPressed: () async {
              await ref
                  .read(projectRepositoryProvider)
                  .deleteProject(project.id);
              if (context.mounted) context.router.maybePop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Deployment project', style: theme.textTheme.headlineSmall),
          if (project.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(project.description!),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Managed resources', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '${resources.length} total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (resources.isEmpty)
            _EmptyResources(
              projectName: project.name,
              onLink: () => _linkResource(context, ref, servers),
            )
          else
            ...resources.map(
              (resource) => _ResourceTile(
                resource: resource,
                serverName: resource.serverId == null
                    ? null
                    : serverNames[resource.serverId!],
                server: resource.serverId == null
                    ? null
                    : serverById[resource.serverId!],
                onDelete: () => ref
                    .read(projectRepositoryProvider)
                    .deleteResource(resource.id),
              ),
            ),
        ],
      ),
    );
  }
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ExpansionTile(
        leading: Icon(_iconFor(kind), color: scheme.primary),
        title: Text(resource.name),
        subtitle: Text([_labelFor(kind), serverName].nonNulls.join(' · ')),
        trailing: IconButton(
          tooltip: 'Remove resource',
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
          if (kind != DeploymentResourceKind.compose && config.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No portable configuration recorded.'),
            ),
        ],
      ),
    );
  }
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
          Text('Live stack', style: Theme.of(context).textTheme.titleSmall),
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
  const _EmptyResources({required this.projectName, required this.onLink});
  final String projectName;
  final VoidCallback onLink;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const Icon(Symbols.add_link, size: 32),
        const SizedBox(height: 12),
        Text('No resources have been added to $projectName.'),
        const SizedBox(height: 4),
        Text(
          'Link a server, its folder, a container, or a Compose deployment.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onLink,
          icon: const Icon(Symbols.add_link),
          label: const Text('Link resource'),
        ),
      ],
    ),
  );
}

Map<String, Object?> _configuration(String source) {
  try {
    final value = jsonDecode(source);
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  } catch (_) {}
  return const {};
}

IconData _iconFor(DeploymentResourceKind kind) => switch (kind) {
  DeploymentResourceKind.server => Symbols.dns,
  DeploymentResourceKind.serverFolder => Symbols.folder,
  DeploymentResourceKind.compose => Symbols.deployed_code,
  DeploymentResourceKind.container => Symbols.deployed_code,
  DeploymentResourceKind.webServer => Symbols.language,
  DeploymentResourceKind.firewallRule => Symbols.security,
  DeploymentResourceKind.systemdService => Symbols.settings,
  DeploymentResourceKind.database => Symbols.database,
  DeploymentResourceKind.other => Symbols.extension,
};

String _labelFor(DeploymentResourceKind kind) => switch (kind) {
  DeploymentResourceKind.server => 'Server',
  DeploymentResourceKind.serverFolder => 'Server folder',
  DeploymentResourceKind.compose => 'Compose stack',
  DeploymentResourceKind.container => 'Container',
  DeploymentResourceKind.webServer => 'Web server',
  DeploymentResourceKind.firewallRule => 'Firewall rule',
  DeploymentResourceKind.systemdService => 'Systemd service',
  DeploymentResourceKind.database => 'Database integration',
  DeploymentResourceKind.other => 'Integration',
};

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
  Widget build(BuildContext context) => SheetScaffold(
    titleText: 'Link resource',
    heightFactor: 0.68,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        DropdownButtonFormField<DeploymentResourceKind>(
          initialValue: _kind,
          decoration: const InputDecoration(labelText: 'Resource type'),
          items: const [
            DropdownMenuItem(
              value: DeploymentResourceKind.server,
              child: Text('Server'),
            ),
            DropdownMenuItem(
              value: DeploymentResourceKind.serverFolder,
              child: Text('Server folder'),
            ),
            DropdownMenuItem(
              value: DeploymentResourceKind.container,
              child: Text('Container'),
            ),
            DropdownMenuItem(
              value: DeploymentResourceKind.compose,
              child: Text('Compose deployment'),
            ),
            DropdownMenuItem(
              value: DeploymentResourceKind.firewallRule,
              child: Text('Firewall rule'),
            ),
            DropdownMenuItem(
              value: DeploymentResourceKind.systemdService,
              child: Text('Systemd service'),
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
          decoration: const InputDecoration(labelText: 'Display name'),
          onChanged: (value) => _name = value,
          onFieldSubmitted: (_) => _submit(),
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
                  selection: TextSelection.collapsed(offset: _location.length),
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
                onChanged: (value) => _location = value,
                onFieldSubmitted: (_) => _submit(),
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
              onChanged: (value) => _directory = value,
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
          onPressed: _submit,
          icon: const Icon(Symbols.add_link),
          label: const Text('Link resource'),
        ),
      ],
    ),
  );
}
