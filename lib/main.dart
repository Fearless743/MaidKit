import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'servers/server_providers.dart';
import 'servers/terminal_adapter_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final terminalAdapterPreferences = await TerminalAdapterPreferences.load();

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
      ],
      child: const MaidKitApp(),
    ),
  );
}
