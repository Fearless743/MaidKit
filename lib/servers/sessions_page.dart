import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:xterm/xterm.dart';

import 'server_models.dart';
import 'server_providers.dart';

@RoutePage()
class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  int? _selectedServerId;
  Terminal? _terminal;
  String? _terminalError;
  bool _openingTerminal = false;

  Future<void> _openTerminal(SshSessionInfo session) async {
    setState(() {
      _selectedServerId = session.serverId;
      _terminal = null;
      _terminalError = null;
      _openingTerminal = true;
    });
    try {
      final terminal = await ref
          .read(connectionManagerProvider)
          .openTerminal(session.serverId);
      if (mounted) setState(() => _terminal = terminal);
    } catch (error) {
      if (mounted) setState(() => _terminalError = error.toString());
    } finally {
      if (mounted) setState(() => _openingTerminal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: sessions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Could not load sessions: $error')),
          data: (items) =>
              items
                  .where((item) => item.status == SessionStatus.connected)
                  .isEmpty
              ? const Center(
                  child: Text(
                    'Connect to a server to open an interactive terminal.',
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final terminalPane = _TerminalPane(
                      terminal: _terminal,
                      opening: _openingTerminal,
                      error: _terminalError,
                      title: items
                          .where((item) => item.serverId == _selectedServerId)
                          .firstOrNull
                          ?.serverName,
                    );
                    final sessionList = _SessionList(
                      sessions: items,
                      selectedServerId: _selectedServerId,
                      onOpen: _openTerminal,
                      onDisconnect: (id) =>
                          ref.read(connectionManagerProvider).disconnect(id),
                    );
                    return constraints.maxWidth > 768
                        ? Row(
                            children: [
                              SizedBox(width: 260, child: sessionList),
                              const VerticalDivider(width: 25),
                              Expanded(child: terminalPane),
                            ],
                          )
                        : Column(
                            children: [
                              SizedBox(height: 160, child: sessionList),
                              const SizedBox(height: 12),
                              Expanded(child: terminalPane),
                            ],
                          );
                  },
                ),
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.selectedServerId,
    required this.onOpen,
    required this.onDisconnect,
  });
  final List<SshSessionInfo> sessions;
  final int? selectedServerId;
  final ValueChanged<SshSessionInfo> onOpen;
  final ValueChanged<int> onDisconnect;

  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: sessions.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final session = sessions[index];
      final connected = session.status == SessionStatus.connected;
      return ListTile(
        selected: session.serverId == selectedServerId,
        onTap: connected ? () => onOpen(session) : null,
        leading: Icon(connected ? Icons.terminal : Icons.link_off),
        title: Text(session.serverName),
        subtitle: Text(session.error ?? session.status.name),
        trailing: connected
            ? IconButton(
                tooltip: 'Disconnect',
                onPressed: () => onDisconnect(session.serverId),
                icon: const Icon(Icons.link_off),
              )
            : null,
      );
    },
  );
}

class _TerminalPane extends StatelessWidget {
  const _TerminalPane({
    required this.terminal,
    required this.opening,
    required this.error,
    this.title,
  });
  final Terminal? terminal;
  final bool opening;
  final String? error;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (opening) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text('Could not open terminal: $error'));
    }
    if (terminal == null) {
      return const Center(
        child: Text('Select a connected server to open its terminal.'),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  title ?? 'Terminal',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(
            child: TerminalView(
              terminal!,
              autofocus: true,
              backgroundOpacity: 0,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
