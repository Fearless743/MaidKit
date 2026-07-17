// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i4;
import 'package:maid_kit/servers/server_workspace_page.dart' as _i1;
import 'package:maid_kit/servers/servers_page.dart' as _i2;
import 'package:maid_kit/servers/sessions_page.dart' as _i3;

/// generated route for
/// [_i1.ServerWorkspacePage]
class ServerWorkspaceRoute extends _i4.PageRouteInfo<void> {
  const ServerWorkspaceRoute({List<_i4.PageRouteInfo>? children})
    : super(ServerWorkspaceRoute.name, initialChildren: children);

  static const String name = 'ServerWorkspaceRoute';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      return const _i1.ServerWorkspacePage();
    },
  );
}

/// generated route for
/// [_i2.ServersPage]
class ServersRoute extends _i4.PageRouteInfo<void> {
  const ServersRoute({List<_i4.PageRouteInfo>? children})
    : super(ServersRoute.name, initialChildren: children);

  static const String name = 'ServersRoute';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      return const _i2.ServersPage();
    },
  );
}

/// generated route for
/// [_i3.SessionsPage]
class SessionsRoute extends _i4.PageRouteInfo<void> {
  const SessionsRoute({List<_i4.PageRouteInfo>? children})
    : super(SessionsRoute.name, initialChildren: children);

  static const String name = 'SessionsRoute';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      return const _i3.SessionsPage();
    },
  );
}
