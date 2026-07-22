import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/shared/presentation/deploy_terminal.dart';
import 'port_forwarding_models.dart';
import 'server_providers.dart';

@RoutePage()
class ServerWorkspacePage extends StatelessWidget {
  const ServerWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [
        ServersRoute(),
        ProjectsRoute(),
        SnippetsRoute(),
        SettingsRoute(),
      ],
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transitionBuilder: (context, child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      builder: (context, child) => _ServerTabsShell(child: child),
    );
  }
}

class _ServerTabsShell extends ConsumerWidget {
  const _ServerTabsShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      selectedIndex: tabsRouter.activeIndex < 3
                          ? tabsRouter.activeIndex
                          : null,
                      onDestinationSelected: tabsRouter.setActiveIndex,
                      trailingAtBottom: true,
                      trailing: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _PortForwardRailIndicator(),
                            const SizedBox(height: 8),
                            const DeploySessionsRailButton(),
                            IconButton(
                              tooltip: 'tabSettings'.tr(),
                              onPressed: () => tabsRouter.setActiveIndex(3),
                              icon: const Icon(Symbols.settings),
                            ),
                          ],
                        ),
                      ),
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Symbols.dns),
                          selectedIcon: const Icon(Symbols.dns, fill: 1),
                          label: Text('tabServers').tr(),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Symbols.deployed_code),
                          selectedIcon: const Icon(
                            Symbols.deployed_code,
                            fill: 1,
                          ),
                          label: Text('tabProjects').tr(),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Symbols.code),
                          selectedIcon: const Icon(Symbols.code, fill: 1),
                          label: Text('tabSnippets').tr(),
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
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Symbols.dns),
                      selectedIcon: const Icon(Symbols.dns, fill: 1),
                      label: 'tabServers'.tr(),
                    ),
                    NavigationDestination(
                      icon: const Icon(Symbols.deployed_code),
                      selectedIcon: const Icon(Symbols.deployed_code, fill: 1),
                      label: 'tabProjects'.tr(),
                    ),
                    NavigationDestination(
                      icon: const Icon(Symbols.code),
                      selectedIcon: const Icon(Symbols.code, fill: 1),
                      label: 'tabSnippets'.tr(),
                    ),
                    NavigationDestination(
                      icon: const Icon(Symbols.settings, fill: 1),
                      selectedIcon: const Icon(Symbols.settings),
                      label: 'tabSettings'.tr(),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PortForwardRailIndicator extends ConsumerWidget {
  const _PortForwardRailIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forwards = ref.watch(portForwardsProvider).asData?.value ?? const [];
    if (forwards.isEmpty) return const SizedBox.shrink();
    return Badge(
      label: Text('portForwardCount').tr(args: ['${forwards.length}']),
      child: PopupMenuButton<ActivePortForward>(
        tooltip: 'activePortForwards'.plural(forwards.length),
        icon: const Icon(Symbols.swap_horiz),
        onSelected: (forward) =>
            ref.read(connectionManagerProvider).stopPortForward(forward.id),
        itemBuilder: (context) => [
          for (final forward in forwards)
            PopupMenuItem(
              value: forward,
              child: SizedBox(
                width: 260,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.swap_horiz),
                  title: Text(forward.serverName),
                  subtitle: Text(forward.summary),
                  trailing: const Icon(Symbols.stop_circle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
