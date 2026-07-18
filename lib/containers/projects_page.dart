import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:super_context_menu/super_context_menu.dart';

import '../data/local/app_database.dart';
import '../servers/server_connection_actions.dart';
import '../servers/server_models.dart';
import '../servers/server_providers.dart';
import '../routing/app_router.gr.dart';
import '../shared/presentation/cloud_file_picker.dart';
import '../shared/presentation/maidkit_alert.dart';
import '../theme.dart';
import 'container_models.dart';
import 'container_cache_repository.dart';
import 'project_repository.dart';

const _composeFileNames = [
  'compose.yaml',
  'compose.yml',
  'docker-compose.yaml',
  'docker-compose.yml',
];

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});

final composeProjectLinksProvider = StreamProvider<List<ComposeProjectLink>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

@RoutePage()
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final _environments = <int, List<ContainerEnvironment>>{};
  var _loading = false;
  var _hasLoaded = false;
  Object? _error;
  int? _serverFilter;
  _ProjectStatusFilter _statusFilter = _ProjectStatusFilter.all;
  ContainerRuntime? _runtimeFilter;
  ContainerScope? _scopeFilter;
  _ProjectUpgradeFilter _upgradeFilter = _ProjectUpgradeFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    final sessions = ref.read(sessionsProvider).asData?.value ?? const [];
    final connected = sessions
        .where((session) => session.status == SessionStatus.connected)
        .map((session) => session.serverId)
        .toSet();
    final cache = ref.read(containerCacheRepositoryProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(
        servers.where((server) => connected.contains(server.id)).map((
          server,
        ) async {
          final credential = await ref
              .read(serverRepositoryProvider)
              .credentialFor(server);
          final values = await ref
              .read(connectionManagerProvider)
              .listContainers(
                server.id,
                sshUserIsRoot: server.username == 'root',
                sudoPassword: credential.type == CredentialType.password
                    ? credential.password
                    : null,
              );
          await cache.replaceForServer(server.id, values);
          return MapEntry(server.id, values);
        }),
      );
      if (mounted) {
        setState(() {
          _hasLoaded = true;
          _environments
            ..clear()
            ..addEntries(results);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newProject({
    Server? initialServer,
    String? initialName,
    String? initialDirectory,
    String? initialSource,
    ContainerRuntime initialRuntime = ContainerRuntime.docker,
    ContainerScope initialScope = ContainerScope.user,
    int? linkId,
    bool importMode = false,
  }) async {
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    if (servers.isEmpty) {
      _snackError('Add a server first.', title: 'No servers');
      return;
    }
    final project = await showModalBottomSheet<_ComposeDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => _ComposeProjectSheet(
        servers: servers,
        initialServer: initialServer,
        initialName: initialName,
        initialDirectory: initialDirectory,
        initialSource: initialSource,
        initialRuntime: initialRuntime,
        initialScope: initialScope,
        importMode: importMode,
      ),
    );
    if (project == null || !mounted) return;
    try {
      final credential = await ref
          .read(serverRepositoryProvider)
          .credentialFor(project.server);
      if (project.deploy) {
        await ref
            .read(connectionManagerProvider)
            .deployComposeProject(
              project.server.id,
              runtime: project.runtime,
              scope: project.scope,
              projectName: project.name,
              directory: project.directory,
              composeSource: project.source,
              sudoPassword: credential.type == CredentialType.password
                  ? credential.password
                  : null,
            );
      }
      await ref
          .read(projectRepositoryProvider)
          .saveLink(
            id: linkId,
            serverId: project.server.id,
            name: project.name,
            directory: project.directory,
            runtime: project.runtime,
            scope: project.scope,
          );
      if (mounted) {
        showStyledSnackBar(
          message: project.deploy
              ? '${project.name} is starting on ${project.server.name}.'
              : '${project.name} is linked on ${project.server.name}.',
          title: project.deploy ? 'Project deployed' : 'Project linked',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
      await _refresh();
    } catch (error) {
      _snackError(error.toString(), title: 'Could not deploy project');
    }
  }

  Future<void> _runProjectAction(
    _ProjectGroup group,
    ComposeProjectAction action,
  ) async {
    if (group.directory == null) return;
    final loading = showMaidKitLoadingModal(
      context,
      message:
          '${action.name[0].toUpperCase()}${action.name.substring(1)}ing ${group.name}…',
    );
    try {
      final credential = await ref
          .read(serverRepositoryProvider)
          .credentialFor(group.server);
      await ref
          .read(connectionManagerProvider)
          .runComposeProjectAction(
            group.server.id,
            runtime: group.environment.runtime,
            scope: group.environment.scope,
            projectName: group.name,
            directory: group.directory!,
            action: action,
            sudoPassword: credential.type == CredentialType.password
                ? credential.password
                : null,
          );
      if (mounted) {
        showStyledSnackBar(
          message: '${group.name} ${action.name} completed.',
          title: 'Project updated',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
      await _refresh();
    } catch (error) {
      _snackError(error.toString(), title: 'Could not ${action.name} project');
    } finally {
      loading.dismiss();
    }
  }

  Future<void> _editProject(_ProjectGroup group) async {
    if (group.directory == null) return;
    final loading = showMaidKitLoadingModal(
      context,
      message: 'Reading ${group.name}…',
    );
    try {
      final source = await _readRemoteCompose(
        group.server,
        group.directory!,
        group.environment.scope,
      );
      if (source == null) {
        _snackError(
          'No compose file was found in ${group.directory}.',
          title: 'Could not edit project',
        );
        return;
      }
      await loading.dismiss();
      await _newProject(
        initialServer: group.server,
        initialName: group.name,
        initialDirectory: group.directory,
        initialSource: source.$1,
        initialRuntime: group.environment.runtime,
        initialScope: group.environment.scope,
        linkId: group.linkId,
      );
    } catch (error) {
      _snackError(error.toString(), title: 'Could not edit project');
    } finally {
      loading.dismiss();
    }
  }

  Future<void> _deleteProjectLink(_ProjectGroup group) async {
    if (group.linkId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Unlink ${group.name}?'),
        content: const Text(
          'This removes the project from MaidKit only. Its remote compose file and containers are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(projectRepositoryProvider).deleteLink(group.linkId!);
    }
  }

  /// Import an existing remote folder that already contains a compose file.
  Future<void> _import() async {
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    if (servers.isEmpty) {
      _snackError('Add a server first.', title: 'No servers');
      return;
    }

    final server = servers.length == 1
        ? servers.first
        : await showDialog<Server>(
            context: context,
            builder: (context) => _PickServerDialog(servers: servers),
          );
    if (server == null || !mounted) return;

    final scope = await showDialog<ContainerScope>(
      context: context,
      builder: (_) => const _PickScopeDialog(),
    );
    if (scope == null || !mounted) return;

    await _importFromFolder(
      server: server,
      scope: scope,
      title: 'Choose compose folder',
    );
  }

  /// Link a scanned compose project (discovered from container labels) to its
  /// remote compose folder so MaidKit can manage it.
  Future<void> _linkScannedProject(_ProjectGroup group) async {
    if (group.raw || group.linkId != null) return;
    await _importFromFolder(
      server: group.server,
      scope: group.environment.scope,
      runtime: group.environment.runtime,
      projectName: group.name,
      title: 'Choose compose folder for ${group.name}',
    );
  }

  Future<void> _importFromFolder({
    required Server server,
    required ContainerScope scope,
    ContainerRuntime runtime = ContainerRuntime.docker,
    String? projectName,
    required String title,
  }) async {
    final picked = await pickRemotePaths(
      context,
      ref,
      server,
      title: title,
      selection: CloudFilePickerSelection.folder,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final directory = picked.first.path;

    String? source;
    final loading = showMaidKitLoadingModal(
      context,
      message: 'Reading compose file from ${server.name}…',
    );
    try {
      final found = await _readRemoteCompose(server, directory, scope);
      source = found?.$1;
    } catch (error) {
      _snackError(error.toString(), title: 'Could not read compose file');
      return;
    } finally {
      loading.dismiss();
    }
    if (source == null || !mounted) {
      _snackError(
        'Expected one of: ${_composeFileNames.join(', ')}',
        title: 'No compose file in folder',
      );
      return;
    }

    final folderName = directory == '/'
        ? 'compose'
        : directory
              .split('/')
              .lastWhere((part) => part.isNotEmpty, orElse: () => 'compose');
    await _newProject(
      initialServer: server,
      initialName: projectName ?? _sanitizeProjectName(folderName),
      initialDirectory: directory,
      initialSource: source,
      initialRuntime: runtime,
      initialScope: scope,
      importMode: true,
    );
  }

  Future<(String, String)?> _readRemoteCompose(
    Server server,
    String directory,
    ContainerScope scope,
  ) async {
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(server);
    return ref
        .read(connectionManagerProvider)
        .readComposeFile(
          server.id,
          scope: scope,
          directory: directory,
          sudoPassword: credential.type == CredentialType.password
              ? credential.password
              : null,
        );
  }

  Future<void> _rawContainer() async {
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    if (servers.isEmpty) {
      _snackError('Add a server first.', title: 'No servers');
      return;
    }
    final draft = await showModalBottomSheet<_RawDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => _RawContainerSheet(servers: servers),
    );
    if (draft == null || !mounted) return;
    try {
      final credential = await ref
          .read(serverRepositoryProvider)
          .credentialFor(draft.server);
      await ref
          .read(connectionManagerProvider)
          .startRawContainer(
            draft.server.id,
            runtime: draft.runtime,
            scope: draft.scope,
            name: draft.name,
            image: draft.image,
            arguments: draft.arguments,
            sudoPassword: credential.type == CredentialType.password
                ? credential.password
                : null,
          );
      if (mounted) {
        showStyledSnackBar(
          message: '${draft.name} was started on ${draft.server.name}.',
          title: 'Container started',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
      await _refresh();
    } catch (error) {
      _snackError(error.toString(), title: 'Could not start container');
    }
  }

  void _snackError(String message, {required String title}) {
    if (!mounted) return;
    showStyledSnackBar(
      message: message,
      title: title,
      icon: Symbols.error,
      accentColor: Theme.of(context).colorScheme.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    final connected = sessions
        .where((s) => s.status == SessionStatus.connected)
        .map((s) => s.serverId)
        .toSet();
    final links =
        ref.watch(composeProjectLinksProvider).asData?.value ??
        const <ComposeProjectLink>[];
    final cached = ContainerCacheRepository.groupByServer(
      ref.watch(containerCacheEntriesProvider).asData?.value ??
          const <ContainerCacheEntry>[],
    );
    final sections = _sections(servers, links, cached);
    final groups = [for (final section in sections) ...section.groups];
    final filteredGroups = groups.where(_matchesFilters).toList();
    final projectCount = groups.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
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
                      Text('Projects', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        connected.isEmpty
                            ? 'Connect a server to discover compose projects'
                            : '$projectCount project${projectCount == 1 ? '' : 's'} · ${connected.length} server${connected.length == 1 ? '' : 's'} connected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _refresh,
                  icon: _loading && _hasLoaded
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : const Icon(Symbols.refresh),
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: _rawContainer,
                  icon: const Icon(Symbols.add_box, size: 18),
                  label: const Text('Run container'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Symbols.folder_open, size: 18),
                  label: const Text('Import'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _newProject(),
                  icon: const Icon(Symbols.add, size: 18),
                  label: const Text('New project'),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: !_hasLoaded && _loading && groups.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _ProjectWorkspace(
                    groups: filteredGroups,
                    hasKnownProjects: groups.isNotEmpty,
                    filters: _ProjectFilters(
                      servers: servers,
                      serverId: _serverFilter,
                      status: _statusFilter,
                      runtime: _runtimeFilter,
                      scope: _scopeFilter,
                      upgrade: _upgradeFilter,
                    ),
                    onFiltersChanged: (filters) => setState(() {
                      _serverFilter = filters.serverId;
                      _statusFilter = filters.status;
                      _runtimeFilter = filters.runtime;
                      _scopeFilter = filters.scope;
                      _upgradeFilter = filters.upgrade;
                    }),
                    connectedServerCount: connected.length,
                    error: _error,
                    onRefresh: _refresh,
                    onNewProject: () => _newProject(),
                    onImport: _import,
                    onLink: _linkScannedProject,
                    onEdit: _editProject,
                    onDelete: _deleteProjectLink,
                    onAction: _runProjectAction,
                    onOpen: (group) => context.router.push(
                      ProjectDetailRoute(linkId: group.linkId!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilters(_ProjectGroup group) {
    if (_serverFilter != null && group.server.id != _serverFilter) {
      return false;
    }
    if (_runtimeFilter != null && group.environment.runtime != _runtimeFilter) {
      return false;
    }
    if (_scopeFilter != null && group.environment.scope != _scopeFilter) {
      return false;
    }
    final status = _statusOf(group);
    if (_statusFilter != _ProjectStatusFilter.all && status != _statusFilter) {
      return false;
    }
    return _upgradeFilter == _ProjectUpgradeFilter.all ||
        _upgradeStatusOf(group) == _upgradeFilter;
  }

  List<_ServerSection> _sections(
    List<Server> servers,
    List<ComposeProjectLink> links,
    Map<int, List<ContainerEnvironment>> cached,
  ) {
    final byServer = {for (final server in servers) server.id: server};
    final groupsByServer = <int, List<_ProjectGroup>>{};
    for (final link in links) {
      final server = byServer[link.serverId];
      if (server == null) continue;
      final runtime = ContainerRuntime.values.byName(link.runtime);
      final scope = ContainerScope.values.byName(link.scope);
      groupsByServer
          .putIfAbsent(server.id, () => [])
          .add(
            _ProjectGroup(
              key:
                  'compose-${server.id}-${runtime.name}-${scope.name}-${link.name}',
              name: link.name,
              server: server,
              environment: ContainerEnvironment(runtime: runtime, scope: scope),
              raw: false,
              directory: link.directory,
              linkId: link.id,
            ),
          );
    }
    for (final server in servers) {
      final environments =
          _environments[server.id] ??
          cached[server.id] ??
          const <ContainerEnvironment>[];
      for (final environment in environments.where((e) => e.isAvailable)) {
        for (final container in environment.containers) {
          final name = container.composeProject;
          // Keys must use enum .name values so scanned containers merge into
          // linked projects (which key with runtime.name / scope.name).
          final key = name == null
              ? 'raw-${server.id}-${environment.runtime.name}-${environment.scope.name}'
              : 'compose-${server.id}-${environment.runtime.name}-${environment.scope.name}-$name';
          final list = groupsByServer.putIfAbsent(server.id, () => []);
          final existing = list.where((group) {
            if (group.key == key) return true;
            // Fall back when a linked name matches the compose project label
            // under the same runtime/scope (covers minor key format drift).
            return name != null &&
                !group.raw &&
                group.name == name &&
                group.environment.runtime == environment.runtime &&
                group.environment.scope == environment.scope;
          }).firstOrNull;
          final group =
              existing ??
              _ProjectGroup(
                key: key,
                name: name ?? 'Standalone containers',
                server: server,
                environment: environment,
                raw: name == null,
                directory: null,
              );
          if (existing == null) list.add(group);
          group.containers.add(container);
        }
      }
    }

    final sections = <_ServerSection>[];
    for (final server in servers) {
      final groups = groupsByServer[server.id];
      if (groups == null || groups.isEmpty) continue;
      groups.sort((a, b) {
        if (a.raw != b.raw) return a.raw ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      sections.add(_ServerSection(server: server, groups: groups));
    }
    return sections;
  }
}

String _sanitizeProjectName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (cleaned.isEmpty) return 'project';
  if (RegExp(r'^[0-9]').hasMatch(cleaned)) return 'p-$cleaned';
  return cleaned;
}

class _ServerSection {
  const _ServerSection({required this.server, required this.groups});
  final Server server;
  final List<_ProjectGroup> groups;
}

class _ProjectGroup {
  _ProjectGroup({
    required this.key,
    required this.name,
    required this.server,
    required this.environment,
    required this.raw,
    this.directory,
    this.linkId,
  });

  final String key;
  final String name;
  final Server server;
  final ContainerEnvironment environment;
  final bool raw;
  final String? directory;
  final int? linkId;
  final containers = <ServerContainer>[];

  int get runningCount =>
      containers.where((container) => _isRunning(container)).length;
}

bool _isRunning(ServerContainer container) {
  final state = container.state.toLowerCase();
  return state.contains('running') || state == 'up';
}

enum _ProjectStatusFilter { all, running, partial, stopped, linked }

enum _ProjectUpgradeFilter { all, upgradeAvailable, upToDate, unknown }

_ProjectStatusFilter _statusOf(_ProjectGroup group) {
  if (group.containers.isEmpty) return _ProjectStatusFilter.linked;
  if (group.runningCount == group.containers.length) {
    return _ProjectStatusFilter.running;
  }
  return group.runningCount == 0
      ? _ProjectStatusFilter.stopped
      : _ProjectStatusFilter.partial;
}

// Image update checks are intentionally non-mutating and are not implemented
// yet; expose their current state honestly rather than treating `latest` as a
// reliable update signal.
_ProjectUpgradeFilter _upgradeStatusOf(_ProjectGroup group) =>
    _ProjectUpgradeFilter.unknown;

class _ProjectFilters {
  const _ProjectFilters({
    required this.servers,
    required this.serverId,
    required this.status,
    required this.runtime,
    required this.scope,
    required this.upgrade,
  });
  final List<Server> servers;
  final int? serverId;
  final _ProjectStatusFilter status;
  final ContainerRuntime? runtime;
  final ContainerScope? scope;
  final _ProjectUpgradeFilter upgrade;
}

class _ProjectWorkspace extends StatelessWidget {
  const _ProjectWorkspace({
    required this.groups,
    required this.hasKnownProjects,
    required this.connectedServerCount,
    required this.onRefresh,
    required this.onNewProject,
    required this.onImport,
    required this.onLink,
    required this.onEdit,
    required this.onDelete,
    required this.onAction,
    required this.onOpen,
    required this.filters,
    required this.onFiltersChanged,
    this.error,
  });

  final List<_ProjectGroup> groups;
  final bool hasKnownProjects;
  final int connectedServerCount;
  final Object? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onNewProject;
  final VoidCallback onImport;
  final Future<void> Function(_ProjectGroup group) onLink;
  final Future<void> Function(_ProjectGroup group) onEdit;
  final Future<void> Function(_ProjectGroup group) onDelete;
  final Future<void> Function(_ProjectGroup group, ComposeProjectAction action)
  onAction;
  final void Function(_ProjectGroup group) onOpen;
  final _ProjectFilters filters;
  final ValueChanged<_ProjectFilters> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    if (error != null && groups.isEmpty && !hasKnownProjects) {
      return _EmptyState(
        icon: Symbols.error_outline,
        title: 'Could not load projects',
        message: error.toString(),
        actionLabel: 'Try again',
        onAction: onRefresh,
      );
    }

    if (groups.isEmpty && !hasKnownProjects) {
      return _EmptyState(
        icon: Symbols.deployed_code,
        title: connectedServerCount == 0
            ? 'No connected servers'
            : 'No projects yet',
        message: connectedServerCount == 0
            ? 'Connect a server from the Servers tab, then import an existing compose folder or create a new project.'
            : 'Import a remote folder that contains docker-compose.yml, or create a new compose project.',
        actionLabel: connectedServerCount == 0 ? 'Refresh' : 'Import',
        onAction: connectedServerCount == 0 ? onRefresh : onImport,
        secondaryLabel: connectedServerCount == 0 ? null : 'New project',
        onSecondary: connectedServerCount == 0 ? null : onNewProject,
      );
    }

    return Column(
      children: [
        _FilterBar(filters: filters, onChanged: onFiltersChanged),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No projects match these filters.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 268,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ContextMenuWidget(
                      menuProvider: (_) => _projectMenu(group),
                      child: _ProjectCard(
                        group: group,
                        onOpen: group.linkId == null
                            ? null
                            : () => onOpen(group),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Menu _projectMenu(_ProjectGroup group) {
    final hasComposeFolder = !group.raw && group.directory != null;
    final canLink = !group.raw && group.linkId == null;
    return Menu(
      children: [
        if (canLink)
          MenuAction(title: 'Link project…', callback: () => onLink(group)),
        MenuAction(
          title: 'Edit project',
          attributes: MenuActionAttributes(disabled: !hasComposeFolder),
          callback: () => onEdit(group),
        ),
        MenuSeparator(),
        MenuAction(
          title: 'Stop',
          attributes: MenuActionAttributes(disabled: !hasComposeFolder),
          callback: () => onAction(group, ComposeProjectAction.stop),
        ),
        MenuAction(
          title: 'Restart',
          attributes: MenuActionAttributes(disabled: !hasComposeFolder),
          callback: () => onAction(group, ComposeProjectAction.restart),
        ),
        MenuAction(
          title: 'Recreate',
          attributes: MenuActionAttributes(disabled: !hasComposeFolder),
          callback: () => onAction(group, ComposeProjectAction.recreate),
        ),
        MenuSeparator(),
        MenuAction(
          title: 'Delete project link',
          attributes: MenuActionAttributes(
            destructive: true,
            disabled: group.linkId == null,
          ),
          callback: () => onDelete(group),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.onChanged});
  final _ProjectFilters filters;
  final ValueChanged<_ProjectFilters> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        child: Row(
          children: [
            DropdownButton<int?>(
              value: filters.serverId,
              hint: const Text('All servers'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All servers')),
                ...filters.servers.map(
                  (server) => DropdownMenuItem(
                    value: server.id,
                    child: Text(server.name),
                  ),
                ),
              ],
              onChanged: (value) => _emit(serverId: value),
            ),
            const SizedBox(width: 16),
            DropdownButton<_ProjectStatusFilter>(
              value: filters.status,
              items: _ProjectStatusFilter.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_filterLabel(value.name)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) _emit(status: value);
              },
            ),
            const SizedBox(width: 16),
            DropdownButton<ContainerRuntime?>(
              value: filters.runtime,
              hint: const Text('All runtimes'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All runtimes'),
                ),
                ...ContainerRuntime.values.map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.name)),
                ),
              ],
              onChanged: (value) => _emit(runtime: value),
            ),
            const SizedBox(width: 16),
            DropdownButton<ContainerScope?>(
              value: filters.scope,
              hint: const Text('All scopes'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All scopes')),
                ...ContainerScope.values.map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.name)),
                ),
              ],
              onChanged: (value) => _emit(scope: value),
            ),
            const SizedBox(width: 16),
            DropdownButton<_ProjectUpgradeFilter>(
              value: filters.upgrade,
              items: _ProjectUpgradeFilter.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_filterLabel(value.name)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) _emit(upgrade: value);
              },
            ),
          ],
        ),
      ),
    ),
  );

  static const _unset = Object();

  void _emit({
    Object? serverId = _unset,
    Object? status = _unset,
    Object? runtime = _unset,
    Object? scope = _unset,
    Object? upgrade = _unset,
  }) => onChanged(
    _ProjectFilters(
      servers: filters.servers,
      serverId: identical(serverId, _unset)
          ? filters.serverId
          : serverId as int?,
      status: identical(status, _unset)
          ? filters.status
          : status as _ProjectStatusFilter,
      runtime: identical(runtime, _unset)
          ? filters.runtime
          : runtime as ContainerRuntime?,
      scope: identical(scope, _unset)
          ? filters.scope
          : scope as ContainerScope?,
      upgrade: identical(upgrade, _unset)
          ? filters.upgrade
          : upgrade as _ProjectUpgradeFilter,
    ),
  );
}

String _filterLabel(String value) => value
    .replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => ' ${match.group(0)!.toLowerCase()}',
    )
    .replaceFirstMapped(
      RegExp(r'^.'),
      (match) => match.group(0)!.toUpperCase(),
    );

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.group, this.onOpen});

  final _ProjectGroup group;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final runtimeLabel =
        '${group.environment.runtime.name[0].toUpperCase()}'
        '${group.environment.runtime.name.substring(1)}';
    final scopeLabel = group.environment.scope == ContainerScope.root
        ? 'Root'
        : 'User';
    final hasContainers = group.containers.isNotEmpty;
    final allRunning =
        hasContainers && group.runningCount == group.containers.length;
    final anyRunning = group.runningCount > 0;
    final statusLabel = !hasContainers
        ? (group.directory == null ? 'No containers' : 'Linked')
        : allRunning
        ? 'Running'
        : anyRunning
        ? 'Partial'
        : 'Stopped';
    final statusColor = !hasContainers
        ? scheme.onSurfaceVariant
        : allRunning
        ? scheme.primary
        : anyRunning
        ? scheme.tertiary
        : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onOpen,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Row(
                  children: [
                    Icon(
                      group.raw ? Symbols.inventory_2 : Symbols.deployed_code,
                      fill: anyRunning ? 1 : 0,
                      size: 22,
                      color: anyRunning
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.server.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MetaChip(label: runtimeLabel),
                              _MetaChip(label: scopeLabel),
                              _MetaChip(
                                label: group.raw ? 'Standalone' : 'Compose',
                              ),
                              if (!group.raw && group.linkId == null)
                                const _MetaChip(label: 'Scanned'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (group.directory != null) ...[
                            Text(
                              group.directory!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                fontFamily: MaidKitFonts.mono,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Expanded(
                            child: hasContainers
                                ? ListView.separated(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: group.containers.length.clamp(
                                      0,
                                      3,
                                    ),
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (context, index) {
                                      final container = group.containers[index];
                                      final running = _isRunning(container);
                                      return Row(
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: running
                                                  ? scheme.primary
                                                  : scheme.outline,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              container.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.bodySmall,
                                            ),
                                          ),
                                          Text(
                                            container.status,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      );
                                    },
                                  )
                                : Text(
                                    group.directory == null
                                        ? 'No running containers discovered yet.'
                                        : 'Compose folder linked. Connect and refresh to load containers.',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                          if (hasContainers && group.containers.length > 3)
                            Text(
                              '+${group.containers.length - 3} more',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasContainers
                          ? '${group.runningCount}/${group.containers.length}'
                          : '—',
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                  if (secondaryLabel != null && onSecondary != null)
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
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

class _PickServerDialog extends StatelessWidget {
  const _PickServerDialog({required this.servers});

  final List<Server> servers;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import from server'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose which server to browse for a compose folder.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final server in servers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.dns),
                title: Text(server.name),
                subtitle: Text('${server.username}@${server.host}'),
                onTap: () => Navigator.pop(context, server),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PickScopeDialog extends StatelessWidget {
  const _PickScopeDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Project scope'),
    content: const Text(
      'Choose the account that owns the compose folder. Root can access folders such as /srv and uses sudo for the import.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      OutlinedButton(
        onPressed: () => Navigator.pop(context, ContainerScope.user),
        child: const Text('User'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, ContainerScope.root),
        child: const Text('Root'),
      ),
    ],
  );
}

class _ComposeDraft {
  const _ComposeDraft(
    this.server,
    this.runtime,
    this.scope,
    this.name,
    this.directory,
    this.source,
    this.deploy,
  );
  final Server server;
  final ContainerRuntime runtime;
  final ContainerScope scope;
  final String name;
  final String directory;
  final String source;
  final bool deploy;
}

class _RawDraft {
  const _RawDraft(
    this.server,
    this.runtime,
    this.scope,
    this.name,
    this.image,
    this.arguments,
  );
  final Server server;
  final ContainerRuntime runtime;
  final ContainerScope scope;
  final String name;
  final String image;
  final String arguments;
}

class _ComposeProjectSheet extends ConsumerStatefulWidget {
  const _ComposeProjectSheet({
    required this.servers,
    this.initialServer,
    this.initialName,
    this.initialDirectory,
    this.initialSource,
    this.initialRuntime = ContainerRuntime.docker,
    this.initialScope = ContainerScope.user,
    this.importMode = false,
  });

  final List<Server> servers;
  final Server? initialServer;
  final String? initialName;
  final String? initialDirectory;
  final String? initialSource;
  final ContainerRuntime initialRuntime;
  final ContainerScope initialScope;
  final bool importMode;

  @override
  ConsumerState<_ComposeProjectSheet> createState() =>
      _ComposeProjectSheetState();
}

class _ComposeProjectSheetState extends ConsumerState<_ComposeProjectSheet> {
  late Server? server =
      widget.initialServer ??
      (widget.servers.isEmpty ? null : widget.servers.first);
  late final name = TextEditingController(text: widget.initialName ?? '');
  late final directory = TextEditingController(
    text: widget.initialDirectory ?? '/opt/maidkit',
  );
  late final source = TextEditingController(
    text:
        widget.initialSource ??
        'services:\n  app:\n    image: nginx:alpine\n    ports:\n      - "8080:80"\n',
  );
  late ContainerRuntime runtime = widget.initialRuntime;
  late ContainerScope scope = widget.initialScope;
  var _browsingDirectory = false;

  @override
  void dispose() {
    name.dispose();
    directory.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> _browseRemoteDirectory() async {
    final selectedServer = server;
    if (selectedServer == null || _browsingDirectory) return;
    setState(() => _browsingDirectory = true);
    try {
      final picked = await pickRemotePaths(
        context,
        ref,
        selectedServer,
        title: 'Choose remote directory',
        initialPath: directory.text.trim().isEmpty
            ? '.'
            : directory.text.trim(),
        selection: CloudFilePickerSelection.folder,
      );
      if (picked == null || picked.isEmpty || !mounted) return;
      setState(() => directory.text = picked.first.path);
    } finally {
      if (mounted) setState(() => _browsingDirectory = false);
    }
  }

  void _submit() {
    final selected = server;
    if (selected == null || name.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _ComposeDraft(
        selected,
        runtime,
        scope,
        name.text.trim(),
        directory.text.trim(),
        source.text,
        !widget.importMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      titleText: widget.importMode
          ? 'Import compose project'
          : 'New compose project',
      heightFactor: 0.88,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (widget.importMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Compose file loaded from the remote folder. It will be linked without starting or changing containers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          DropdownButtonFormField<Server>(
            initialValue: server,
            decoration: const InputDecoration(labelText: 'Server'),
            items: widget.servers
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: widget.importMode
                ? null
                : (value) => setState(() => server = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Project name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: directory,
            readOnly: widget.importMode,
            decoration: InputDecoration(
              labelText: 'Remote directory',
              suffixIcon: widget.importMode
                  ? const Icon(Symbols.lock, size: 18)
                  : IconButton(
                      tooltip: 'Browse remote folder',
                      onPressed: server == null || _browsingDirectory
                          ? null
                          : _browseRemoteDirectory,
                      icon: _browsingDirectory
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Symbols.folder_open),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField(
                  initialValue: runtime,
                  decoration: const InputDecoration(labelText: 'Runtime'),
                  items: ContainerRuntime.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => runtime = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'Scope'),
                  items: ContainerScope.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => scope = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: source,
            minLines: 12,
            maxLines: 18,
            style: const TextStyle(fontFamily: MaidKitFonts.mono, fontSize: 13),

            decoration: InputDecoration(
              labelText: widget.importMode
                  ? 'compose file (from remote)'
                  : 'compose.yaml',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: server == null || name.text.trim().isEmpty
                    ? null
                    : _submit,
                child: Text(widget.importMode ? 'Link project' : 'Deploy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RawContainerSheet extends StatefulWidget {
  const _RawContainerSheet({required this.servers});

  final List<Server> servers;

  @override
  State<_RawContainerSheet> createState() => _RawContainerSheetState();
}

class _RawContainerSheetState extends State<_RawContainerSheet> {
  late Server? server = widget.servers.isEmpty ? null : widget.servers.first;
  final name = TextEditingController();
  final image = TextEditingController();
  final arguments = TextEditingController();
  ContainerRuntime runtime = ContainerRuntime.docker;
  ContainerScope scope = ContainerScope.user;

  @override
  void dispose() {
    name.dispose();
    image.dispose();
    arguments.dispose();
    super.dispose();
  }

  void _submit() {
    final selected = server;
    if (selected == null ||
        name.text.trim().isEmpty ||
        image.text.trim().isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      _RawDraft(
        selected,
        runtime,
        scope,
        name.text.trim(),
        image.text.trim(),
        arguments.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      titleText: 'Run standalone container',
      heightFactor: 0.72,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          DropdownButtonFormField<Server>(
            initialValue: server,
            decoration: const InputDecoration(labelText: 'Server'),
            items: widget.servers
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (value) => setState(() => server = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Container name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: image,
            decoration: const InputDecoration(labelText: 'Image'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: arguments,
            decoration: const InputDecoration(
              labelText: 'Runtime arguments (optional)',
              helperText: 'For example: -p 8080:80 -e KEY=value',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ContainerRuntime>(
                  initialValue: runtime,
                  decoration: const InputDecoration(labelText: 'Runtime'),
                  items: ContainerRuntime.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => runtime = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ContainerScope>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'Scope'),
                  items: ContainerScope.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => scope = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    server == null ||
                        name.text.trim().isEmpty ||
                        image.text.trim().isEmpty
                    ? null
                    : _submit,
                child: const Text('Start'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
