import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/containers/container_management_tab.dart';
import 'package:maid_kit/containers/image_management_tab.dart';
import 'activity_tab.dart';
import 'crontab_tab.dart';
import 'firewall_tab.dart';
import 'package_management_tab.dart';
import 'port_forwarding_tab.dart';
import 'server_connection_actions.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'systemd_tab.dart';

@RoutePage()
class ServerDetailPage extends ConsumerStatefulWidget {
  const ServerDetailPage({super.key, required this.server});

  final Server server;

  @override
  ConsumerState<ServerDetailPage> createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends ConsumerState<ServerDetailPage> {
  AsyncValue<List<ServerProcess>> _processes = const AsyncValue.data([]);
  Timer? _refreshTimer;
  late final FocusedServerNotifier _focusedServerNotifier;
  var _refreshing = false;
  var _hasLoadedProcesses = false;

  @override
  void initState() {
    super.initState();
    _focusedServerNotifier = ref.read(focusedServerIdProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProcesses());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusedServerNotifier.focus(widget.server.id);
      }
    });
    _startRefreshTimer(ref.read(focusedServerRefreshIntervalProvider));
    ref.listenManual<Duration>(focusedServerRefreshIntervalProvider, (
      _,
      interval,
    ) {
      _startRefreshTimer(interval);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Riverpod forbids mutating providers during dispose / tree finalization.
    final serverId = widget.server.id;
    final focused = _focusedServerNotifier;
    Future.microtask(() => focused.clear(serverId));
    super.dispose();
  }

  void _startRefreshTimer(Duration interval) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => _refresh());
  }

  Future<void> _loadProcesses() async {
    if (!_hasLoadedProcesses) {
      setState(() => _processes = const AsyncValue.loading());
    }
    try {
      final processes = await ref
          .read(connectionManagerProvider)
          .listProcesses(widget.server.id);
      if (mounted) {
        setState(() {
          _hasLoadedProcesses = true;
          _processes = AsyncValue.data(processes);
        });
      }
    } catch (error, stackTrace) {
      if (mounted && !_hasLoadedProcesses) {
        setState(() => _processes = AsyncValue.error(error, stackTrace));
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final manager = ref.read(connectionManagerProvider);
    if (manager.clientFor(widget.server.id) == null) return;
    _refreshing = true;
    try {
      await manager.refreshServerInfo(widget.server);
      await _loadProcesses();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _connect() async {
    final connected = await connectForStatistics(context, ref, widget.server);
    if (connected && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    final session = sessions
        .where((item) => item.serverId == widget.server.id)
        .firstOrNull;
    final connected = session?.status == SessionStatus.connected;
    final refreshInterval = ref.watch(focusedServerRefreshIntervalProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.name),
        actions: [
          IconButton(
            tooltip: 'Refresh details',
            onPressed: connected ? _refresh : null,
            icon: const Icon(Symbols.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _DetailWorkspace(
        server: widget.server,
        session: session,
        connected: connected,
        processes: _processes,
        refreshInterval: refreshInterval,
        onConnect: _connect,
        onRefreshProcesses: _loadProcesses,
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
  const _DetailWorkspace({
    required this.server,
    required this.session,
    required this.connected,
    required this.processes,
    required this.refreshInterval,
    required this.onConnect,
    required this.onRefreshProcesses,
  });

  final Server server;
  final SshSessionInfo? session;
  final bool connected;
  final AsyncValue<List<ServerProcess>> processes;
  final Duration refreshInterval;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefreshProcesses;

  @override
  Widget build(BuildContext context) {
    final overview = _OverviewPanel(server: server, session: session);
    final inspector = _InspectorTabs(
      connected: connected,
      connectionError: session?.error,
      processes: processes,
      server: server,
      refreshInterval: refreshInterval,
      onConnect: onConnect,
      onRefreshProcesses: onRefreshProcesses,
    );
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
  const _OverviewPanel({required this.server, required this.session});

  final Server server;
  final SshSessionInfo? session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Overview'),
        const SizedBox(height: 12),
        _ServerIdentity(server: server, session: session),
        const SizedBox(height: 16),
        _ServerSpecifications(
          stats: session?.stats,
          systemInfo: session?.systemInfo,
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Performance'),
        const SizedBox(height: 12),
        _MetricGrid(stats: session?.stats),
      ],
    );
  }
}

class _ServerSpecifications extends StatelessWidget {
  const _ServerSpecifications({required this.stats, required this.systemInfo});

  final ServerStats? stats;
  final ServerSystemInfo? systemInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final specs = [
      _SpecItem(
        icon: Symbols.memory,
        label: 'CPU',
        value: stats?.cpuCount == null ? '—' : '${stats!.cpuCount} cores',
      ),
      _SpecItem(
        icon: Symbols.developer_board,
        label: 'Memory',
        value: stats?.memoryTotalKb == null
            ? '—'
            : _formatKb(stats!.memoryTotalKb!),
      ),
      _SpecItem(
        icon: Symbols.storage,
        label: 'Root disk',
        value: stats?.diskTotalKb == null
            ? '—'
            : _formatKb(stats!.diskTotalKb!),
      ),
      _SpecItem(
        icon: Symbols.terminal,
        label: 'System',
        value: [
          systemInfo?.distribution,
          systemInfo?.kernel,
        ].whereType<String>().join(' · '),
      ),
    ];
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
              'Specifications',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final spec in specs) ...[
              _SpecificationRow(spec: spec),
              if (spec != specs.last) const SizedBox(height: 10),
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
      children: [
        Icon(spec.icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _InspectorTabs extends StatelessWidget {
  const _InspectorTabs({
    required this.connected,
    required this.connectionError,
    required this.processes,
    required this.server,
    required this.refreshInterval,
    required this.onConnect,
    required this.onRefreshProcesses,
  });

  final bool connected;
  final String? connectionError;
  final AsyncValue<List<ServerProcess>> processes;
  final Server server;
  final Duration refreshInterval;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefreshProcesses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: scheme.outlineVariant,
            tabs: const [
              Tab(icon: Icon(Symbols.monitoring, size: 18), text: 'Activity'),
              Tab(icon: Icon(Symbols.terminal, size: 18), text: 'Processes'),
              Tab(
                icon: Icon(Symbols.settings_applications, size: 18),
                text: 'Services',
              ),
              Tab(
                icon: Icon(Symbols.deployed_code, size: 18),
                text: 'Containers',
              ),
              Tab(icon: Icon(Symbols.image, size: 18), text: 'Images'),
              Tab(icon: Icon(Symbols.schedule, size: 18), text: 'Crontab'),
              Tab(icon: Icon(Symbols.inventory_2, size: 18), text: 'Packages'),
              Tab(icon: Icon(Symbols.shield, size: 18), text: 'Firewall'),
              Tab(
                icon: Icon(Symbols.swap_horiz, size: 18),
                text: 'Port forwarding',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ActivityTab(
                  server: server,
                  connected: connected,
                  connectionError: connectionError,
                  onConnect: onConnect,
                  refreshInterval: refreshInterval,
                ),
                connected
                    ? _ProcessTable(
                        processes: processes,
                        onRefresh: onRefreshProcesses,
                      )
                    : _ConnectionPrompt(
                        message:
                            connectionError ??
                            'Connect to collect live server data.',
                        onConnect: onConnect,
                      ),
                SystemdTab(
                  server: server,
                  connected: connected,
                  connectionError: connectionError,
                  onConnect: onConnect,
                ),
                ContainerManagementTab(
                  server: server,
                  connected: connected,
                  connectionError: connectionError,
                  onConnect: onConnect,
                  refreshInterval: refreshInterval,
                ),
                ImageManagementTab(
                  server: server,
                  connected: connected,
                  connectionError: connectionError,
                  onConnect: onConnect,
                  refreshInterval: refreshInterval,
                ),
                CrontabTab(
                  server: server,
                  connected: connected,
                  connectionError: connectionError,
                  onConnect: onConnect,
                ),
                PackageManagementTab(
                  server: server,
                  connected: connected,
                  connectionError: connectionError,
                  onConnect: onConnect,
                ),
                FirewallTab(
                  server: server,
                  connected: connected,
                  connectionError: connectionError,
                  onConnect: onConnect,
                ),
                PortForwardingTab(server: server, connected: connected),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerIdentity extends StatelessWidget {
  const _ServerIdentity({required this.server, required this.session});

  final Server server;
  final SshSessionInfo? session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = session?.status == SessionStatus.connected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Symbols.dns,
          size: 22,
          fill: connected ? 1 : 0,
          color: connected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${server.username}@${server.host}:${server.port}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(connected: connected, status: session?.status),
                  if (session?.stats?.updatedAt != null)
                    Text(
                      'Updated ${_formatTimestamp(session!.stats!.updatedAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
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
        'Not connected',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: connected ? scheme.primary : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPrompt extends StatelessWidget {
  const _ConnectionPrompt({required this.message, required this.onConnect});

  final String message;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) => _EmptyPanel(
    icon: Symbols.link_off,
    message: message,
    actionLabel: 'Connect for metrics',
    onAction: onConnect,
    actionIcon: Symbols.link,
    filledAction: true,
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats});

  final ServerStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const _EmptyPanel(
        icon: Symbols.monitoring,
        message: 'Metrics are being collected…',
        compact: true,
      );
    }
    final memoryUsed =
        stats!.memoryTotalKb == null || stats!.memoryAvailableKb == null
        ? null
        : stats!.memoryTotalKb! - stats!.memoryAvailableKb!;
    final diskUsed =
        stats!.diskTotalKb == null || stats!.diskAvailableKb == null
        ? null
        : stats!.diskTotalKb! - stats!.diskAvailableKb!;
    final swapUsed = stats!.swapTotalKb == null || stats!.swapFreeKb == null
        ? null
        : stats!.swapTotalKb! - stats!.swapFreeKb!;
    return Column(
      children: [
        _MetricCard(
          icon: Symbols.speed,
          label: 'Load average',
          value: _loadLabel(stats!),
          detail: stats!.cpuCount == null ? null : '${stats!.cpuCount} CPUs',
        ),
        const SizedBox(height: 8),
        _MetricCard(
          icon: Symbols.memory,
          label: 'Memory',
          value: memoryUsed == null ? '—' : _formatKb(memoryUsed),
          detail: stats!.memoryTotalKb == null
              ? null
              : 'of ${_formatKb(stats!.memoryTotalKb!)}',
          progress: _ratio(memoryUsed, stats!.memoryTotalKb),
        ),
        const SizedBox(height: 8),
        _MetricCard(
          icon: Symbols.storage,
          label: 'Root disk',
          value: diskUsed == null ? '—' : _formatKb(diskUsed),
          detail: stats!.diskTotalKb == null
              ? null
              : 'of ${_formatKb(stats!.diskTotalKb!)}',
          progress: _ratio(diskUsed, stats!.diskTotalKb),
        ),
        const SizedBox(height: 8),
        _MetricCard(
          icon: Symbols.timer,
          label: 'Uptime',
          value: _formatUptime(stats!.uptime),
          detail: swapUsed == null || stats!.swapTotalKb == null
              ? null
              : 'Swap ${_formatKb(swapUsed)} / ${_formatKb(stats!.swapTotalKb!)}',
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
                Text(value, style: theme.textTheme.titleSmall),
              ],
            ),
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

class _ProcessTable extends StatelessWidget {
  const _ProcessTable({required this.processes, required this.onRefresh});

  final AsyncValue<List<ServerProcess>> processes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => processes.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => _EmptyPanel(
      icon: Symbols.error_outline,
      message: 'Could not retrieve processes: $error',
      actionLabel: 'Try again',
      onAction: onRefresh,
    ),
    data: (items) => items.isEmpty
        ? _EmptyPanel(
            icon: Symbols.terminal,
            message: 'No process information is available.',
            actionLabel: 'Refresh',
            onAction: onRefresh,
          )
        : _ProcessList(items: items, onRefresh: onRefresh),
  );
}

enum _ProcessSort { pid, user, cpu, mem, rss, command }

class _ProcessList extends StatefulWidget {
  const _ProcessList({required this.items, required this.onRefresh});

  final List<ServerProcess> items;
  final Future<void> Function() onRefresh;

  @override
  State<_ProcessList> createState() => _ProcessListState();
}

class _ProcessListState extends State<_ProcessList> {
  // Default to highest CPU first so cost hotspots surface immediately.
  _ProcessSort _sort = _ProcessSort.cpu;
  var _ascending = false;

  void _toggleSort(_ProcessSort column) {
    setState(() {
      if (_sort == column) {
        _ascending = !_ascending;
      } else {
        _sort = column;
        // Perf columns default high→low; identity columns low→high.
        _ascending = switch (column) {
          _ProcessSort.cpu || _ProcessSort.mem || _ProcessSort.rss => false,
          _ProcessSort.pid || _ProcessSort.user || _ProcessSort.command => true,
        };
      }
    });
  }

  List<ServerProcess> get _sorted {
    final items = [...widget.items];
    int compare(ServerProcess a, ServerProcess b) {
      final result = switch (_sort) {
        _ProcessSort.pid => a.pid.compareTo(b.pid),
        _ProcessSort.user => a.user.toLowerCase().compareTo(
          b.user.toLowerCase(),
        ),
        _ProcessSort.cpu => a.cpuPercent.compareTo(b.cpuPercent),
        _ProcessSort.mem => a.memoryPercent.compareTo(b.memoryPercent),
        _ProcessSort.rss => a.rssKb.compareTo(b.rssKb),
        _ProcessSort.command => a.command.toLowerCase().compareTo(
          b.command.toLowerCase(),
        ),
      };
      return _ascending ? result : -result;
    }

    items.sort(compare);
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _sorted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text(
                '${items.length} processes',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh processes',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onRefresh,
                icon: const Icon(Symbols.refresh),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              return Column(
                children: [
                  _ProcessHeaderRow(
                    wide: wide,
                    sort: _sort,
                    ascending: _ascending,
                    onSort: _toggleSort,
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) =>
                          _ProcessRow(process: items[index], wide: wide),
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

class _ProcessHeaderRow extends StatelessWidget {
  const _ProcessHeaderRow({
    required this.wide,
    required this.sort,
    required this.ascending,
    required this.onSort,
  });

  final bool wide;
  final _ProcessSort sort;
  final bool ascending;
  final ValueChanged<_ProcessSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: _SortHeader(
              label: 'PID',
              active: sort == _ProcessSort.pid,
              ascending: ascending,
              onTap: () => onSort(_ProcessSort.pid),
            ),
          ),
          SizedBox(
            width: 88,
            child: _SortHeader(
              label: 'User',
              active: sort == _ProcessSort.user,
              ascending: ascending,
              onTap: () => onSort(_ProcessSort.user),
            ),
          ),
          if (wide) ...[
            SizedBox(
              width: 64,
              child: _SortHeader(
                label: 'CPU',
                active: sort == _ProcessSort.cpu,
                ascending: ascending,
                alignEnd: true,
                onTap: () => onSort(_ProcessSort.cpu),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: _SortHeader(
                label: 'Mem',
                active: sort == _ProcessSort.mem,
                ascending: ascending,
                alignEnd: true,
                onTap: () => onSort(_ProcessSort.mem),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: _SortHeader(
                label: 'RSS',
                active: sort == _ProcessSort.rss,
                ascending: ascending,
                alignEnd: true,
                onTap: () => onSort(_ProcessSort.rss),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: _SortHeader(
              label: 'Command',
              active: sort == _ProcessSort.command,
              ascending: ascending,
              onTap: () => onSort(_ProcessSort.command),
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

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.process, required this.wide});

  final ServerProcess process;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text('${process.pid}', style: mono)),
          SizedBox(
            width: 88,
            child: Text(
              process.user,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (wide) ...[
            SizedBox(
              width: 64,
              child: Text(
                '${process.cpuPercent.toStringAsFixed(1)}%',
                textAlign: TextAlign.end,
                style: mono,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text(
                '${process.memoryPercent.toStringAsFixed(1)}%',
                textAlign: TextAlign.end,
                style: mono,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: Text(
                _formatKb(process.rssKb),
                textAlign: TextAlign.end,
                style: mono,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  process.command,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (!wide) ...[
                  const SizedBox(height: 2),
                  Text(
                    'CPU ${process.cpuPercent.toStringAsFixed(1)}% · '
                    'Mem ${process.memoryPercent.toStringAsFixed(1)}% · '
                    'RSS ${_formatKb(process.rssKb)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.filledAction = false,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final IconData? actionIcon;
  final bool filledAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 24 : 32, color: scheme.onSurfaceVariant),
        SizedBox(height: compact ? 8 : 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          if (filledAction)
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Symbols.refresh),
              label: Text(actionLabel!),
            )
          else
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: content,
      );
    }
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

double? _ratio(int? value, int? total) =>
    value == null || total == null || total == 0
    ? null
    : (value / total).clamp(0, 1);

String _loadLabel(ServerStats stats) => [
  stats.loadAverage,
  stats.loadAverage5,
  stats.loadAverage15,
].map((value) => value?.toStringAsFixed(2) ?? '—').join(' · ');

String _formatKb(int value) {
  const kbPerGb = 1024 * 1024;
  return value >= kbPerGb
      ? '${(value / kbPerGb).toStringAsFixed(1)} GB'
      : '${(value / 1024).toStringAsFixed(0)} MB';
}

String _formatUptime(Duration? uptime) {
  if (uptime == null || uptime.inSeconds == 0) return '—';
  final days = uptime.inDays;
  final hours = uptime.inHours.remainder(24);
  final minutes = uptime.inMinutes.remainder(60);
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
