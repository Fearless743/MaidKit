import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

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
    final focusedSession = _sessionForTab(sessions, tabs.selectedTab);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: tabs.isEmpty
                ? _SessionIntro(
                    servers: servers,
                    tabs: tabs,
                    // Full-workspace intro (no pane chrome / no top tab strip).
                    onOpenTerminal: (server) =>
                        openTerminalSession(context, ref, server),
                    onOpenFiles: (server) => _openFiles(context, ref, server),
                  )
                : _SessionLayoutView(tabs: tabs, servers: servers),
          ),
          if (tabs.selectedTab != null)
            _TerminalStatusBar(session: focusedSession),
        ],
      ),
    );
  }
}

SshSessionInfo? _sessionForTab(
  AsyncValue<List<SshSessionInfo>> sessions,
  SessionTab? tab,
) {
  if (tab == null) return null;
  return sessions.asData?.value
      .where((item) => item.serverId == tab.serverId)
      .firstOrNull;
}

Future<void> _openFiles(
  BuildContext context,
  WidgetRef ref,
  Server server, {
  String? paneId,
}) async {
  final manager = ref.read(connectionManagerProvider);
  if (manager.clientFor(server.id) == null &&
      !await connectForStatistics(context, ref, server)) {
    return;
  }
  ref
      .read(terminalTabsProvider.notifier)
      .openFileManagement(server, paneId: paneId);
}

class _SessionLayoutView extends ConsumerWidget {
  const _SessionLayoutView({required this.tabs, required this.servers});

  final TerminalTabsState tabs;
  final AsyncValue<List<Server>> servers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = tabs.layout;
    if (root == null) {
      final pane = tabs.focusedPane;
      if (pane == null) return const SizedBox.shrink();
      return _SessionPaneView(paneId: pane.id, tabs: tabs, servers: servers);
    }
    return _LayoutNode(node: root, tabs: tabs, servers: servers);
  }
}

class _LayoutNode extends ConsumerWidget {
  const _LayoutNode({
    required this.node,
    required this.tabs,
    required this.servers,
  });

  final SessionLayout node;
  final TerminalTabsState tabs;
  final AsyncValue<List<Server>> servers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (node) {
      case SessionLayoutLeaf(:final paneId):
        return _SessionPaneView(paneId: paneId, tabs: tabs, servers: servers);
      case SessionLayoutSplit(
        :final id,
        :final axis,
        :final first,
        :final second,
        :final ratio,
      ):
        return _ResizableSplit(
          axis: axis,
          ratio: ratio,
          onRatioChanged: (value) =>
              ref.read(terminalTabsProvider.notifier).setSplitRatio(id, value),
          first: _LayoutNode(node: first, tabs: tabs, servers: servers),
          second: _LayoutNode(node: second, tabs: tabs, servers: servers),
        );
    }
  }
}

class _ResizableSplit extends StatefulWidget {
  const _ResizableSplit({
    required this.axis,
    required this.ratio,
    required this.onRatioChanged,
    required this.first,
    required this.second,
  });

  final SessionSplitAxis axis;
  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final Widget first;
  final Widget second;

  @override
  State<_ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<_ResizableSplit> {
  static const _dividerThickness = 4.0;
  double? _dragRatio;

  double get _ratio => _dragRatio ?? widget.ratio;

  void _onDragUpdate(DragUpdateDetails details, double maxExtent) {
    if (maxExtent <= 0) return;
    final delta = widget.axis == SessionSplitAxis.horizontal
        ? details.delta.dx
        : details.delta.dy;
    final next = clampSplitRatio(_ratio + delta / maxExtent);
    setState(() => _dragRatio = next);
  }

  void _onDragEnd() {
    final ratio = _dragRatio;
    if (ratio != null) {
      widget.onRatioChanged(ratio);
    }
    setState(() => _dragRatio = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHorizontal = widget.axis == SessionSplitAxis.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxExtent = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final available = maxExtent - _dividerThickness;
        final firstExtent = available * _ratio;
        final secondExtent = available - firstExtent;

        final children = <Widget>[
          SizedBox(
            width: isHorizontal ? firstExtent : null,
            height: isHorizontal ? null : firstExtent,
            child: widget.first,
          ),
          MouseRegion(
            cursor: isHorizontal
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: isHorizontal
                  ? (d) => _onDragUpdate(d, available)
                  : null,
              onHorizontalDragEnd: isHorizontal ? (_) => _onDragEnd() : null,
              onVerticalDragUpdate: isHorizontal
                  ? null
                  : (d) => _onDragUpdate(d, available),
              onVerticalDragEnd: isHorizontal ? null : (_) => _onDragEnd(),
              child: ColoredBox(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                child: SizedBox(
                  width: isHorizontal ? _dividerThickness : double.infinity,
                  height: isHorizontal ? double.infinity : _dividerThickness,
                ),
              ),
            ),
          ),
          SizedBox(
            width: isHorizontal ? secondExtent : null,
            height: isHorizontal ? null : secondExtent,
            child: widget.second,
          ),
        ];

        return isHorizontal
            ? Row(children: children)
            : Column(children: children);
      },
    );
  }
}

