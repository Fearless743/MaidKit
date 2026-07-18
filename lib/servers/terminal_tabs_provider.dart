import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'ssh_connection_manager.dart';
import 'terminal_session_adapter.dart';

enum SessionTabType { terminal, fileManagement }

sealed class SessionTab {
  const SessionTab({
    required this.id,
    required this.serverId,
    required this.serverName,
  });

  final String id;
  final int serverId;
  final String serverName;
  SessionTabType get type;
}

class TerminalTab extends SessionTab {
  const TerminalTab({
    required super.id,
    required super.serverId,
    required super.serverName,
    required this.terminal,
  });

  final TerminalSessionAdapter terminal;

  @override
  SessionTabType get type => SessionTabType.terminal;
}

class FileManagementTab extends SessionTab {
  const FileManagementTab({
    required super.id,
    required super.serverId,
    required super.serverName,
  });

  @override
  SessionTabType get type => SessionTabType.fileManagement;
}

class TerminalTabsState {
  const TerminalTabsState({this.tabs = const [], this.selectedId});

  final List<SessionTab> tabs;
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

  Future<void> open(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    String? initialDirectory,
  }) async {
    final handle = await ref
        .read(connectionManagerProvider)
        .openTerminal(
          server,
          credential,
          approve,
          knownHostKeyFingerprint: knownHostKeyFingerprint,
          initialDirectory: initialDirectory,
        );
    final tab = TerminalTab(
      id: handle.id,
      serverId: server.id,
      serverName: server.name,
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

  void openFileManagement(Server server) {
    final tab = FileManagementTab(
      id: 'files-${DateTime.now().microsecondsSinceEpoch}',
      serverId: server.id,
      serverName: server.name,
    );
    state = TerminalTabsState(tabs: [...state.tabs, tab], selectedId: tab.id);
  }

  void select(String terminalId) {
    if (state.tabs.any((tab) => tab.id == terminalId)) {
      state = TerminalTabsState(tabs: state.tabs, selectedId: terminalId);
    }
  }

  Future<void> close(String terminalId) async {
    final tab = state.tabs.where((tab) => tab.id == terminalId).firstOrNull;
    if (tab is TerminalTab) {
      await ref.read(connectionManagerProvider).closeTerminal(terminalId);
    }
    _remove(terminalId);
  }

  Future<void> closeForServer(int serverId) async {
    final tabIds = state.tabs
        .where((tab) => tab.serverId == serverId)
        .map((tab) => tab.id)
        .toList();
    await Future.wait(tabIds.map(close));
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
