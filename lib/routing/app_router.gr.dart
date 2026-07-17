// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i6;
import 'package:flutter/material.dart' as _i7;
import 'package:maid_kit/data/local/app_database.dart' as _i8;
import 'package:maid_kit/servers/server_detail_page.dart' as _i1;
import 'package:maid_kit/servers/server_workspace_page.dart' as _i2;
import 'package:maid_kit/servers/servers_page.dart' as _i3;
import 'package:maid_kit/servers/sessions_page.dart' as _i4;
import 'package:maid_kit/servers/settings_page.dart' as _i5;

/// generated route for
/// [_i1.ServerDetailPage]
class ServerDetailRoute extends _i6.PageRouteInfo<ServerDetailRouteArgs> {
  ServerDetailRoute({
    _i7.Key? key,
    required _i8.Server server,
    List<_i6.PageRouteInfo>? children,
  }) : super(
         ServerDetailRoute.name,
         args: ServerDetailRouteArgs(key: key, server: server),
         initialChildren: children,
       );

  static const String name = 'ServerDetailRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServerDetailRouteArgs>();
      return _i1.ServerDetailPage(key: args.key, server: args.server);
    },
  );
}

class ServerDetailRouteArgs {
  const ServerDetailRouteArgs({this.key, required this.server});

  final _i7.Key? key;

  final _i8.Server server;

  @override
  String toString() {
    return 'ServerDetailRouteArgs{key: $key, server: $server}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServerDetailRouteArgs) return false;
    return key == other.key && server == other.server;
  }

  @override
  int get hashCode => key.hashCode ^ server.hashCode;
}

/// generated route for
/// [_i2.ServerWorkspacePage]
class ServerWorkspaceRoute extends _i6.PageRouteInfo<void> {
  const ServerWorkspaceRoute({List<_i6.PageRouteInfo>? children})
    : super(ServerWorkspaceRoute.name, initialChildren: children);

  static const String name = 'ServerWorkspaceRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i2.ServerWorkspacePage();
    },
  );
}

/// generated route for
/// [_i3.ServersPage]
class ServersRoute extends _i6.PageRouteInfo<void> {
  const ServersRoute({List<_i6.PageRouteInfo>? children})
    : super(ServersRoute.name, initialChildren: children);

  static const String name = 'ServersRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i3.ServersPage();
    },
  );
}

/// generated route for
/// [_i4.SessionsPage]
class SessionsRoute extends _i6.PageRouteInfo<void> {
  const SessionsRoute({List<_i6.PageRouteInfo>? children})
    : super(SessionsRoute.name, initialChildren: children);

  static const String name = 'SessionsRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i4.SessionsPage();
    },
  );
}

/// generated route for
/// [_i5.SettingsPage]
class SettingsRoute extends _i6.PageRouteInfo<void> {
  const SettingsRoute({List<_i6.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i5.SettingsPage();
    },
  );
}
