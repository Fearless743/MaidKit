import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/local/app_database.dart';
import 'ghostty_terminal_session_adapter.dart';
import 'server_repository.dart';
import 'ssh_connection_manager.dart';
import 'server_models.dart';
import 'terminal_session_adapter.dart';
import 'terminal_adapter_preferences.dart';
import 'startup_connection_preferences.dart';
import 'vault_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(
    ref.watch(databaseProvider),
    ref.watch(vaultServiceProvider),
  );
});

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService(ref.watch(databaseProvider));
});

final vaultExistsProvider = FutureProvider<bool>((ref) {
  return ref.watch(vaultServiceProvider).hasVault();
});

final biometricUnlockEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(vaultServiceProvider).isBiometricUnlockEnabled();
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) => state = mode;
}

final terminalSessionAdapterOptionsProvider =
    Provider<List<TerminalSessionAdapterOption>>((ref) {
      final cursorAnimationEnabled = ref.watch(cursorAnimationEnabledProvider);
      return [
        TerminalSessionAdapterOption(
          id: 'ghostty',
          label: 'Ghostty',
          description: 'The default libghostty-vt renderer for new terminals.',
          factory: GhosttyTerminalSessionAdapterFactory(
            cursorAnimationEnabled: cursorAnimationEnabled,
          ),
        ),
        TerminalSessionAdapterOption(
          id: 'xterm',
          label: 'xterm',
          description: 'The built-in Flutter fallback renderer.',
          factory: XtermTerminalSessionAdapterFactory(),
        ),
      ];
    });

final terminalAdapterPreferencesProvider = Provider<TerminalAdapterSettings>(
  (ref) => InMemoryTerminalAdapterSettings(),
);

final startupConnectionSettingsProvider = Provider<StartupConnectionSettings>(
  (ref) => InMemoryStartupConnectionSettings(),
);

final connectOnStartupProvider =
    NotifierProvider<ConnectOnStartupNotifier, bool>(
      ConnectOnStartupNotifier.new,
    );

class ConnectOnStartupNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(startupConnectionSettingsProvider).connectOnStartup;

  Future<void> setEnabled(bool value) async {
    await ref
        .read(startupConnectionSettingsProvider)
        .saveConnectOnStartup(value);
    state = value;
  }
}

final selectedTerminalSessionAdapterProvider =
    NotifierProvider<SelectedTerminalSessionAdapterNotifier, String>(
      SelectedTerminalSessionAdapterNotifier.new,
    );

class SelectedTerminalSessionAdapterNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.read(terminalAdapterPreferencesProvider).selectedAdapterId;

  Future<void> select(String adapterId) async {
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveSelectedAdapterId(adapterId);
    state = adapterId;
  }
}

final cursorAnimationEnabledProvider =
    NotifierProvider<CursorAnimationEnabledNotifier, bool>(
      CursorAnimationEnabledNotifier.new,
    );

class CursorAnimationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(terminalAdapterPreferencesProvider).cursorAnimationEnabled;

  Future<void> setEnabled(bool enabled) async {
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveCursorAnimationEnabled(enabled);
    state = enabled;
  }
}

final terminalSessionAdapterFactoryProvider =
    Provider<TerminalSessionAdapterFactory>((ref) {
      final options = ref.watch(terminalSessionAdapterOptionsProvider);
      final selectedId = ref.watch(selectedTerminalSessionAdapterProvider);
      return options
              .where((option) => option.id == selectedId)
              .firstOrNull
              ?.factory ??
          options.first.factory;
    });

final connectionManagerProvider = Provider<SshConnectionManager>((ref) {
  final manager = SshConnectionManager(
    () => ref.read(terminalSessionAdapterFactoryProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final sessionsProvider = StreamProvider<List<SshSessionInfo>>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return _watchSessions(manager);
});

Stream<List<SshSessionInfo>> _watchSessions(
  SshConnectionManager manager,
) async* {
  yield manager.current;
  yield* manager.sessions;
}

final serversProvider = StreamProvider<List<Server>>((ref) {
  return ref.watch(serverRepositoryProvider).watchAll();
});
