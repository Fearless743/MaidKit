import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'server_connection_actions.dart';
import 'file_management_tab.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'terminal_command_palette.dart';
import 'terminal_find_host.dart';
import 'terminal_tabs_provider.dart';

@RoutePage()
class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(terminalTabsProvider);
    final sessions = ref.watch(sessionsProvider);
    final servers = ref.watch(serversProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _TerminalTabBar(tabs: tabs),
          Expanded(
            child: tabs.tabs.isEmpty
                ? _ConnectedServers(
                    servers: servers,
                    tabs: tabs,
                    onOpenTerminal: (server) =>
                        openTerminalSession(context, ref, server),
                    onOpenFiles: (server) async {
                      final manager = ref.read(connectionManagerProvider);
                      if (manager.clientFor(server.id) == null &&
                          !await connectForStatistics(context, ref, server)) {
                        return;
                      }
                      ref
                          .read(terminalTabsProvider.notifier)
                          .openFileManagement(server);
                    },
                  )
                : _TerminalTabs(tabs: tabs, sessions: sessions),
          ),
        ],
      ),
    );
  }
}

class _TerminalTabBar extends ConsumerWidget {
  const _TerminalTabBar({required this.tabs});

  final TerminalTabsState tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tabs.tabs.isEmpty) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Terminal actions (Shift+Tab)',
              onPressed: () => showTerminalCommandPalette(context, ref),
              icon: const Icon(Symbols.add),
            ),
          ).padding(right: 8),
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: DefaultTabController(
        key: ValueKey(tabs.tabs.length),
        length: tabs.tabs.length,
        initialIndex: tabs.selectedIndex,
        child: Row(
          children: [
            Expanded(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                onTap: (index) => ref
                    .read(terminalTabsProvider.notifier)
                    .select(tabs.tabs[index].id),
                tabs: [
                  for (final tab in tabs.tabs)
                    Tab(
                      child: Listener(
                        onPointerDown: (event) {
                          if (event.buttons & kMiddleMouseButton != 0) {
                            ref
                                .read(terminalTabsProvider.notifier)
                                .close(tab.id);
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.type == SessionTabType.terminal
                                  ? Symbols.terminal
                                  : Symbols.folder,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(tab.serverName),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Close tab',
                              onPressed: () => ref
                                  .read(terminalTabsProvider.notifier)
                                  .close(tab.id),
                              icon: const Icon(Symbols.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Terminal actions (Shift+Tab)',
              onPressed: () => showTerminalCommandPalette(context, ref),
              icon: const Icon(Symbols.add),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _TerminalTabs extends StatelessWidget {
  const _TerminalTabs({required this.tabs, required this.sessions});

  final TerminalTabsState tabs;
  final AsyncValue<List<SshSessionInfo>> sessions;

  @override
  Widget build(BuildContext context) {
    final tab = tabs.tabs[tabs.selectedIndex];
    if (tab is FileManagementTab) return FileManagementTabView(tab: tab);
    final terminalTab = tab as TerminalTab;
    final session = sessions.asData?.value
        .where((item) => item.serverId == terminalTab.serverId)
        .firstOrNull;
    return ColoredBox(
      color: const Color(0xFF111315),
      child: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: TerminalFindHost(
                adapter: terminalTab.terminal,
                autofocus: true,
              ),
            ),
          ),
          _TerminalStatusBar(session: session),
        ],
      ),
    );
  }
}

class _TerminalStatusBar extends StatelessWidget {
  const _TerminalStatusBar({required this.session});

  final SshSessionInfo? session;

  @override
  Widget build(BuildContext context) {
    final stats = session?.stats;
    final usedMemory =
        stats?.memoryTotalKb == null || stats?.memoryAvailableKb == null
        ? null
        : stats!.memoryTotalKb! - stats.memoryAvailableKb!;
    final items = <String>[
      'Connected',
      if (stats?.loadAverage != null)
        'Load ${stats!.loadAverage!.toStringAsFixed(2)}',
      if (usedMemory != null && stats?.memoryTotalKb != null)
        'Memory ${_formatMemory(usedMemory, stats!.memoryTotalKb!)}',
      if (stats?.uptime != null) 'Uptime ${_formatUptime(stats!.uptime!)}',
      if (session?.systemInfo?.distribution != null)
        session!.systemInfo!.distribution!,
      if (session?.systemInfo?.kernel != null) session!.systemInfo!.kernel!,
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('•'),
          ),
          itemBuilder: (context, index) =>
              Text(items[index], style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

String _formatMemory(int usedKb, int totalKb) =>
    '${(usedKb / 1024 / 1024).toStringAsFixed(1)} / ${(totalKb / 1024 / 1024).toStringAsFixed(1)} GB';

String _formatUptime(Duration uptime) {
  final days = uptime.inDays;
  final hours = uptime.inHours.remainder(24);
  return days > 0 ? '${days}d ${hours}h' : '${hours}h';
}

class _ConnectedServers extends StatelessWidget {
  const _ConnectedServers({
    required this.servers,
    required this.tabs,
    required this.onOpenTerminal,
    required this.onOpenFiles,
  });

  final AsyncValue<List<Server>> servers;
  final TerminalTabsState tabs;
  final Future<void> Function(Server server) onOpenTerminal;
  final Future<void> Function(Server server) onOpenFiles;

  @override
  Widget build(BuildContext context) => servers.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) =>
        Center(child: Text('Could not load saved servers: $error')),
    data: (servers) => servers.isEmpty
        ? Center(
            child: FilledButton.icon(
              onPressed: () => AutoTabsRouter.of(context).setActiveIndex(0),
              icon: const Icon(Symbols.add),
              label: const Text('Add server'),
            ),
          )
        : _TerminalServerGrid(
            servers: servers,
            tabs: tabs,
            onOpenTerminal: onOpenTerminal,
            onOpenFiles: onOpenFiles,
          ),
  );
}

class _TerminalServerGrid extends StatelessWidget {
  const _TerminalServerGrid({
    required this.servers,
    required this.tabs,
    required this.onOpenTerminal,
    required this.onOpenFiles,
  });

  final List<Server> servers;
  final TerminalTabsState tabs;
  final Future<void> Function(Server server) onOpenTerminal;
  final Future<void> Function(Server server) onOpenFiles;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(24),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 380,
      mainAxisExtent: 180,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
    ),
    itemCount: servers.length,
    itemBuilder: (context, index) {
      final server = servers[index];
      final terminalCount = tabs.tabs
          .where((tab) => tab.serverId == server.id)
          .length;
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.terminal, size: 22),
              const SizedBox(height: 12),
              Text(server.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${server.username}@${server.host}:${server.port}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    '$terminalCount open',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => onOpenTerminal(server),
                    icon: const Icon(Symbols.add),
                    label: const Text('New terminal'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Open file management',
                    onPressed: () => onOpenFiles(server),
                    icon: const Icon(Symbols.folder),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
