import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';

import 'routing/app_router.dart';
import 'shared/presentation/maidkit_window_scaffold.dart';
import 'servers/server_providers.dart';
import 'servers/startup_connection_bootstrap.dart';
import 'servers/vault_gate.dart';
import 'theme.dart';

final maidKitOverlayKey = GlobalKey<OverlayState>();

class MaidKitApp extends ConsumerWidget {
  const MaidKitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(serverMetricsRefreshSchedulerProvider);
    IslandUIFoundation.configureOverlay(maidKitOverlayKey);
    IslandUIFoundation.configureNavigator(maidKitNavigatorKey);
    return MaterialApp.router(
      title: 'MaidKit',
      debugShowCheckedModeBanner: false,
      theme: createMaidKitTheme(Brightness.light),
      darkTheme: createMaidKitTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter.config(),
      builder: (context, child) => Overlay(
        key: maidKitOverlayKey,
        initialEntries: [
          OverlayEntry(
            builder: (context) => MaidKitWindowScaffold(
              child: VaultGate(
                child: StartupConnectionBootstrap(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
