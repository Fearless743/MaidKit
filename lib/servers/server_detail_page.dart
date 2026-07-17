import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';

import '../data/local/app_database.dart';
import 'server_connection_actions.dart';
import 'server_models.dart';
import 'server_providers.dart';

@RoutePage()
class ServerDetailPage extends ConsumerStatefulWidget {
  const ServerDetailPage({super.key, required this.server});

  final Server server;

  @override
  ConsumerState<ServerDetailPage> createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends ConsumerState<ServerDetailPage> {
  AsyncValue<List<ServerProcess>> _processes = const AsyncValue.data([]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProcesses());
  }

  Future<void> _loadProcesses() async {
    setState(() => _processes = const AsyncValue.loading());
    try {
      final processes = await ref
          .read(connectionManagerProvider)
          .listProcesses(widget.server.id);
      if (mounted) setState(() => _processes = AsyncValue.data(processes));
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _processes = AsyncValue.error(error, stackTrace));
      }
    }
  }

  Future<void> _refresh() async {
    await ref.read(connectionManagerProvider).refreshServerInfo(widget.server);
    await _loadProcesses();
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
        onConnect: _connect,
        onRefreshProcesses: _loadProcesses,
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
    required this.onConnect,
    required this.onRefreshProcesses,
  });

  final Server server;
  final SshSessionInfo? session;
  final bool connected;
  final AsyncValue<List<ServerProcess>> processes;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefreshProcesses;

  @override
  Widget build(BuildContext context) {
    final overview = _OverviewPanel(server: server, session: session);
    final inspector = _InspectorTabs(
      connected: connected,
      connectionError: session?.error,
      processes: processes,
      onConnect: onConnect,
      onRefreshProcesses: onRefreshProcesses,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              overview,
              const SizedBox(height: 24),
              SizedBox(height: 560, child: inspector),
            ],
          );
        }
        return Row(
          spacing: 24,
          children: [
            SizedBox(
              width: 360,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [overview],
              ),
            ),
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: inspector,
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Overview', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _ServerIdentity(server: server, session: session),
        const SizedBox(height: 12),
        _ServerSpecifications(
          stats: session?.stats,
          systemInfo: session?.systemInfo,
        ),
        const SizedBox(height: 24),
        Text('Performance', style: theme.textTheme.titleMedium),
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
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server specifications', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final spec in specs) ...[
              _SpecificationRow(spec: spec),
              if (spec != specs.last) const SizedBox(height: 8),
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
        SizedBox(
          width: 104,
          child: Row(
            children: [
              Icon(
                spec.icon,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(spec.label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Flexible(
          child: Text(
            spec.value.isEmpty ? '—' : spec.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium,
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
    required this.onConnect,
    required this.onRefreshProcesses,
  });

  final bool connected;
  final String? connectionError;
  final AsyncValue<List<ServerProcess>> processes;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefreshProcesses;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Processes'),
            Tab(text: 'Containers'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
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
              const _PlannedIntegration(
                icon: Symbols.deployed_code,
                name: 'Contaienrs',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PlannedIntegration extends StatelessWidget {
  const _PlannedIntegration({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text('$name integration is not available yet.'),
      ],
    ),
  );
}

class _ServerIdentity extends StatelessWidget {
  const _ServerIdentity({required this.server, required this.session});

  final Server server;
  final SshSessionInfo? session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = session?.status == SessionStatus.connected;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Symbols.dns,
              size: 20,
              color: connected ? scheme.primary : null,
            ),
            Text(
              '${server.username}@${server.host}:${server.port}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _StatusLabel(connected: connected, status: session?.status),
            if (session?.stats?.updatedAt != null)
              Text('Updated ${_formatTimestamp(session!.stats!.updatedAt)}'),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.connected, required this.status});

  final bool connected;
  final SessionStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = connected
        ? 'Connected'
        : status == SessionStatus.connecting
        ? 'Connecting'
        : status == SessionStatus.failed
        ? 'Failed'
        : 'Not connected';
    final color = connected
        ? scheme.primary
        : status == SessionStatus.failed
        ? scheme.error
        : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _ConnectionPrompt extends StatelessWidget {
  const _ConnectionPrompt({required this.message, required this.onConnect});

  final String message;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.insights, size: 32),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Symbols.link),
            label: const Text('Connect for metrics'),
          ),
        ],
      ),
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats});

  final ServerStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const _NoDataMessage(message: 'Metrics are being collected…');
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
    return GridView.count(
      crossAxisCount: 1,
      mainAxisSpacing: 8,
      childAspectRatio: 4.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _MetricCard(
          icon: Symbols.speed,
          label: 'Load average',
          value: _loadLabel(stats!),
          detail: stats!.cpuCount == null ? null : '${stats!.cpuCount} CPUs',
        ),
        _MetricCard(
          icon: Symbols.memory,
          label: 'Memory',
          value: memoryUsed == null ? '—' : _formatKb(memoryUsed),
          detail: stats!.memoryTotalKb == null
              ? null
              : 'of ${_formatKb(stats!.memoryTotalKb!)}',
          progress: _ratio(memoryUsed, stats!.memoryTotalKb),
        ),
        _MetricCard(
          icon: Symbols.storage,
          label: 'Root disk',
          value: diskUsed == null ? '—' : _formatKb(diskUsed),
          detail: stats!.diskTotalKb == null
              ? null
              : 'of ${_formatKb(stats!.diskTotalKb!)}',
          progress: _ratio(diskUsed, stats!.diskTotalKb),
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: theme.textTheme.labelMedium),
                ),
                Text(value, style: theme.textTheme.titleMedium),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress, minHeight: 4),
            ] else
              const SizedBox(height: 4),
            const SizedBox(height: 4),
            Text(detail ?? ' ', style: theme.textTheme.labelSmall),
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
    loading: () => const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, _) => _NoDataMessage(
      message: 'Could not retrieve processes: $error',
      actionLabel: 'Try again',
      onAction: onRefresh,
    ),
    data: (items) => items.isEmpty
        ? const _NoDataMessage(message: 'No process information is available.')
        : SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('PID'), numeric: true),
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('CPU'), numeric: true),
                  DataColumn(label: Text('Memory'), numeric: true),
                  DataColumn(label: Text('RSS'), numeric: true),
                  DataColumn(label: Text('Command')),
                ],
                rows: [
                  for (final process in items)
                    DataRow(
                      cells: [
                        DataCell(Text('${process.pid}')),
                        DataCell(Text(process.user)),
                        DataCell(
                          Text('${process.cpuPercent.toStringAsFixed(1)}%'),
                        ),
                        DataCell(
                          Text('${process.memoryPercent.toStringAsFixed(1)}%'),
                        ),
                        DataCell(Text(_formatKb(process.rssKb))),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              process.command,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
  );
}

class _NoDataMessage extends StatelessWidget {
  const _NoDataMessage({this.message = '', this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
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