class _SessionPaneView extends ConsumerWidget {
  const _SessionPaneView({
    required this.paneId,
    required this.tabs,
    required this.servers,
  });

  final String paneId;
  final TerminalTabsState tabs;
  final AsyncValue<List<Server>> servers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pane = tabs.panes[paneId];
    if (pane == null) return const SizedBox.shrink();

    final paneTabs = tabs.tabsInPane(paneId);
    final focused = tabs.focusedPaneId == paneId;
    final isEmptyPane = pane.isEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => ref.read(terminalTabsProvider.notifier).focusPane(paneId),
      child: Column(
        children: [
          // Only the pane's own tab strip — never a workspace-wide bar.
          _PaneTabBar(
            paneId: paneId,
            paneTabs: paneTabs,
            selectedTabId: pane.selectedTabId,
            focused: focused,
            showClosePane: tabs.hasSplits || isEmptyPane,
          ),
          Expanded(
            child: isEmptyPane
                ? _SessionIntro(
                    servers: servers,
                    tabs: tabs,
                    compact: true,
                    onOpenTerminal: (server) => openTerminalSession(
                      context,
                      ref,
                      server,
                      paneId: paneId,
                    ),
                    onOpenFiles: (server) =>
                        _openFiles(context, ref, server, paneId: paneId),
                  )
                : _PaneTabStack(
                    paneTabs: paneTabs,
                    selectedTabId: pane.selectedTabId,
                    paneFocused: focused,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shared height for each pane tab strip and its tab chips.
const _paneTabBarHeight = 40.0;

class _TabDragData {
  const _TabDragData({required this.tabId, required this.fromPaneId});

  final String tabId;
  final String fromPaneId;
}

class _PaneTabBar extends ConsumerWidget {
  const _PaneTabBar({
    required this.paneId,
    required this.paneTabs,
    required this.selectedTabId,
    required this.focused,
    required this.showClosePane,
  });

  final String paneId;
  final List<SessionTab> paneTabs;
  final String? selectedTabId;
  final bool focused;
  final bool showClosePane;

  void _acceptTab(WidgetRef ref, _TabDragData data, {int? toIndex}) {
    ref
        .read(terminalTabsProvider.notifier)
        .moveTab(data.tabId, paneId, toIndex: toIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: focused ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
      child: SizedBox(
        height: _paneTabBarHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DragTarget<_TabDragData>(
                onWillAcceptWithDetails: (details) =>
                    details.data.tabId.isNotEmpty,
                onAcceptWithDetails: (details) => _acceptTab(ref, details.data),
                builder: (context, candidate, rejected) {
                  final hovering = candidate.isNotEmpty;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: hovering
                          ? scheme.primary.withValues(alpha: 0.08)
                          : null,
                    ),
                    child: paneTabs.isEmpty
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                hovering
                                    ? 'sessionsDropTabHere'.tr()
                                    : 'sessionsNewPane'.tr(),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            // Trailing slot so tabs can be dropped after the last item.
                            itemCount: paneTabs.length + 1,
                            itemBuilder: (context, index) {
                              if (index == paneTabs.length) {
                                return _TabDropTail(
                                  hovering: hovering,
                                  onAccept: (data) => _acceptTab(
                                    ref,
                                    data,
                                    toIndex: paneTabs.length,
                                  ),
                                );
                              }
                              final tab = paneTabs[index];
                              final selected = tab.id == selectedTabId;
                              return _DraggablePaneTab(
                                key: ValueKey(tab.id),
                                tab: tab,
                                paneId: paneId,
                                selected: selected,
                                index: index,
                                onSelect: () {
                                  ref
                                      .read(terminalTabsProvider.notifier)
                                      .focusPane(paneId);
                                  ref
                                      .read(terminalTabsProvider.notifier)
                                      .select(tab.id);
                                },
                                onClose: () => ref
                                    .read(terminalTabsProvider.notifier)
                                    .close(tab.id),
                                onAccept: (data, insertIndex) =>
                                    _acceptTab(ref, data, toIndex: insertIndex),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: 'sessionsSplitRight'.tr(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: _paneTabBarHeight,
                minHeight: _paneTabBarHeight,
              ),
              onPressed: () {
                ref.read(terminalTabsProvider.notifier).focusPane(paneId);
                ref
                    .read(terminalTabsProvider.notifier)
                    .splitEmpty(SessionSplitAxis.horizontal);
              },
              icon: const Icon(Symbols.vertical_split, size: 20),
            ),
            IconButton(
              tooltip: 'sessionsSplitDown'.tr(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: _paneTabBarHeight,
                minHeight: _paneTabBarHeight,
              ),
              onPressed: () {
                ref.read(terminalTabsProvider.notifier).focusPane(paneId);
                ref
                    .read(terminalTabsProvider.notifier)
                    .splitEmpty(SessionSplitAxis.vertical);
              },
              icon: const Icon(Symbols.horizontal_split, size: 20),
            ),
            IconButton(
              tooltip: 'sessionsSessionActions'.tr(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: _paneTabBarHeight,
                minHeight: _paneTabBarHeight,
              ),
              onPressed: () {
                ref.read(terminalTabsProvider.notifier).focusPane(paneId);
                showTerminalCommandPalette(context, ref);
              },
              icon: const Icon(Symbols.add, size: 20),
            ),
            if (showClosePane)
              IconButton(
                tooltip: 'sessionsClosePane'.tr(),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: _paneTabBarHeight,
                  minHeight: _paneTabBarHeight,
                ),
                onPressed: () =>
                    ref.read(terminalTabsProvider.notifier).closePane(paneId),
                icon: const Icon(Symbols.close, size: 18),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _TabDropTail extends StatelessWidget {
  const _TabDropTail({required this.hovering, required this.onAccept});

  final bool hovering;
  final void Function(_TabDragData data) onAccept;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<_TabDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty || hovering;
        return SizedBox(
          width: 28,
          height: _paneTabBarHeight,
          child: active
              ? Align(
                  child: Container(width: 2, height: 20, color: scheme.primary),
                )
              : null,
        );
      },
    );
  }
}

class _DraggablePaneTab extends StatelessWidget {
  const _DraggablePaneTab({
    super.key,
    required this.tab,
    required this.paneId,
    required this.selected,
    required this.index,
    required this.onSelect,
    required this.onClose,
    required this.onAccept,
  });

  final SessionTab tab;
  final String paneId;
  final bool selected;
  final int index;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final void Function(_TabDragData data, int insertIndex) onAccept;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = _PaneTabChip(
      tab: tab,
      selected: selected,
      onSelect: onSelect,
      onClose: onClose,
    );

    return DragTarget<_TabDragData>(
      onWillAcceptWithDetails: (details) => details.data.tabId != tab.id,
      onAcceptWithDetails: (details) {
        // Insert before this tab for stable reordering.
        onAccept(details.data, index);
      },
      builder: (context, candidate, rejected) {
        final showInsert = candidate.isNotEmpty;
        return SizedBox(
          height: _paneTabBarHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showInsert)
                Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: scheme.primary,
                ),
              Draggable<_TabDragData>(
                data: _TabDragData(tabId: tab.id, fromPaneId: paneId),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  elevation: 4,
                  color: scheme.surfaceContainerHighest,
                  child: SizedBox(
                    height: _paneTabBarHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.type == SessionTabType.terminal
                                ? Symbols.terminal
                                : Symbols.folder,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tab.serverName,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: chip),
                child: chip,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaneTabChip extends StatelessWidget {
  const _PaneTabChip({
    required this.tab,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final SessionTab tab;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _paneTabBarHeight,
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons & kMiddleMouseButton != 0) {
            onClose();
          }
        },
        child: InkWell(
          onTap: onSelect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.type == SessionTabType.terminal
                        ? Symbols.terminal
                        : Symbols.folder,
                    size: 16,
                    color: selected ? scheme.primary : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab.serverName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? scheme.primary : null,
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'sessionsCloseTab'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: onClose,
                    icon: const Icon(Symbols.close, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps every tab in the pane mounted so switching/splitting does not reset
/// file-browser or terminal chrome state. [sessionTabViewKey] further preserves
/// that state when a tab moves to another pane or the layout tree reshapes.
class _PaneTabStack extends StatelessWidget {
  const _PaneTabStack({
    required this.paneTabs,
    required this.selectedTabId,
    required this.paneFocused,
  });

  final List<SessionTab> paneTabs;
  final String? selectedTabId;
  final bool paneFocused;

  @override
  Widget build(BuildContext context) {
    if (paneTabs.isEmpty) return const SizedBox.shrink();
    final selectedIndex = paneTabs.indexWhere((tab) => tab.id == selectedTabId);
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    return IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: [
        for (final tab in paneTabs)
          _SessionTabBody(
            tab: tab,
            autofocus: paneFocused && tab.id == selectedTabId,
          ),
      ],
    );
  }
}

class _SessionTabBody extends StatelessWidget {
  const _SessionTabBody({required this.tab, required this.autofocus});

  final SessionTab tab;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    // GlobalKey reparents State when this tab moves across the layout tree
    // (split creation, drag between panes, etc.).
    final key = sessionTabViewKey(tab.id);
    if (tab is FileManagementTab) {
      return FileManagementTabView(key: key, tab: tab as FileManagementTab);
    }
    final terminalTab = tab as TerminalTab;
    return ColoredBox(
      color: const Color(0xFF111315),
      child: ClipRect(
        child: TerminalFindHost(
          key: key,
          adapter: terminalTab.terminal,
          autofocus: autofocus,
        ),
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
        if (session != null) 'commonConnected'.tr() else 'No session',
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

/// Empty-state server picker used for the full workspace and for empty panes.
class _SessionIntro extends StatelessWidget {
  const _SessionIntro({
    required this.servers,
    required this.tabs,
    required this.onOpenTerminal,
    required this.onOpenFiles,
    this.compact = false,
  });

  final AsyncValue<List<Server>> servers;
  final TerminalTabsState tabs;
  final Future<void> Function(Server server) onOpenTerminal;
  final Future<void> Function(Server server) onOpenFiles;
  final bool compact;

  @override
  Widget build(BuildContext context) => servers.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) =>
        Center(child: Text('serversLoadError'.tr(args: [error.toString()]))),
    data: (servers) => servers.isEmpty
        ? Center(
            child: FilledButton.icon(
              onPressed: () => AutoTabsRouter.of(context).setActiveIndex(0),
              icon: const Icon(Symbols.add),
              label: Text('serversAddServer'.tr()),
            ),
          )
        : _TerminalServerGrid(
            servers: servers,
            tabs: tabs,
            compact: compact,
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
    this.compact = false,
  });

  final List<Server> servers;
  final TerminalTabsState tabs;
  final Future<void> Function(Server server) onOpenTerminal;
  final Future<void> Function(Server server) onOpenFiles;
  final bool compact;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: EdgeInsets.all(compact ? 12 : 24),
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: compact ? 320 : 380,
      mainAxisExtent: compact ? 168 : 180,
      mainAxisSpacing: compact ? 12 : 16,
      crossAxisSpacing: compact ? 12 : 16,
    ),
    itemCount: servers.length,
    itemBuilder: (context, index) {
      final server = servers[index];
      final openCount = tabs.tabs
          .where((tab) => tab.serverId == server.id)
          .length;
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.terminal, size: 22),
              const SizedBox(height: 12),
              Text(
                server.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${server.username}@${server.host}:${server.port}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              _ServerCardActions(
                openCount: openCount,
                onOpenTerminal: () => onOpenTerminal(server),
                onOpenFiles: () => onOpenFiles(server),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Action row that collapses to icon buttons when the card is narrow (split panes).
class _ServerCardActions extends StatelessWidget {
  const _ServerCardActions({
    required this.openCount,
    required this.onOpenTerminal,
    required this.onOpenFiles,
  });

  final int openCount;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenFiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Split panes often leave cards under ~260px — use icon-only actions.
        final narrow = constraints.maxWidth < 260;
        if (narrow) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  'sessionsOpenCount'.tr(args: ['$openCount']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
               IconButton.filledTonal(
                 tooltip: 'sessionsNewTerminal'.tr(),
                 visualDensity: VisualDensity.compact,
                 onPressed: onOpenTerminal,
                 icon: const Icon(Symbols.add, size: 20),
               ),
               IconButton(
                 tooltip: 'sessionsOpenFileManagement'.tr(),
                 visualDensity: VisualDensity.compact,
                 onPressed: onOpenFiles,
                 icon: const Icon(Symbols.folder, size: 20),
               ),
            ],
          );
        }
        return Row(
          children: [
            Text(
              'sessionsOpenCount'.tr(args: ['$openCount']),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: onOpenTerminal,
              icon: const Icon(Symbols.add),
              label: Text('sessionsNewTerminal'.tr()),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'sessionsOpenFileManagement'.tr(),
              onPressed: onOpenFiles,
              icon: const Icon(Symbols.folder),
            ),
          ],
        );
      },
    );
  }
}
