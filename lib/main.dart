import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'servers/server_providers.dart';
import 'servers/metrics_refresh_preferences.dart';
import 'servers/terminal_adapter_preferences.dart';
import 'servers/startup_connection_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  final preferences = await Future.wait([
    TerminalAdapterPreferences.load(),
    StartupConnectionPreferences.load(),
    MetricsRefreshPreferences.load(),
  ]);
  final terminalAdapterPreferences =
      preferences[0] as TerminalAdapterPreferences;
  final startupConnectionPreferences =
      preferences[1] as StartupConnectionPreferences;
  final metricsRefreshPreferences = preferences[2] as MetricsRefreshPreferences;

  if (DesktopWindowFrame.isPlatformDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(720, 520),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        terminalAdapterPreferencesProvider.overrideWithValue(
          terminalAdapterPreferences,
        ),
        startupConnectionSettingsProvider.overrideWithValue(
          startupConnectionPreferences,
        ),
        metricsRefreshSettingsProvider.overrideWithValue(
          metricsRefreshPreferences,
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('zh', 'CN'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        useFallbackTranslations: true,
        child: const MaidKitApp(),
      ),
    ),
  );
}
