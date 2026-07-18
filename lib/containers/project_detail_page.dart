import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/servers/server_connection_actions.dart';
import 'package:maid_kit/servers/server_models.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/app_context_menu.dart';
import 'package:maid_kit/theme.dart';
import 'compose_project_actions.dart';
import 'container_cache_repository.dart';
import 'container_list_tile.dart';
import 'container_models.dart';

@RoutePage()
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.linkId});
  final int linkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<List<ComposeProjectLink>>(
        stream: ref.watch(databaseProvider).watchComposeProjectLinks(),
        builder: (context, snapshot) {
          final link = snapshot.data
              ?.where((item) => item.id == linkId)
              .firstOrNull;
          if (link == null) {
            return const Scaffold(
              body: Center(child: Text('This project link no longer exists.')),
            );
          }
          return _ProjectDetailBody(link: link);
        },
      );
}

class _ProjectDetailBody extends ConsumerStatefulWidget {
  const _ProjectDetailBody({required this.link});
  final ComposeProjectLink link;
  @override
  ConsumerState<_ProjectDetailBody> createState() => _ProjectDetailBodyState();
}

class _ProjectDetailBodyState extends ConsumerState<_ProjectDetailBody> {
  String? _compose;
  Object? _composeError;
  var _loadingCompose = false;
  var _refreshing = false;
  var _hasLoadedLive = false;
  var _wasConnected = false;
  var _clientWaitAttempts = 0;
  List<ServerContainer> _liveContainers = const [];
  Object? _containersError;
  Map<String, ContainerStats> _statsById = const {};
  Object? _statsError;
  DateTime? _statsUpdatedAt;
  Timer? _refreshTimer;
  Timer? _retryTimer;

  ContainerRuntime get _runtime =>
      ContainerRuntime.values.byName(widget.link.runtime);
  ContainerScope get _scope => ContainerScope.values.byName(widget.link.scope);

