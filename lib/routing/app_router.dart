import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_router.gr.dart';

final maidKitNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<AppRouter>(
  (ref) => AppRouter(navigatorKey: maidKitNavigatorKey),
);

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey});

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: ServerWorkspaceRoute.page,
      initial: true,
      children: [
        AutoRoute(page: ServersRoute.page, path: '', initial: true),
        AutoRoute(page: AssetsRoute.page, path: 'assets'),
        AutoRoute(page: ProjectsRoute.page, path: 'projects'),
        AutoRoute(page: SnippetsRoute.page, path: 'snippets'),
        AutoRoute(page: AgentRoute.page, path: 'agent'),
        AutoRoute(page: GitHubRoute.page, path: 'github'),
        AutoRoute(page: SettingsRoute.page, path: 'settings'),
      ],
    ),
    AutoRoute(page: ServerDetailRoute.page, path: '/server-detail'),
    AutoRoute(page: GitHubRunDetailRoute.page, path: '/github-run-detail'),
    AutoRoute(page: ProjectDetailRoute.page, path: '/project-detail'),
    AutoRoute(page: ContainerDetailRoute.page, path: '/container-detail'),
    AutoRoute(page: ComposeDetailRoute.page, path: '/compose-detail'),
    AutoRoute(page: AboutRoute.page, path: '/about'),
  ];
}
