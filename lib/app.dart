import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'routing/app_router.dart';
import 'shared/presentation/maidkit_window_scaffold.dart';

class MaidKitApp extends ConsumerWidget {
  const MaidKitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);
    const seedColor = Color(0xFF0F766E);

    return MaterialApp.router(
      title: 'MaidKit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
        navigationRailTheme: const NavigationRailThemeData(
          groupAlignment: -1,
          labelType: NavigationRailLabelType.all,
        ),
      ),
      routerConfig: appRouter.config(),
      builder: (context, child) =>
          MaidKitWindowScaffold(child: child ?? const SizedBox.shrink()),
    );
  }
}