  @override
  void initState() {
    super.initState();
    // Pull live containers + stats as soon as this screen is shown — not only
    // after the first periodic tick or a manual refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
    _startRefreshTimer(ref.read(focusedServerRefreshIntervalProvider));
    ref.listenManual<Duration>(focusedServerRefreshIntervalProvider, (
      _,
      interval,
    ) {
      _startRefreshTimer(interval);
    });
    ref.listenManual(sessionsProvider, (previous, next) {
      final connected = _isServerConnected(next.asData?.value);
      if (connected && !_wasConnected) {
        unawaited(_bootstrap());
      }
      _wasConnected = connected;
    });
    ref.listenManual(serversProvider, (previous, next) {
      // Server list may load after the first frame; bootstrap once available.
      final hadServer =
          previous?.asData?.value.any(
            (server) => server.id == widget.link.serverId,
          ) ??
          false;
      final hasServer =
          next.asData?.value.any(
            (server) => server.id == widget.link.serverId,
          ) ??
          false;
      if (hasServer && !hadServer) {
        unawaited(_bootstrap());
      }
    });
    _wasConnected = _isServerConnected(
      ref.read(sessionsProvider).asData?.value,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  bool _isServerConnected(List<SshSessionInfo>? sessions) {
    if (sessions == null) return false;
    return sessions.any(
      (session) =>
          session.serverId == widget.link.serverId &&
          session.status == SessionStatus.connected,
    );
  }

  void _startRefreshTimer(Duration interval) {
    _refreshTimer?.cancel();
    // Periodic samples while this screen is open.
    _refreshTimer = Timer.periodic(interval, (_) {
      unawaited(_refresh());
    });
  }

  /// Initial / reconnect load of compose file, containers, and stats.
  Future<void> _bootstrap() async {
    if (!mounted) return;
    await Future.wait([_loadCompose(), _refresh()]);
  }

  void _scheduleRetry() {
    if (_retryTimer != null || !mounted) return;
    if (!_isServerConnected(ref.read(sessionsProvider).asData?.value)) {
      _clientWaitAttempts = 0;
      return;
    }
    // Bound retries so a stuck "connected" session without a client cannot
    // spin forever; reconnect and open again will reset via _bootstrap.
    if (_clientWaitAttempts >= 20) return;
    _clientWaitAttempts++;
    _retryTimer = Timer(const Duration(milliseconds: 400), () {
      _retryTimer = null;
      if (mounted) unawaited(_bootstrap());
    });
  }

  Future<String?> _sudoPassword(Server server) async {
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(server);
    return credential.type == CredentialType.password
        ? credential.password
        : null;
  }

  Future<void> _loadCompose() async {
    if (_loadingCompose) return;
    final server = _serverOrNull();
    if (server == null) return;
    final manager = ref.read(connectionManagerProvider);
    if (manager.clientFor(server.id) == null) {
      _scheduleRetry();
      return;
    }
    setState(() {
      _loadingCompose = true;
      _composeError = null;
    });
    try {
      final file = await ref
          .read(connectionManagerProvider)
          .readComposeFile(
            server.id,
            scope: _scope,
            directory: widget.link.directory,
            sudoPassword: await _sudoPassword(server),
          );
      if (mounted) setState(() => _compose = file?.$1);
    } catch (error) {
      if (mounted) setState(() => _composeError = error);
    } finally {
      if (mounted) setState(() => _loadingCompose = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final server = _serverOrNull();
    if (server == null) {
      _scheduleRetry();
      return;
    }
    final manager = ref.read(connectionManagerProvider);
    if (manager.clientFor(server.id) == null) {
      // Session can report connected slightly before the SSH client is retained.
      _scheduleRetry();
      return;
    }
    _clientWaitAttempts = 0;
    _refreshing = true;
    try {
      // Stats need the current running set, so load containers first.
      await _loadLiveContainers(server);
      await _loadStats(server);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadLiveContainers(Server server) async {
    try {
      final environments = await ref
          .read(connectionManagerProvider)
          .listContainers(
            server.id,
            sshUserIsRoot: server.username == 'root',
            sudoPassword: await _sudoPassword(server),
          );
      final containers = environments
          .where(
            (environment) =>
                environment.runtime == _runtime && environment.scope == _scope,
          )
          .expand((environment) => environment.containers)
          .where((container) => container.composeProject == widget.link.name)
          .toList();
      if (mounted) {
        setState(() {
          _hasLoadedLive = true;
          _liveContainers = containers;
          _containersError = null;
        });
      }
    } catch (error) {
      if (mounted && !_hasLoadedLive) {
        setState(() => _containersError = error);
      }
    }
  }

  Future<void> _loadStats(Server server) async {
    final containers = _containersFor(server);
    final runningIds = [
      for (final container in containers)
        if (_isRunning(container)) container.id,
    ];
    if (runningIds.isEmpty) {
      if (mounted) {
        setState(() {
          _statsById = const {};
          _statsError = null;
          _statsUpdatedAt = DateTime.now();
        });
      }
      return;
    }
    try {
      final samples = await ref
          .read(connectionManagerProvider)
          .listContainerStats(
            server.id,
            runtime: _runtime,
            scope: _scope,
            containerIds: runningIds,
            sudoPassword: await _sudoPassword(server),
          );
      if (!mounted) return;
      setState(() {
        _statsById = {
          for (final sample in samples)
            for (final key in _matchKeys(sample, containers)) key: sample,
        };
        _statsError = null;
        _statsUpdatedAt = DateTime.now();
      });
    } catch (error) {
      if (mounted) setState(() => _statsError = error);
    }
  }

  /// Stats IDs may be longer/shorter than `ps` IDs; map by prefix or name.
  Iterable<String> _matchKeys(
    ContainerStats sample,
    List<ServerContainer> containers,
  ) sync* {
    yield sample.id;
    for (final container in containers) {
      if (container.id == sample.id ||
          container.id.startsWith(sample.id) ||
          sample.id.startsWith(container.id) ||
          container.name == sample.name ||
          container.name.endsWith('/${sample.name}') ||
          sample.name == container.name.split('/').last) {
        yield container.id;
      }
    }
  }

  Future<void> _connect(Server server) async {
    final connected = await connectForStatistics(context, ref, server);
    if (connected && mounted) {
      await Future.wait([_refresh(), _loadCompose()]);
    }
  }

  Future<void> _action(Server server, ComposeProjectAction action) async {
    try {
      await runComposeProjectActionWithTerminal(
        ref: ref,
        serverId: server.id,
        serverName: server.name,
        runtime: _runtime,
        scope: _scope,
        projectName: widget.link.name,
        directory: widget.link.directory,
        action: action,
        sudoPassword: await _sudoPassword(server),
      );
      ref.invalidate(containerCacheEntriesProvider);
      if (mounted) {
        showStyledSnackBar(
          message:
              '${widget.link.name} · ${action.label.toLowerCase()} finished.',
          title: 'Project updated',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      showStyledSnackBar(
        message: error.toString(),
        title: 'Could not ${action.label.toLowerCase()}',
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
  }

  Server? _serverOrNull() {
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    return servers.where((item) => item.id == widget.link.serverId).firstOrNull;
  }

  List<ServerContainer> _containersFor(Server server) {
    if (_liveContainers.isNotEmpty || _hasLoadedLive) return _liveContainers;
    final cached = ContainerCacheRepository.groupByServer(
      ref.read(containerCacheEntriesProvider).asData?.value ??
          const <ContainerCacheEntry>[],
    );
    return (cached[server.id] ?? const <ContainerEnvironment>[])
        .where(
          (environment) =>
              environment.runtime == _runtime && environment.scope == _scope,
        )
        .expand((environment) => environment.containers)
        .where((container) => container.composeProject == widget.link.name)
        .toList();
  }

  List<ServerContainer> _containersFromWatch(Server server) {
    if (_liveContainers.isNotEmpty || _hasLoadedLive) return _liveContainers;
    final cached = ContainerCacheRepository.groupByServer(
      ref.watch(containerCacheEntriesProvider).asData?.value ??
          const <ContainerCacheEntry>[],
    );
    return (cached[server.id] ?? const <ContainerEnvironment>[])
        .where(
          (environment) =>
              environment.runtime == _runtime && environment.scope == _scope,
        )
        .expand((environment) => environment.containers)
        .where((container) => container.composeProject == widget.link.name)
        .toList();
  }

  ContainerStats? _statsFor(ServerContainer container) {
    final direct = _statsById[container.id];
    if (direct != null) return direct;
    for (final entry in _statsById.entries) {
      final sample = entry.value;
      if (container.id.startsWith(sample.id) ||
          sample.id.startsWith(container.id) ||
          container.name == sample.name ||
          sample.name == container.name.split('/').last) {
        return sample;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final server = servers
        .where((item) => item.id == widget.link.serverId)
        .firstOrNull;
    if (server == null) {
      return const Scaffold(
        body: Center(child: Text('The linked server no longer exists.')),
      );
    }

    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    final session = sessions
        .where((item) => item.serverId == server.id)
        .firstOrNull;
    final connected = session?.status == SessionStatus.connected;
    final containers = _containersFromWatch(server);
    final running = containers.where(_isRunning).length;
    final samples = [for (final container in containers) ?_statsFor(container)];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.link.name),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: connected
                ? () async {
                    await Future.wait([_refresh(), _loadCompose()]);
                  }
                : null,
            icon: const Icon(Symbols.refresh),
          ),
          AppContextMenuButton(
            menuBuilder: () => Menu(
              children: [
                for (final action in ComposeProjectAction.values)
                  MenuAction(
                    title: action.label,
                    callback: () => unawaited(_action(server, action)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _DetailWorkspace(
        overview: _OverviewPanel(
          link: widget.link,
          server: server,
          runtime: _runtime,
          scope: _scope,
          connected: connected,
          session: session,
          containerCount: containers.length,
          runningCount: running,
          samples: samples,
          statsError: _statsError,
          statsUpdatedAt: _statsUpdatedAt,
          onConnect: () => _connect(server),
        ),
        inspector: _InspectorTabs(
          server: server,
          runtime: _runtime,
          scope: _scope,
          containers: containers,
          containersError: _containersError,
          connected: connected,
          connectionError: session?.error,
          statsFor: _statsFor,
          compose: _compose,
          composeError: _composeError,
          loadingCompose: _loadingCompose,
          onConnect: () => _connect(server),
          onRefreshContainers: _refresh,
          onRefreshCompose: _loadCompose,
        ),
      ),
    );
  }
}

/// Shared surface used by overview and inspector so both columns read as one
/// Material 3 layout rather than a freeform left rail and a carded right pane.
class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DetailWorkspace extends StatelessWidget {
  const _DetailWorkspace({required this.overview, required this.inspector});

  final Widget overview;
  final Widget inspector;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PanelSurface(padding: const EdgeInsets.all(16), child: overview),
              const SizedBox(height: 16),
              SizedBox(height: 560, child: _PanelSurface(child: inspector)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 360,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _PanelSurface(
                    padding: const EdgeInsets.all(16),
                    child: overview,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _PanelSurface(child: inspector),
              ),
            ),
          ],
        ).padding(horizontal: 24);
      },
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.link,
    required this.server,
    required this.runtime,
    required this.scope,
    required this.connected,
    required this.session,
    required this.containerCount,
    required this.runningCount,
    required this.samples,
    required this.statsError,
    required this.statsUpdatedAt,
    required this.onConnect,
  });

  final ComposeProjectLink link;
  final Server server;
  final ContainerRuntime runtime;
  final ContainerScope scope;
  final bool connected;
  final SshSessionInfo? session;
  final int containerCount;
  final int runningCount;
  final List<ContainerStats> samples;
  final Object? statsError;
  final DateTime? statsUpdatedAt;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final runtimeLabel =
        '${runtime.name[0].toUpperCase()}${runtime.name.substring(1)}';
    final scopeLabel = scope == ContainerScope.root ? 'Root' : 'User';
    final totalCpu = samples.fold<double>(
      0,
      (sum, sample) => sum + (sample.cpuPercent ?? 0),
    );
    // Working set is additive across containers.
    final totalMemUsed = samples.fold<int>(
      0,
      (sum, sample) => sum + (sample.memUsedBytes ?? 0),
    );
    // Docker/Podman `MemUsage` is `used / limit`. With no cgroup memory limit,
    // the second value is usually host RAM and is the *same* for every row.
    // Summing it multiplies host memory by container count (e.g. 5×16G ≈ 80G).
    final hostMemBytes = session?.stats?.memoryTotalKb == null
        ? null
        : session!.stats!.memoryTotalKb! * 1024;
    final sharedLimitBytes = samples
        .map((sample) => sample.memLimitBytes)
        .whereType<int>()
        .fold<int?>(
          null,
          (max, value) => max == null || value > max ? value : max,
        );
    final memCeilingBytes = hostMemBytes ?? sharedLimitBytes;
    final totalNetRx = samples.fold<int>(
      0,
      (sum, sample) => sum + (sample.netRxBytes ?? 0),
    );
    final totalNetTx = samples.fold<int>(
      0,
      (sum, sample) => sum + (sample.netTxBytes ?? 0),
    );
    final totalBlockRead = samples.fold<int>(
      0,
      (sum, sample) => sum + (sample.blockReadBytes ?? 0),
    );
    final totalBlockWrite = samples.fold<int>(
      0,
      (sum, sample) => sum + (sample.blockWriteBytes ?? 0),
    );
    final hasSamples = samples.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Overview'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Symbols.deployed_code,
              size: 22,
              fill: runningCount > 0 ? 1 : 0,
              color: runningCount > 0
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(link.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    server.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(
                        connected: connected,
                        status: session?.status,
                      ),
                      _MetaChip(label: runtimeLabel),
                      _MetaChip(label: scopeLabel),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SpecBlock(
          items: [
            _SpecItem(
              icon: Symbols.folder,
              label: 'Directory',
              value: link.directory,
            ),
            _SpecItem(
              icon: Symbols.deployed_code,
              label: 'Containers',
              value: containerCount == 0
                  ? 'None discovered'
                  : '$runningCount / $containerCount running',
            ),
            _SpecItem(
              icon: Symbols.schedule,
              label: 'Linked',
              value: _formatTimestamp(link.linkedAt.toLocal()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Resource cost'),
        const SizedBox(height: 12),
        if (!connected)
          _InlinePrompt(
            message: 'Connect to sample live CPU, memory, and I/O cost.',
            actionLabel: 'Connect',
            onAction: onConnect,
          )
        else if (statsError != null)
          Text(
            'Could not read stats: $statsError',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          )
        else if (!hasSamples)
          Text(
            runningCount == 0
                ? 'No running containers to sample.'
                : 'Waiting for the first stats sample…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else ...[
          _MetricGrid(
            cpuLabel: '${totalCpu.toStringAsFixed(1)}%',
            memoryLabel: _formatBytes(totalMemUsed),
            memoryDetail: memCeilingBytes != null && memCeilingBytes > 0
                ? 'of ${_formatBytes(memCeilingBytes)} host'
                : '${samples.length} containers sampled',
            memoryProgress: memCeilingBytes != null && memCeilingBytes > 0
                ? (totalMemUsed / memCeilingBytes).clamp(0.0, 1.0)
                : null,
            networkLabel: _formatBytes(totalNetRx + totalNetTx),
            networkDetail:
                '↓ ${_formatBytes(totalNetRx)} · ↑ ${_formatBytes(totalNetTx)}',
            blockLabel: _formatBytes(totalBlockRead + totalBlockWrite),
            blockDetail:
                'R ${_formatBytes(totalBlockRead)} · W ${_formatBytes(totalBlockWrite)}',
          ),
          if (statsUpdatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Updated ${_formatTimestamp(statsUpdatedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SpecBlock extends StatelessWidget {
  const _SpecBlock({required this.items});

  final List<_SpecItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < items.length; i++) ...[
              _SpecificationRow(spec: items[i]),
              if (i != items.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpecItem {
  const _SpecItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _SpecificationRow extends StatelessWidget {
  const _SpecificationRow({required this.spec});

  final _SpecItem spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(spec.icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 84,
          child: Text(
            spec.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            spec.value.isEmpty ? '—' : spec.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: spec.label == 'Directory' ? MaidKitFonts.mono : null,
              fontSize: spec.label == 'Directory' ? 12 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.cpuLabel,
    required this.memoryLabel,
    required this.memoryDetail,
    required this.memoryProgress,
    required this.networkLabel,
    required this.networkDetail,
    required this.blockLabel,
    required this.blockDetail,
  });

  final String cpuLabel;
  final String memoryLabel;
  final String memoryDetail;
  final double? memoryProgress;
  final String networkLabel;
  final String networkDetail;
  final String blockLabel;
  final String blockDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Symbols.memory,
                label: 'CPU',
                value: cpuLabel,
                detail: 'Across running containers',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: Symbols.developer_board,
                label: 'Memory',
                value: memoryLabel,
                detail: memoryDetail,
                progress: memoryProgress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Symbols.lan,
                label: 'Network',
                value: networkLabel,
                detail: networkDetail,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: Symbols.hard_drive,
                label: 'Block I/O',
                value: blockLabel,
                detail: blockDetail,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleSmall),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress, minHeight: 4),
              ),
            ],
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InspectorTabs extends StatelessWidget {
  const _InspectorTabs({
    required this.server,
    required this.runtime,
    required this.scope,
    required this.containers,
    required this.containersError,
    required this.connected,
    required this.connectionError,
    required this.statsFor,
    required this.compose,
    required this.composeError,
    required this.loadingCompose,
    required this.onConnect,
    required this.onRefreshContainers,
    required this.onRefreshCompose,
  });

  final Server server;
  final ContainerRuntime runtime;
  final ContainerScope scope;
  final List<ServerContainer> containers;
  final Object? containersError;
  final bool connected;
  final String? connectionError;
  final ContainerStats? Function(ServerContainer container) statsFor;
  final String? compose;
  final Object? composeError;
  final bool loadingCompose;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefreshContainers;
  final Future<void> Function() onRefreshCompose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: scheme.outlineVariant,
            tabs: [
              Tab(
                icon: const Icon(Symbols.deployed_code, size: 18),
                text: 'Containers (${containers.length})',
              ),
              const Tab(icon: Icon(Symbols.code, size: 18), text: 'Compose'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ContainersPane(
                  server: server,
                  runtime: runtime,
                  scope: scope,
                  containers: containers,
                  containersError: containersError,
                  connected: connected,
                  connectionError: connectionError,
                  statsFor: statsFor,
                  onConnect: onConnect,
                  onRefresh: onRefreshContainers,
                ),
                _ComposePane(
                  compose: compose,
                  composeError: composeError,
                  loading: loadingCompose,
                  connected: connected,
                  onConnect: onConnect,
                  onRefresh: onRefreshCompose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ContainerSort { name, cpu, memory, network, block, status }

class _ContainersPane extends StatefulWidget {
  const _ContainersPane({
    required this.server,
    required this.runtime,
    required this.scope,
    required this.containers,
    required this.containersError,
    required this.connected,
    required this.connectionError,
    required this.statsFor,
    required this.onConnect,
    required this.onRefresh,
  });

  final Server server;
  final ContainerRuntime runtime;
  final ContainerScope scope;
  final List<ServerContainer> containers;
  final Object? containersError;
  final bool connected;
  final String? connectionError;
  final ContainerStats? Function(ServerContainer container) statsFor;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefresh;

  @override
  State<_ContainersPane> createState() => _ContainersPaneState();
}

class _ContainersPaneState extends State<_ContainersPane> {
  _ContainerSort _sort = _ContainerSort.name;
  var _ascending = true;

  void _toggleSort(_ContainerSort column) {
    setState(() {
      if (_sort == column) {
        _ascending = !_ascending;
      } else {
        _sort = column;
        _ascending = switch (column) {
          _ContainerSort.name || _ContainerSort.status => true,
          _ContainerSort.cpu ||
          _ContainerSort.memory ||
          _ContainerSort.network ||
          _ContainerSort.block => false,
        };
      }
    });
  }

  List<ServerContainer> get _sorted {
    final items = [...widget.containers];
    int metric(ServerContainer container) {
      final stats = widget.statsFor(container);
      return switch (_sort) {
        _ContainerSort.cpu => ((stats?.cpuPercent ?? -1) * 1000).round(),
        _ContainerSort.memory => stats?.memUsedBytes ?? -1,
        _ContainerSort.network =>
          (stats?.netRxBytes ?? 0) + (stats?.netTxBytes ?? 0),
        _ContainerSort.block =>
          (stats?.blockReadBytes ?? 0) + (stats?.blockWriteBytes ?? 0),
        _ContainerSort.name || _ContainerSort.status => 0,
      };
    }

    int compare(ServerContainer a, ServerContainer b) {
      final result = switch (_sort) {
        _ContainerSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _ContainerSort.status => a.status.toLowerCase().compareTo(
          b.status.toLowerCase(),
        ),
        _ContainerSort.cpu ||
        _ContainerSort.memory ||
        _ContainerSort.network ||
        _ContainerSort.block => metric(a).compareTo(metric(b)),
      };
      // Tie-break by name so equal metrics stay readable.
      if (result == 0 && _sort != _ContainerSort.name) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _ascending ? result : -result;
    }

    items.sort(compare);
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.connected && widget.containers.isEmpty) {
      return _EmptyPanel(
        icon: Symbols.link_off,
        message:
            widget.connectionError ?? 'Connect to load project containers.',
        actionLabel: 'Connect',
        onAction: widget.onConnect,
        filledAction: true,
      );
    }
    if (widget.containersError != null && widget.containers.isEmpty) {
      return _EmptyPanel(
        icon: Symbols.error_outline,
        message: 'Could not load containers: ${widget.containersError}',
        actionLabel: 'Try again',
        onAction: widget.onRefresh,
      );
    }
    if (widget.containers.isEmpty) {
      return _EmptyPanel(
        icon: Symbols.deployed_code,
        message: widget.connected
            ? 'No containers found for this compose project.'
            : 'No cached containers. Connect to refresh.',
        actionLabel: widget.connected ? 'Refresh' : 'Connect',
        onAction: widget.connected ? widget.onRefresh : widget.onConnect,
        filledAction: !widget.connected,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final containers = _sorted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text(
                '${containers.where(_isRunning).length} running · ${containers.length} total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh containers',
                visualDensity: VisualDensity.compact,
                onPressed: widget.connected ? widget.onRefresh : null,
                icon: const Icon(Symbols.refresh),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              return Column(
                children: [
                  _ContainerHeaderRow(
                    wide: wide,
                    sort: _sort,
                    ascending: _ascending,
                    onSort: _toggleSort,
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: ListView.separated(
                      itemCount: containers.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) {
                        final container = containers[index];
                        return ContainerListTile(
                          container: container,
                          stats: widget.statsFor(container),
                          wide: wide,
                          onOpen: () => context.router.push(
                            ContainerDetailRoute(
                              server: widget.server,
                              runtime: widget.runtime,
                              scope: widget.scope,
                              containerId: container.id,
                              containerName: container.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContainerHeaderRow extends StatelessWidget {
  const _ContainerHeaderRow({
    required this.wide,
    required this.sort,
    required this.ascending,
    required this.onSort,
  });

  final bool wide;
  final _ContainerSort sort;
  final bool ascending;
  final ValueChanged<_ContainerSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _SortHeader(
              label: 'Container',
              active: sort == _ContainerSort.name,
              ascending: ascending,
              onTap: () => onSort(_ContainerSort.name),
            ),
          ),
          if (wide) ...[
            SizedBox(
              width: 72,
              child: _SortHeader(
                label: 'CPU',
                active: sort == _ContainerSort.cpu,
                ascending: ascending,
                alignEnd: true,
                onTap: () => onSort(_ContainerSort.cpu),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 108,
              child: _SortHeader(
                label: 'Memory',
                active: sort == _ContainerSort.memory,
                ascending: ascending,
                alignEnd: true,
                onTap: () => onSort(_ContainerSort.memory),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: _SortHeader(
                label: 'Network',
                active: sort == _ContainerSort.network,
                ascending: ascending,
                alignEnd: true,
                onTap: () => onSort(_ContainerSort.network),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: _SortHeader(
                label: 'Block I/O',
                active: sort == _ContainerSort.block,
                ascending: ascending,
                alignEnd: true,
                onTap: () => onSort(_ContainerSort.block),
              ),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: wide ? 100 : 88,
            child: _SortHeader(
              label: 'Status',
              active: sort == _ContainerSort.status,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(_ContainerSort.status),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    final style = theme.textTheme.labelMedium?.copyWith(color: color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(
                ascending ? Symbols.arrow_upward : Symbols.arrow_downward,
                size: 14,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComposePane extends StatelessWidget {
  const _ComposePane({
    required this.compose,
    required this.composeError,
    required this.loading,
    required this.connected,
    required this.onConnect,
    required this.onRefresh,
  });

  final String? compose;
  final Object? composeError;
  final bool loading;
  final bool connected;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (!connected && compose == null && composeError == null && !loading) {
      return _EmptyPanel(
        icon: Symbols.link_off,
        message: 'Connect to read the remote compose file.',
        actionLabel: 'Connect',
        onAction: onConnect,
        filledAction: true,
      );
    }
    if (loading && compose == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (composeError != null && compose == null) {
      return _EmptyPanel(
        icon: Symbols.error_outline,
        message: 'Could not read compose file: $composeError',
        actionLabel: 'Try again',
        onAction: onRefresh,
      );
    }
    if (compose == null) {
      return _EmptyPanel(
        icon: Symbols.code,
        message: 'No compose file found in the linked directory.',
        actionLabel: 'Refresh',
        onAction: onRefresh,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text(
                'Remote compose file',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Refresh compose file',
                  visualDensity: VisualDensity.compact,
                  onPressed: connected ? onRefresh : null,
                  icon: const Icon(Symbols.refresh),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              compose!,
              style: const TextStyle(
                fontFamily: MaidKitFonts.mono,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.connected, required this.status});

  final bool connected;
  final SessionStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, bg) = switch (status) {
      SessionStatus.connected => (
        'Connected',
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      SessionStatus.connecting => (
        'Connecting',
        scheme.onTertiaryContainer,
        scheme.tertiaryContainer,
      ),
      SessionStatus.failed => (
        'Failed',
        scheme.onErrorContainer,
        scheme.errorContainer,
      ),
      _ => (
        connected ? 'Connected' : 'Offline',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
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

class _InlinePrompt extends StatelessWidget {
  const _InlinePrompt({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.filledAction = false,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;
  final bool filledAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            filledAction
                ? FilledButton(onPressed: onAction, child: Text(actionLabel))
                : OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

bool _isRunning(ServerContainer container) => isContainerRunning(container);

String _formatBytes(int bytes) => formatContainerBytes(bytes);

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
}
