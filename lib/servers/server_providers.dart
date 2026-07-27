import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/shared/presentation/app_scaffold.dart';
import 'ghostty_terminal_session_adapter.dart';
import 'metrics_refresh_preferences.dart';
import 'port_forwarding_models.dart';
import 'server_repository.dart';
import 'server_metrics_refresh_scheduler.dart';
import 'ssh_connection_manager.dart';
import 'server_models.dart';
import 'terminal_session_adapter.dart';
import 'terminal_adapter_preferences.dart';
import 'terminal_color_scheme.dart';
import 'startup_connection_preferences.dart';
import 'vault_service.dart';
import 'vault_file_storage.dart';

final vaultFileStorageProvider = Provider<VaultFileStorage>(
  (ref) => VaultFileStorage(),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(filePath: ref.watch(activeVaultFileProvider));
  ref.onDispose(database.close);
  return database;
});

const _activeVaultFilePreference = 'active_vault_file';
const _vaultFilesPreference = 'vault_files';

/// The database file backing the currently selected vault. A null value keeps
/// using the original MaidKit database so existing users migrate seamlessly.
final activeVaultFileProvider =
    NotifierProvider<ActiveVaultFileNotifier, String?>(
      ActiveVaultFileNotifier.new,
    );

class ActiveVaultFileNotifier extends Notifier<String?> {
  @override
  String? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final path = preferences.getString(_activeVaultFilePreference);
    if (path != null && path.isNotEmpty) {
      try {
        final managedPath = await ref
            .read(vaultFileStorageProvider)
            .importVault(path);
        await ref.read(vaultFilesProvider.notifier).remember(managedPath);
        state = managedPath;
        await preferences.setString(_activeVaultFilePreference, managedPath);
      } on FileSystemException {
        await preferences.remove(_activeVaultFilePreference);
      }
    }
  }

  Future<void> select(String? path) async {
    if (path != null) {
      await ref.read(vaultFilesProvider.notifier).remember(path);
    }
    state = path;
    final preferences = await SharedPreferences.getInstance();
    if (path == null) {
      await preferences.remove(_activeVaultFilePreference);
    } else {
      await preferences.setString(_activeVaultFilePreference, path);
    }
  }
}

/// Vault database files known to MaidKit. The original app database is a
/// separate built-in option and is therefore not included in this list.
final vaultFilesProvider = NotifierProvider<VaultFilesNotifier, List<String>>(
  VaultFilesNotifier.new,
);

class VaultFilesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_vaultFilesPreference) ?? const [];
    final managedPaths = <String>[];
    for (final path in stored) {
      try {
        final managedPath = await ref
            .read(vaultFileStorageProvider)
            .importVault(path);
        if (!managedPaths.contains(managedPath)) managedPaths.add(managedPath);
      } on FileSystemException {
        // Missing external files from older versions are no longer selectable.
      }
    }
    state = [
      ...managedPaths,
      ...state.where((path) => !managedPaths.contains(path)),
    ];
    await preferences.setStringList(_vaultFilesPreference, state);
  }

  Future<void> remember(String path) async {
    state = [path, ...state.where((value) => value != path)];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_vaultFilesPreference, state);
  }
}

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(
    ref.watch(databaseProvider),
    ref.watch(vaultServiceProvider),
  );
});

final savedCredentialsProvider = StreamProvider<List<SavedCredential>>((ref) {
  return ref.watch(serverRepositoryProvider).watchCredentials();
});

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService(
    ref.watch(databaseProvider),
    vaultId: ref.watch(activeVaultFileProvider) ?? 'maid_kit',
  );
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
      final colorScheme = ref.watch(terminalColorSchemeProvider);
      final transparentBackground = ref.watch(
        transparentTerminalBackgroundProvider,
      );
      return [
        TerminalSessionAdapterOption(
          id: 'ghostty',
          label: 'Ghostty',
          description: 'The default libghostty-vt renderer for new terminals.',
          factory: GhosttyTerminalSessionAdapterFactory(
            cursorAnimationEnabled: cursorAnimationEnabled,
            colorScheme: colorScheme,
            transparentBackground: transparentBackground,
          ),
        ),
        TerminalSessionAdapterOption(
          id: 'xterm',
          label: 'xterm',
          description: 'The built-in Flutter fallback renderer.',
          factory: XtermTerminalSessionAdapterFactory(
            colorScheme: colorScheme,
            transparentBackground: transparentBackground,
          ),
        ),
      ];
    });

