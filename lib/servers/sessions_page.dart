import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/local/app_database.dart';
import 'server_connection_actions.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'terminal_command_palette.dart';
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
                    sessions: sessions,
                    servers: servers,
                    onOpen: (session) => ref
                        .read(terminalTabsProvider.notifier)
                        .open(session.serverId, session.serverName),
                    onConnect: (server) =>
                        connectAndOpenTerminal(context, ref, server),
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
              icon: const Icon(Icons.add),
            ),
          ),
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
                            const Icon(Icons.terminal, size: 18),
                            const SizedBox(width: 8),
                            Text(tab.serverName),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Close terminal',
                              onPressed: () => ref
                                  .read(terminalTabsProvider.notifier)
                                  .close(tab.id),
                              icon: const Icon(Icons.close, size: 18),
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
              icon: const Icon(Icons.add),
            ),
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
    final session = sessions.asData?.value
        .where((item) => item.serverId == tab.serverId)
        .firstOrNull;
    return ColoredBox(
      color: const Color(0xFF111315),
      child: Column(
        children: [
          Expanded(
            child: ClipRect(child: tab.terminal.buildView(autofocus: true)),
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
      session?.status == SessionStatus.connected ? 'Connected' : 'Disconnected',
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
    required this.sessions,
    required this.servers,
    required this.onOpen,
    required this.onConnect,
  });

  final AsyncValue<List<SshSessionInfo>> sessions;
  final AsyncValue<List<Server>> servers;
  final ValueChanged<SshSessionInfo> onOpen;
  final Future<void> Function(Server server) onConnect;

  @override
  Widget build(BuildContext context) => sessions.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(child: Text('Could not load sessions: $error')),
    data: (items) {
      final connected = items
          .where((item) => item.status == SessionStatus.connected)
          .toList();
      if (connected.isEmpty) {
        return servers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Could not load saved servers: $error')),
          data: (servers) => servers.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: () =>
                        AutoTabsRouter.of(context).setActiveIndex(0),
                    icon: const Icon(Icons.add),
                    label: const Text('Add server'),
                  ),
                )
              : ListView.builder(
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    return ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: Text(server.name),
                      subtitle: Text(
                        '${server.username}@${server.host}:${server.port}',
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => onConnect(server),
                        icon: const Icon(Icons.link),
                        label: const Text('Connect'),
                      ),
                    );
                  },
                ),
        );
      }
      return ListView.builder(
        itemCount: connected.length,
        itemBuilder: (context, index) {
          final session = connected[index];
          return ListTile(
            leading: const Icon(Icons.terminal),
            title: Text(session.serverName),
            subtitle: const Text('Connected'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            trailing: FilledButton.tonalIcon(
              onPressed: () => onOpen(session),
              icon: const Icon(Icons.add),
              label: const Text('New terminal'),
            ),
          );
        },
      );
    },
  );
}
