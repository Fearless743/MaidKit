import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      title: 'title'.tr(),
      debugShowCheckedModeBanner: false,
      theme: createMaidKitTheme(Brightness.light),
      darkTheme: createMaidKitTheme(Brightness.dark),
      themeMode: themeMode,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter.config(),
      builder: (context, child) => Overlay(
        key: maidKitOverlayKey,
        initialEntries: [
          OverlayEntry(
            builder: (context) => MaidKitWindowScaffold(
              title: 'title'.tr(),
              // The gate needs a Navigator for standard Material controls
              // such as a dropdown. The app router remains below it and is
              // only exposed once the vault unlocks.
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (context) => VaultGate(
                    child: StartupConnectionBootstrap(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
