import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/shared/presentation/maidkit_alert.dart';
import 'server_connection_actions.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

Future<void> showTerminalCommandPalette(BuildContext context, WidgetRef ref) {
  final tabs = ref.read(terminalTabsProvider);
  final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
  final activeTab = tabs.tabs.isEmpty ? null : tabs.tabs[tabs.selectedIndex];
  return showMaidKitCommandPalette<void>(
    builder: (context, close) => _TerminalCommandPalette(
      activeTab: activeTab,
      servers: servers,
      onDismiss: () => close(null),
      onOpen: (server) async {
        await openTerminalSession(context, ref, server);
        close(null);
      },
      onClose: activeTab == null
          ? null
          : () async {
              await ref.read(terminalTabsProvider.notifier).close(activeTab.id);
              close(null);
            },
      onDisconnect: activeTab == null
          ? null
          : () async {
              await ref
                  .read(terminalTabsProvider.notifier)
                  .closeForServer(activeTab.serverId);
              close(null);
            },
    ),
  );
}

class _TerminalCommandPalette extends StatefulWidget {
  const _TerminalCommandPalette({
    required this.activeTab,
    required this.servers,
    required this.onDismiss,
    required this.onOpen,
    required this.onClose,
    required this.onDisconnect,
  });

  final SessionTab? activeTab;
  final List<Server> servers;
  final VoidCallback onDismiss;
  final Future<void> Function(Server server) onOpen;
  final Future<void> Function()? onClose;
  final Future<void> Function()? onDisconnect;

  @override
  State<_TerminalCommandPalette> createState() =>
      _TerminalCommandPaletteState();
}

class _TerminalCommandPaletteState extends State<_TerminalCommandPalette> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final activeTab = widget.activeTab;
    final activeServer = activeTab == null
        ? null
        : widget.servers
              .where((server) => server.id == activeTab.serverId)
              .firstOrNull;
    final actions = [
      if (activeServer != null)
        _TerminalAction(
          label: 'New terminal on ${activeTab!.serverName}',
          icon: Symbols.add,
          onSelect: () => widget.onOpen(activeServer),
        ),
      if (widget.onClose != null)
        _TerminalAction(
          label: 'Close this terminal',
          icon: Symbols.close,
          onSelect: widget.onClose!,
        ),
      if (widget.onDisconnect != null)
        _TerminalAction(
          label: 'Close all terminals on ${activeTab!.serverName}',
          icon: Symbols.link_off,
          onSelect: widget.onDisconnect!,
        ),
      for (final server in widget.servers)
        if (server.id != activeTab?.serverId)
          _TerminalAction(
            label: 'New terminal on ${server.name}',
            icon: Symbols.terminal,
            onSelect: () => widget.onOpen(server),
          ),
    ].where((action) => action.label.toLowerCase().contains(query)).toList();

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onDismiss();
              return null;
            },
          ),
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Search terminal actions',
              leading: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  child: const Icon(Symbols.keyboard_command_key),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: actions.isEmpty
                  ? const SizedBox.shrink()
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          return ListTile(
                            leading: Icon(action.icon),
                            title: Text(action.label),
                            onTap: () => action.onSelect(),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalAction {
  const _TerminalAction({
    required this.label,
    required this.icon,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onSelect;
}
