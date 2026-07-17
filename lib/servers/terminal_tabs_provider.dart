import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'server_providers.dart';
import 'terminal_session_adapter.dart';

class TerminalTab {
  const TerminalTab({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.terminal,
  });

  final String id;
  final int serverId;
  final String serverName;
  final TerminalSessionAdapter terminal;
}

class TerminalTabsState {
  const TerminalTabsState({this.tabs = const [], this.selectedId});

  final List<TerminalTab> tabs;
  final String? selectedId;

  int get selectedIndex {
    final index = tabs.indexWhere((tab) => tab.id == selectedId);
    return index < 0 ? 0 : index;
  }
}

final terminalTabsProvider =
    NotifierProvider<TerminalTabsNotifier, TerminalTabsState>(
      TerminalTabsNotifier.new,
    );

/// Holds live terminal tabs for the entire app lifetime.
///
/// This provider deliberately is not auto-disposed, so terminals continue to
/// receive output while the user visits another workspace page.
class TerminalTabsNotifier extends Notifier<TerminalTabsState> {
  @override
  TerminalTabsState build() => const TerminalTabsState();

  Future<void> open(int serverId, String serverName) async {
    final handle = await ref
        .read(connectionManagerProvider)
        .openTerminal(serverId);
    final tab = TerminalTab(
      id: handle.id,
      serverId: serverId,
      serverName: serverName,
      terminal: handle.adapter,
    );
    state = TerminalTabsState(tabs: [...state.tabs, tab], selectedId: tab.id);
    unawaited(
      handle.done.then<void>(
        (_) => _remove(handle.id),
        onError: (_, _) => _remove(handle.id),
      ),
    );
  }

  void select(String terminalId) {
    if (state.tabs.any((tab) => tab.id == terminalId)) {
      state = TerminalTabsState(tabs: state.tabs, selectedId: terminalId);
    }
  }

  Future<void> close(String terminalId) async {
    await ref.read(connectionManagerProvider).closeTerminal(terminalId);
    _remove(terminalId);
  }

  Future<void> closeForServer(int serverId) async {
    final terminalIds = state.tabs
        .where((tab) => tab.serverId == serverId)
        .map((tab) => tab.id)
        .toList();
    await Future.wait(terminalIds.map(close));
  }

  void _remove(String terminalId) {
    final oldTabs = state.tabs;
    final index = oldTabs.indexWhere((tab) => tab.id == terminalId);
    if (index < 0) return;
    final tabs = [...oldTabs]..removeAt(index);
    final selectedId = state.selectedId == terminalId
        ? (tabs.isEmpty ? null : tabs[index.clamp(0, tabs.length - 1)].id)
        : state.selectedId;
    state = TerminalTabsState(tabs: tabs, selectedId: selectedId);
  }
}