final terminalAdapterPreferencesProvider = Provider<TerminalAdapterSettings>(
  (ref) => InMemoryTerminalAdapterSettings(),
);

final startupConnectionSettingsProvider = Provider<StartupConnectionSettings>(
  (ref) => InMemoryStartupConnectionSettings(),
);

final metricsRefreshSettingsProvider = Provider<MetricsRefreshSettings>(
  (ref) => InMemoryMetricsRefreshSettings(),
);

final serverMetricsRefreshIntervalProvider =
    NotifierProvider<ServerMetricsRefreshIntervalNotifier, Duration>(
      ServerMetricsRefreshIntervalNotifier.new,
    );

class ServerMetricsRefreshIntervalNotifier extends Notifier<Duration> {
  @override
  Duration build() =>
      ref.read(metricsRefreshSettingsProvider).backgroundInterval;

  Future<void> setInterval(Duration value) async {
    await ref
        .read(metricsRefreshSettingsProvider)
        .saveBackgroundInterval(value);
    state = value;
  }
}

final focusedServerRefreshIntervalProvider =
    NotifierProvider<FocusedServerRefreshIntervalNotifier, Duration>(
      FocusedServerRefreshIntervalNotifier.new,
    );

class FocusedServerRefreshIntervalNotifier extends Notifier<Duration> {
  @override
  Duration build() => ref.read(metricsRefreshSettingsProvider).focusedInterval;

  Future<void> setInterval(Duration value) async {
    await ref.read(metricsRefreshSettingsProvider).saveFocusedInterval(value);
    state = value;
  }
}

final focusedServerIdProvider = NotifierProvider<FocusedServerNotifier, int?>(
  FocusedServerNotifier.new,
);

class FocusedServerNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void focus(int serverId) => state = serverId;

  void clear(int serverId) {
    if (state == serverId) state = null;
  }
}

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

final terminalBrandingEnvironmentEnabledProvider =
    NotifierProvider<TerminalBrandingEnvironmentEnabledNotifier, bool>(
      TerminalBrandingEnvironmentEnabledNotifier.new,
    );

class TerminalBrandingEnvironmentEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(terminalAdapterPreferencesProvider).brandingEnvironmentEnabled;

  Future<void> setEnabled(bool enabled) async {
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveBrandingEnvironmentEnabled(enabled);
    state = enabled;
  }
}

final terminalColorSchemeProvider =
    NotifierProvider<TerminalColorSchemeNotifier, TerminalColorScheme>(
      TerminalColorSchemeNotifier.new,
    );

class TerminalColorSchemeNotifier extends Notifier<TerminalColorScheme> {
  @override
  TerminalColorScheme build() => TerminalColorSchemes.byId(
    ref.read(terminalAdapterPreferencesProvider).colorSchemeId,
  );

  Future<void> select(String colorSchemeId) async {
    final scheme = TerminalColorSchemes.byId(colorSchemeId);
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveColorSchemeId(scheme.id);
    state = scheme;
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
    brandingEnvironmentEnabled: () =>
        ref.read(terminalBrandingEnvironmentEnabledProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final sessionsProvider = StreamProvider<List<SshSessionInfo>>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return _watchSessions(manager);
});

final portForwardsProvider = StreamProvider<List<ActivePortForward>>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return _watchPortForwards(manager);
});

Stream<List<ActivePortForward>> _watchPortForwards(
  SshConnectionManager manager,
) async* {
  yield manager.currentPortForwards;
  yield* manager.portForwards;
}

Stream<List<SshSessionInfo>> _watchSessions(
  SshConnectionManager manager,
) async* {
  yield manager.current;
  yield* manager.sessions;
}

final serversProvider = StreamProvider<List<Server>>((ref) {
  return ref.watch(serverRepositoryProvider).watchAll();
});

final serverMetricsRefreshSchedulerProvider =
    Provider<ServerMetricsRefreshScheduler>((ref) {
      final scheduler = ServerMetricsRefreshScheduler(
        ref.watch(connectionManagerProvider),
      );
      final interval = ref.watch(serverMetricsRefreshIntervalProvider);
      final focusedServerId = ref.watch(focusedServerIdProvider);
      final servers =
          ref.watch(serversProvider).asData?.value ?? const <Server>[];
      final sessions =
          ref.watch(sessionsProvider).asData?.value ?? const <SshSessionInfo>[];
      scheduler.update(
        interval: interval,
        servers: servers,
        sessions: sessions,
        focusedServerId: focusedServerId,
      );
      ref.onDispose(scheduler.dispose);
      return scheduler;
    });
