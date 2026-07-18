// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i8;
import 'package:flutter/material.dart' as _i9;
import 'package:maid_kit/containers/project_detail_page.dart' as _i1;
import 'package:maid_kit/containers/projects_page.dart' as _i2;
import 'package:maid_kit/data/local/app_database.dart' as _i10;
import 'package:maid_kit/servers/server_detail_page.dart' as _i3;
import 'package:maid_kit/servers/server_workspace_page.dart' as _i4;
import 'package:maid_kit/servers/servers_page.dart' as _i5;
import 'package:maid_kit/servers/sessions_page.dart' as _i6;
import 'package:maid_kit/servers/settings_page.dart' as _i7;

/// generated route for
/// [_i1.ProjectDetailPage]
class ProjectDetailRoute extends _i8.PageRouteInfo<ProjectDetailRouteArgs> {
  ProjectDetailRoute({
    _i9.Key? key,
    required int linkId,
    List<_i8.PageRouteInfo>? children,
  }) : super(
         ProjectDetailRoute.name,
         args: ProjectDetailRouteArgs(key: key, linkId: linkId),
         initialChildren: children,
       );

  static const String name = 'ProjectDetailRoute';

  static _i8.PageInfo page = _i8.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProjectDetailRouteArgs>();
      return _i1.ProjectDetailPage(key: args.key, linkId: args.linkId);
    },
  );
}

class ProjectDetailRouteArgs {
  const ProjectDetailRouteArgs({this.key, required this.linkId});

  final _i9.Key? key;

  final int linkId;

  @override
  String toString() {
    return 'ProjectDetailRouteArgs{key: $key, linkId: $linkId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProjectDetailRouteArgs) return false;
    return key == other.key && linkId == other.linkId;
  }

  @override
  int get hashCode => key.hashCode ^ linkId.hashCode;
}

/// generated route for
/// [_i2.ProjectsPage]
class ProjectsRoute extends _i8.PageRouteInfo<void> {
  const ProjectsRoute({List<_i8.PageRouteInfo>? children})
    : super(ProjectsRoute.name, initialChildren: children);

  static const String name = 'ProjectsRoute';

  static _i8.PageInfo page = _i8.PageInfo(
    name,
    builder: (data) {
      return const _i2.ProjectsPage();
    },
  );
}

/// generated route for
/// [_i3.ServerDetailPage]
class ServerDetailRoute extends _i8.PageRouteInfo<ServerDetailRouteArgs> {
  ServerDetailRoute({
    _i9.Key? key,
    required _i10.Server server,
    List<_i8.PageRouteInfo>? children,
  }) : super(
         ServerDetailRoute.name,
         args: ServerDetailRouteArgs(key: key, server: server),
         initialChildren: children,
       );

  static const String name = 'ServerDetailRoute';

  static _i8.PageInfo page = _i8.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServerDetailRouteArgs>();
      return _i3.ServerDetailPage(key: args.key, server: args.server);
    },
  );
}

class ServerDetailRouteArgs {
  const ServerDetailRouteArgs({this.key, required this.server});

  final _i9.Key? key;

  final _i10.Server server;

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
/// [_i4.ServerWorkspacePage]
class ServerWorkspaceRoute extends _i8.PageRouteInfo<void> {
  const ServerWorkspaceRoute({List<_i8.PageRouteInfo>? children})
    : super(ServerWorkspaceRoute.name, initialChildren: children);

  static const String name = 'ServerWorkspaceRoute';

  static _i8.PageInfo page = _i8.PageInfo(
    name,
    builder: (data) {
      return const _i4.ServerWorkspacePage();
    },
  );
}

/// generated route for
/// [_i5.ServersPage]
class ServersRoute extends _i8.PageRouteInfo<void> {
  const ServersRoute({List<_i8.PageRouteInfo>? children})
    : super(ServersRoute.name, initialChildren: children);

  static const String name = 'ServersRoute';

  static _i8.PageInfo page = _i8.PageInfo(
    name,
    builder: (data) {
      return const _i5.ServersPage();
    },
  );
}

/// generated route for
/// [_i6.SessionsPage]
class SessionsRoute extends _i8.PageRouteInfo<void> {
  const SessionsRoute({List<_i8.PageRouteInfo>? children})
    : super(SessionsRoute.name, initialChildren: children);

  static const String name = 'SessionsRoute';

  static _i8.PageInfo page = _i8.PageInfo(
    name,
    builder: (data) {
      return const _i6.SessionsPage();
    },
  );
}

/// generated route for
/// [_i7.SettingsPage]
class SettingsRoute extends _i8.PageRouteInfo<void> {
  const SettingsRoute({List<_i8.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i8.PageInfo page = _i8.PageInfo(
    name,
    builder: (data) {
      return const _i7.SettingsPage();
    },
  );
}
