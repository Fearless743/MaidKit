import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../routing/app_router.gr.dart';

@RoutePage()
class ServerWorkspacePage extends StatelessWidget {
  const ServerWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [ServersRoute(), SessionsRoute(), SettingsRoute()],
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transitionBuilder: (context, child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      builder: (context, child) => _ServerTabsShell(child: child),
    );
  }
}

class _ServerTabsShell extends StatelessWidget {
  const _ServerTabsShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tabsRouter = AutoTabsRouter.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 768;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: tabsRouter.activeIndex < 2
                          ? tabsRouter.activeIndex
                          : null,
                      onDestinationSelected: tabsRouter.setActiveIndex,
                      trailingAtBottom: true,
                      trailing: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(
                          tooltip: 'Settings',
                          onPressed: () => tabsRouter.setActiveIndex(2),
                          icon: const Icon(Symbols.settings),
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Symbols.dns),
                          selectedIcon: Icon(Symbols.dns, fill: 1),
                          label: Text('Servers'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Symbols.terminal),
                          selectedIcon: Icon(Symbols.terminal, fill: 1),
                          label: Text('Sessions'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                        ),
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: child,
                        ),
                      ),
                    ),
                  ],
                )
              : child,
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  height: 56,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  selectedIndex: tabsRouter.activeIndex,
                  onDestinationSelected: tabsRouter.setActiveIndex,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Symbols.dns),
                      selectedIcon: Icon(Symbols.dns, fill: 1),
                      label: 'Servers',
                    ),
                    NavigationDestination(
                      icon: Icon(Symbols.terminal, fill: 1),
                      selectedIcon: Icon(Symbols.terminal),
                      label: 'Sessions',
                    ),
                    NavigationDestination(
                      icon: Icon(Symbols.settings, fill: 1),
                      selectedIcon: Icon(Symbols.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
