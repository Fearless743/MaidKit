import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_router.gr.dart';

final appRouterProvider = Provider<AppRouter>((ref) => AppRouter());

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: ServerWorkspaceRoute.page,
      initial: true,
      children: [
        AutoRoute(page: ServersRoute.page, path: '', initial: true),
        AutoRoute(page: SessionsRoute.page, path: 'sessions'),
        AutoRoute(page: SettingsRoute.page, path: 'settings'),
      ],
    ),
    AutoRoute(page: ServerDetailRoute.page, path: '/server-detail'),
  ];
}
