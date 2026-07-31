import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/shared/presentation/app_scaffold.dart';
import 'server_connection_actions.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'sessions_page.dart';
import 'terminal_tabs_provider.dart';

class ServerDashboardTab extends ConsumerWidget {
  const ServerDashboardTab({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final credentials = await ref.read(serverRepositoryProvider).credentials();
    if (!context.mounted) return;
    final draft = await showModalBottomSheet<ServerDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ServerEditorDialog(credentials: credentials),
    );
    if (draft == null || !context.mounted) return;
    try {
      final server = await ref.read(serverRepositoryProvider).create(draft);
      if (!context.mounted) return;
      await _connect(context, ref, server);
    } catch (_) {
      if (context.mounted) {
        showStyledSnackBar(
          message: 'serversSaveError'.tr(),
          title: 'serversSaveError'.tr(),
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    Server server,
  ) async {
    await connectForStatistics(context, ref, server);
  }

  Future<void> _reconnectAll(
    BuildContext context,
    WidgetRef ref,
    List<Server> servers,
  ) async {
    for (final server in servers) {
      if (!context.mounted) return;
      await _connect(context, ref, server);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Server server) async {
    try {
      final repository = ref.read(serverRepositoryProvider);
      final credential = server.credentialId == null
          ? null
          : await repository.credentialFor(server);
      final credentials = await repository.credentials();
      if (!context.mounted) return;
      final draft = await showModalBottomSheet<ServerDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ServerEditorDialog(
          credentials: credentials,
          initial: ServerDraft(
            name: server.name,
            host: server.host,
            port: server.port,
            username: server.username,
            credential: credential,
            credentialId: server.credentialId,
            collectStats: server.collectStats,
            collectSystemInfo: server.collectSystemInfo,
          ),
        ),
      );
      if (draft != null) {
        await ref.read(serverRepositoryProvider).update(server, draft);
      }
    } catch (error) {
      if (context.mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'serversEditError'.tr(),
          icon: Symbols.error_outline,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _delete(WidgetRef ref, Server server) async {
    await ref.read(terminalTabsProvider.notifier).closeForServer(server.id);
    await ref.read(connectionManagerProvider).disconnect(server.id);
    await ref.read(serverRepositoryProvider).delete(server);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    return _ServersCatalog(
      servers: servers,
      sessions: sessions,
      onAdd: () => _add(context, ref),
      onConnect: (server) => _connect(context, ref, server),
      onReconnectAll: (disconnectedServers) =>
          _reconnectAll(context, ref, disconnectedServers),
      onEdit: (server) => _edit(context, ref, server),
      onDelete: (server) => _delete(ref, server),
      onOpenDetail: (server) =>
          ref.read(terminalTabsProvider.notifier).openServerDetails(server),
      onOpenTerminal: (server) => openTerminalSession(context, ref, server),
      onOpenFiles: (server) => _openFiles(context, ref, server),
      onRefresh: (server) =>
          ref.read(connectionManagerProvider).refreshServerInfo(server),
    );
  }

  Future<void> _openFiles(
    BuildContext context,
    WidgetRef ref,
    Server server,
  ) async {
    final manager = ref.read(connectionManagerProvider);
    if (manager.clientFor(server.id) == null &&
        !await connectForStatistics(context, ref, server)) {
      return;
    }
    ref.read(terminalTabsProvider.notifier).openFileManagement(server);
  }
}

@RoutePage()
class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) => const SessionsWorkspace();
}

class _ServersCatalog extends StatelessWidget {
  const _ServersCatalog({
    required this.servers,
    required this.sessions,
    required this.onAdd,
    required this.onConnect,
    required this.onReconnectAll,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenDetail,
    required this.onOpenTerminal,
    required this.onOpenFiles,
    required this.onRefresh,
  });

  final AsyncValue<List<Server>> servers;
  final List<SshSessionInfo> sessions;
  final VoidCallback onAdd;
  final ValueChanged<Server> onConnect;
  final Future<void> Function(List<Server>) onReconnectAll;
  final ValueChanged<Server> onEdit;
  final ValueChanged<Server> onDelete;
  final ValueChanged<Server> onOpenDetail;
  final ValueChanged<Server> onOpenTerminal;
  final ValueChanged<Server> onOpenFiles;
  final ValueChanged<Server> onRefresh;

  @override
  Widget build(BuildContext context) {
    return MaidKitAppScaffold(
      body: servers.when(
        data: (items) => items.isEmpty
            ? _EmptyServers(onAdd: onAdd)
            : _ServerGrid(
                servers: items,
                sessions: sessions,
                onConnect: onConnect,
                onReconnectAll: onReconnectAll,
                onEdit: onEdit,
                onDelete: onDelete,
                onOpenDetail: onOpenDetail,
                onOpenTerminal: onOpenTerminal,
                onOpenFiles: onOpenFiles,
                onRefresh: onRefresh,
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('serversLoadError'.tr(args: [error.toString()])),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'servers-create-fab',
        onPressed: onAdd,
        icon: const Icon(Symbols.add),
        label: Text('serversAddServer'.tr()),
      ),
    );
  }
}

class _ServerGrid extends StatefulWidget {
  const _ServerGrid({
    required this.servers,
    required this.sessions,
    required this.onConnect,
    required this.onReconnectAll,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenDetail,
    required this.onOpenTerminal,
    required this.onOpenFiles,
    required this.onRefresh,
  });

  final List<Server> servers;
  final List<SshSessionInfo> sessions;
  final ValueChanged<Server> onConnect;
  final Future<void> Function(List<Server>) onReconnectAll;
  final ValueChanged<Server> onEdit;
  final ValueChanged<Server> onDelete;
  final ValueChanged<Server> onOpenDetail;
  final ValueChanged<Server> onOpenTerminal;
  final ValueChanged<Server> onOpenFiles;
  final ValueChanged<Server> onRefresh;

  @override
  State<_ServerGrid> createState() => _ServerGridState();
}

class _ServerGridState extends State<_ServerGrid> {
  var _isReconnecting = false;

  Future<void> _reconnectAll(List<Server> servers) async {
    setState(() => _isReconnecting = true);
    try {
      await widget.onReconnectAll(servers);
    } finally {
      if (mounted) setState(() => _isReconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsByServerId = {
      for (final session in widget.sessions) session.serverId: session,
    };
    final disconnectedServers = widget.servers.where((server) {
      final status = sessionsByServerId[server.id]?.status;
      return status != SessionStatus.connected &&
          status != SessionStatus.connecting;
    }).toList();

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: disconnectedServers.length > 1
              ? Padding(
                  key: const ValueKey('servers-reconnect-all'),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _ReconnectAllCard(
                    count: disconnectedServers.length,
                    isReconnecting: _isReconnecting,
                    onPressed: () => _reconnectAll(disconnectedServers),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('servers-reconnect-none')),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 320,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: widget.servers.length,
            itemBuilder: (context, index) {
              final server = widget.servers[index];
              final session = sessionsByServerId[server.id];
              return ContextMenuWidget(
                menuProvider: (_) => Menu(
                  children: [
                    MenuAction(
                      title: 'serversEditServer'.tr(),
                      callback: () => widget.onEdit(server),
                    ),
                    MenuSeparator(),
                    MenuAction(
                      title: 'serversDeleteServer'.tr(),
                      attributes: const MenuActionAttributes(destructive: true),
                      callback: () => widget.onDelete(server),
                    ),
                  ],
                ),
                child: _ServerCard(
                  server: server,
                  session: session,
                  onConnect: () => widget.onConnect(server),
                  onOpenDetail: () => widget.onOpenDetail(server),
                  onOpenTerminal: () => widget.onOpenTerminal(server),
                  onOpenFiles: () => widget.onOpenFiles(server),
                  onRefresh: () => widget.onRefresh(server),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReconnectAllCard extends StatelessWidget {
  const _ReconnectAllCard({
    required this.count,
    required this.isReconnecting,
    required this.onPressed,
  });

  final int count;
  final bool isReconnecting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              Symbols.cloud_off,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'serversDisconnectedCount'.plural(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: isReconnecting ? null : onPressed,
              icon: isReconnecting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : const Icon(Symbols.sync, size: 18),
              label: Text('serversReconnectAll'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.session,
    required this.onConnect,
    required this.onOpenDetail,
    required this.onOpenTerminal,
    required this.onOpenFiles,
    required this.onRefresh,
  });

  final Server server;
  final SshSessionInfo? session;
  final VoidCallback onConnect;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenFiles;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final connected = session?.status == SessionStatus.connected;
    final connecting = session?.status == SessionStatus.connecting;
    final failed = session?.status == SessionStatus.failed;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    Icon(
                      Symbols.dns,
                      fill: connected ? 1 : 0,
                      size: 22,
                      color: connected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            server.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${server.username}@${server.host}:${server.port}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'serversRefreshStatistics'.tr(),
                      visualDensity: VisualDensity.compact,
                      onPressed: connected ? onRefresh : null,
                      icon: const Icon(Symbols.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: connected
                      ? _ServerStats(
                          stats: session?.stats,
                          systemInfo: session?.systemInfo,
                          collectStats: server.collectStats,
                          collectSystemInfo: server.collectSystemInfo,
                        )
                      : _DisconnectedStats(
                          connecting: connecting,
                          error: session?.error,
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
                    _ConnectionStatus(
                      connected: connected,
                      connecting: connecting,
                      failed: failed,
                      latency: session?.latency,
                    ),
                    const Spacer(),
                    if (!connected && !connecting)
                      TextButton(
                        onPressed: onConnect,
                        child: Text('serversConnect'.tr()),
                      ),
                    if (connecting)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ServerQuickActions(
                  onOpenTerminal: connecting ? null : onOpenTerminal,
                  onOpenFiles: connecting ? null : onOpenFiles,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerQuickActions extends StatelessWidget {
  const _ServerQuickActions({this.onOpenTerminal, this.onOpenFiles});

  final VoidCallback? onOpenTerminal;
  final VoidCallback? onOpenFiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenTerminal,
                  icon: const Icon(Symbols.terminal, size: 18),
                  label: Text('sessionsNewTerminal'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'sessionsOpenFileManagement'.tr(),
                child: IconButton.outlined(
                  onPressed: onOpenFiles,
                  icon: const Icon(Symbols.folder, size: 18),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onOpenTerminal,
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                icon: const Icon(Symbols.terminal, size: 18),
                label: Text('sessionsNewTerminal'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenFiles,
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                icon: const Icon(Symbols.folder, size: 18),
                label: Text('sessionsOpenFileManagement'.tr()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    required this.connected,
    required this.connecting,
    required this.failed,
    this.latency,
  });

  final bool connected;
  final bool connecting;
  final bool failed;
  final Duration? latency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final latency = this.latency;

    if (connected) {
      final latencyColor = latency == null
          ? colorScheme.onSurfaceVariant
          : latency.inMilliseconds >= 250
          ? colorScheme.error
          : latency.inMilliseconds >= 100
          ? colorScheme.tertiary
          : colorScheme.onSurfaceVariant;
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            latency == null ? '—' : '${latency.inMilliseconds} ms',
            style: textTheme.labelLarge?.copyWith(color: latencyColor),
          ),
        ],
      );
    }

    final (label, color) = switch ((connecting, failed)) {
      (true, _) => ('serversConnecting'.tr(), colorScheme.tertiary),
      (_, true) => ('serversFailed'.tr(), colorScheme.error),
      _ => ('serversNotConnected'.tr(), colorScheme.onSurfaceVariant),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
        ),
      ],
    );
  }
}

class _DisconnectedStats extends StatelessWidget {
  const _DisconnectedStats({required this.connecting, this.error});

  final bool connecting;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message = connecting
        ? 'serversEstablishingSession'.tr()
        : (error ?? 'serversConnectToViewStats'.tr());

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Icon(
              connecting ? Symbols.hourglass_top : Symbols.insights,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerStats extends StatelessWidget {
  const _ServerStats({
    required this.stats,
    required this.systemInfo,
    required this.collectStats,
    required this.collectSystemInfo,
  });

  final ServerStats? stats;
  final ServerSystemInfo? systemInfo;
  final bool collectStats;
  final bool collectSystemInfo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!collectStats && !collectSystemInfo) {
      return _StatsMessage(
        icon: Symbols.visibility_off,
        message: 'serversCollectionDisabled'.tr(),
      );
    }
    if (stats == null && systemInfo == null) {
      return _StatsMessage(
        icon: Symbols.sync,
        message: 'serversFetchingInfo'.tr(),
      );
    }

    final usedMemoryKb =
        stats?.memoryTotalKb == null || stats?.memoryAvailableKb == null
        ? null
        : stats!.memoryTotalKb! - stats!.memoryAvailableKb!;
    final memoryRatio =
        usedMemoryKb == null ||
            stats?.memoryTotalKb == null ||
            stats!.memoryTotalKb == 0
        ? null
        : (usedMemoryKb / stats!.memoryTotalKb!).clamp(0.0, 1.0);
    final memoryPercent = memoryRatio == null
        ? null
        : (memoryRatio * 100).round();
    final systemLabel = [
      systemInfo?.distribution,
      systemInfo?.kernel,
    ].whereType<String>().join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'detailLoadAverage'.tr(),
                  value: stats!.loadAverage?.toStringAsFixed(2) ?? '—',
                  detail: _loadDetail(stats!.loadAverage),
                  valueColor: _loadColor(stats!.loadAverage, colorScheme),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'detailMemory'.tr(),
                  value: memoryPercent == null ? '—' : '$memoryPercent%',
                  detail: usedMemoryKb == null || stats!.memoryTotalKb == null
                      ? null
                      : '${_formatBytes(usedMemoryKb * 1024)} / ${_formatBytes(stats!.memoryTotalKb! * 1024)}',
                  progress: memoryRatio,
                  progressColor: _memoryColor(memoryRatio, colorScheme),
                  valueColor: _memoryColor(memoryRatio, colorScheme),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'detailUptime'.tr(),
                  value: _formatUptime(stats!.uptime),
                  detail: _uptimeDetail(stats!.uptime),
                ),
              ),
            ],
          )
        else if (collectStats)
          _StatsMessage(
            icon: Symbols.query_stats,
            message: 'serversStatsUnavailable'.tr(),
          ),
        if (systemLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            systemLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ).padding(horizontal: 4),
        ],
        if (stats?.updatedAt != null) ...[
          Text(
            'detailRefreshDetailsAt'.tr(
              args: [_formatRelative(stats!.updatedAt)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
          ).padding(horizontal: 4),
        ],
      ],
    );
  }

  static String? _loadDetail(double? load) {
    if (load == null) return null;
    if (load < 1) return 'serversLoadIdle'.tr();
    if (load < 2) return 'serversLoadNormal'.tr();
    if (load < 4) return 'serversLoadBusy'.tr();
    return 'serversLoadHigh'.tr();
  }

  static String? _uptimeDetail(Duration? uptime) {
    if (uptime == null || uptime.inSeconds == 0) return null;
    if (uptime.inDays >= 30) return 'serversUptimeStable'.tr();
    if (uptime.inHours < 1) return 'serversUptimeRecent'.tr();
    return null;
  }

  static Color? _loadColor(double? load, ColorScheme scheme) {
    if (load == null) return null;
    if (load >= 4) return scheme.error;
    if (load >= 2) return scheme.tertiary;
    return null;
  }

  static Color? _memoryColor(double? ratio, ColorScheme scheme) {
    if (ratio == null) return null;
    if (ratio >= 0.9) return scheme.error;
    if (ratio >= 0.75) return scheme.tertiary;
    return null;
  }
}

class _StatsMessage extends StatelessWidget {
  const _StatsMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.detail,
    this.progress,
    this.progressColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? detail;
  final double? progress;
  final Color? progressColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final resolvedValueColor = valueColor ?? colorScheme.onSurface;
    final resolvedProgressColor = progressColor ?? colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: resolvedValueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            if (progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  color: resolvedProgressColor,
                ),
              )
            else
              const SizedBox(height: 4),
            const SizedBox(height: 6),
            Text(
              detail ?? ' ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const megabyte = 1024 * 1024;
  const gigabyte = 1024 * megabyte;
  return bytes >= gigabyte
      ? '${(bytes / gigabyte).toStringAsFixed(1)} GB'
      : '${(bytes / megabyte).toStringAsFixed(0)} MB';
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

String _formatRelative(DateTime time) {
  final delta = DateTime.now().difference(time);
  if (delta.inSeconds < 15) return 'just now';
  if (delta.inMinutes < 1) return '${delta.inSeconds}s ago';
  if (delta.inHours < 1) return '${delta.inMinutes}m ago';
  if (delta.inDays < 1) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

class _EmptyServers extends StatelessWidget {
  const _EmptyServers({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.dns,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'serversEmpty'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('serversEmptyHint'.tr()),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Symbols.add),
            label: Text('serversAddServer'.tr()),
          ),
        ],
      ),
    ),
  );
}

class ServerEditorDialog extends StatefulWidget {
  const ServerEditorDialog({
    super.key,
    required this.credentials,
    this.initial,
  });

  final ServerDraft? initial;
  final List<SavedCredential> credentials;
  @override
  State<ServerEditorDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<ServerEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  late final _port = TextEditingController(text: 'serverDefaultPort'.tr());
  final _user = TextEditingController();
  final _secret = TextEditingController();
  final _passphrase = TextEditingController();
  CredentialType _type = CredentialType.password;
  int? _credentialId;
  bool _useNewCredential = true;
  bool _collectStats = true;
  bool _collectSystemInfo = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _name.text = initial.name;
    _host.text = initial.host;
    _port.text = initial.port.toString();
    _user.text = initial.username;
    _credentialId = initial.credentialId;
    _useNewCredential = initial.credentialId == null;
    final credential = initial.credential;
    if (credential != null) {
      _type = credential.type;
      _secret.text = credential.password ?? credential.privateKey ?? '';
      _passphrase.text = credential.keyPassphrase ?? '';
    }
    _collectStats = initial.collectStats;
    _collectSystemInfo = initial.collectSystemInfo;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _host,
      _port,
      _user,
      _secret,
      _passphrase,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickKey() async {
    final result = await FilePicker.pickFiles(withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes != null) {
      setState(() => _secret.text = String.fromCharCodes(bytes));
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'serverPortRequired'.tr() : null;
  String? _validPort(String? value) {
    final port = int.tryParse(value ?? '');
    return port != null && port > 0 && port < 65536
        ? null
        : 'serverPortInvalid'.tr();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final credential = !_useNewCredential
        ? null
        : _type == CredentialType.password
        ? ServerCredential.password(_secret.text)
        : ServerCredential.privateKey(
            privateKey: _secret.text,
            keyPassphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          );
    Navigator.pop(
      context,
      ServerDraft(
        name: _name.text,
        host: _host.text,
        port: int.parse(_port.text),
        username: _user.text,
        credential: credential,
        credentialId: _useNewCredential ? null : _credentialId,
        credentialName: _name.text,
        collectStats: _collectStats,
        collectSystemInfo: _collectSystemInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 560,
    child: SheetScaffold(
      titleText: 'serversAddSheetTitle'.tr(),
      heightFactor: 0.78,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: 'serverNameLabel'.tr()),
              validator: _required,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _host,
                    decoration: InputDecoration(
                      labelText: 'serverHostLabel'.tr(),
                    ),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'serverPortLabel'.tr(),
                    ),
                    validator: _validPort,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _user,
              decoration: InputDecoration(
                labelText: 'serverUsernameLabel'.tr(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            if (widget.credentials.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                initialValue: _useNewCredential ? null : _credentialId,
                decoration: InputDecoration(
                  labelText: 'serverCredentialLabel'.tr(),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('serverCredentialNew'.tr()),
                  ),
                  ...widget.credentials.map(
                    (credential) => DropdownMenuItem(
                      value: credential.id,
                      child: Text(credential.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _credentialId = value;
                  _useNewCredential = value == null;
                }),
              ),
              const SizedBox(height: 12),
            ],
            if (_useNewCredential) ...[
              SegmentedButton<CredentialType>(
                segments: [
                  ButtonSegment(
                    value: CredentialType.password,
                    label: Text('serverAuthPassword'.tr()),
                  ),
                  ButtonSegment(
                    value: CredentialType.privateKey,
                    label: Text('serverAuthPrivateKey'.tr()),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
              ),
              const SizedBox(height: 12),
              if (_type == CredentialType.password)
                TextFormField(
                  controller: _secret,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'serverPasswordLabel'.tr(),
                  ),
                  validator: _required,
                )
              else ...[
                TextFormField(
                  controller: _secret,
                  minLines: 4,
                  maxLines: 8,
                  validator: _required,
                  decoration: InputDecoration(
                    labelText: 'serverPrivateKeyLabel'.tr(),
                    suffixIcon: IconButton(
                      onPressed: _pickKey,
                      icon: const Icon(Symbols.upload_file),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passphrase,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'serverKeyPassphraseLabel'.tr(),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('serverCollectStats'.tr()),
              subtitle: Text('serverCollectStatsHint'.tr()),
              value: _collectStats,
              onChanged: (value) => setState(() => _collectStats = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('serverDiscoverSystemInfo'.tr()),
              subtitle: Text('serverDiscoverSystemInfoHint'.tr()),
              value: _collectSystemInfo,
              onChanged: (value) => setState(() => _collectSystemInfo = value),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('commonCancel'.tr()),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text('serverSaveAndConnect'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
