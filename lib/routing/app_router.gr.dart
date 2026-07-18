// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i9;
import 'package:flutter/material.dart' as _i10;
import 'package:maid_kit/containers/container_detail_page.dart' as _i1;
import 'package:maid_kit/containers/container_models.dart' as _i12;
import 'package:maid_kit/containers/project_detail_page.dart' as _i2;
import 'package:maid_kit/containers/projects_page.dart' as _i3;
import 'package:maid_kit/data/local/app_database.dart' as _i11;
import 'package:maid_kit/servers/server_detail_page.dart' as _i4;
import 'package:maid_kit/servers/server_workspace_page.dart' as _i5;
import 'package:maid_kit/servers/servers_page.dart' as _i6;
import 'package:maid_kit/servers/sessions_page.dart' as _i7;
import 'package:maid_kit/servers/settings_page.dart' as _i8;

/// generated route for
/// [_i1.ContainerDetailPage]
class ContainerDetailRoute extends _i9.PageRouteInfo<ContainerDetailRouteArgs> {
  ContainerDetailRoute({
    _i10.Key? key,
    required _i11.Server server,
    required _i12.ContainerRuntime runtime,
    required _i12.ContainerScope scope,
    required String containerId,
    required String containerName,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         ContainerDetailRoute.name,
         args: ContainerDetailRouteArgs(
           key: key,
           server: server,
           runtime: runtime,
           scope: scope,
           containerId: containerId,
           containerName: containerName,
         ),
         initialChildren: children,
       );

  static const String name = 'ContainerDetailRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ContainerDetailRouteArgs>();
      return _i1.ContainerDetailPage(
        key: args.key,
        server: args.server,
        runtime: args.runtime,
        scope: args.scope,
        containerId: args.containerId,
        containerName: args.containerName,
      );
    },
  );
}

class ContainerDetailRouteArgs {
  const ContainerDetailRouteArgs({
    this.key,
    required this.server,
    required this.runtime,
    required this.scope,
    required this.containerId,
    required this.containerName,
  });

  final _i10.Key? key;

  final _i11.Server server;

  final _i12.ContainerRuntime runtime;

  final _i12.ContainerScope scope;

  final String containerId;

  final String containerName;

  @override
  String toString() {
    return 'ContainerDetailRouteArgs{key: $key, server: $server, runtime: $runtime, scope: $scope, containerId: $containerId, containerName: $containerName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContainerDetailRouteArgs) return false;
    return key == other.key &&
        server == other.server &&
        runtime == other.runtime &&
        scope == other.scope &&
        containerId == other.containerId &&
        containerName == other.containerName;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      server.hashCode ^
      runtime.hashCode ^
      scope.hashCode ^
      containerId.hashCode ^
      containerName.hashCode;
}

/// generated route for
/// [_i2.ProjectDetailPage]
class ProjectDetailRoute extends _i9.PageRouteInfo<ProjectDetailRouteArgs> {
  ProjectDetailRoute({
    _i10.Key? key,
    required int linkId,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         ProjectDetailRoute.name,
         args: ProjectDetailRouteArgs(key: key, linkId: linkId),
         initialChildren: children,
       );

  static const String name = 'ProjectDetailRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProjectDetailRouteArgs>();
      return _i2.ProjectDetailPage(key: args.key, linkId: args.linkId);
    },
  );
}

class ProjectDetailRouteArgs {
  const ProjectDetailRouteArgs({this.key, required this.linkId});

  final _i10.Key? key;

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
/// [_i3.ProjectsPage]
class ProjectsRoute extends _i9.PageRouteInfo<void> {
  const ProjectsRoute({List<_i9.PageRouteInfo>? children})
    : super(ProjectsRoute.name, initialChildren: children);

  static const String name = 'ProjectsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i3.ProjectsPage();
    },
  );
}

/// generated route for
/// [_i4.ServerDetailPage]
class ServerDetailRoute extends _i9.PageRouteInfo<ServerDetailRouteArgs> {
  ServerDetailRoute({
    _i10.Key? key,
    required _i11.Server server,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         ServerDetailRoute.name,
         args: ServerDetailRouteArgs(key: key, server: server),
         initialChildren: children,
       );

  static const String name = 'ServerDetailRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServerDetailRouteArgs>();
      return _i4.ServerDetailPage(key: args.key, server: args.server);
    },
  );
}

class ServerDetailRouteArgs {
  const ServerDetailRouteArgs({this.key, required this.server});

  final _i10.Key? key;

  final _i11.Server server;

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
/// [_i5.ServerWorkspacePage]
class ServerWorkspaceRoute extends _i9.PageRouteInfo<void> {
  const ServerWorkspaceRoute({List<_i9.PageRouteInfo>? children})
    : super(ServerWorkspaceRoute.name, initialChildren: children);

  static const String name = 'ServerWorkspaceRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i5.ServerWorkspacePage();
    },
  );
}

/// generated route for
/// [_i6.ServersPage]
class ServersRoute extends _i9.PageRouteInfo<void> {
  const ServersRoute({List<_i9.PageRouteInfo>? children})
    : super(ServersRoute.name, initialChildren: children);

  static const String name = 'ServersRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i6.ServersPage();
    },
  );
}

/// generated route for
/// [_i7.SessionsPage]
class SessionsRoute extends _i9.PageRouteInfo<void> {
  const SessionsRoute({List<_i9.PageRouteInfo>? children})
    : super(SessionsRoute.name, initialChildren: children);

  static const String name = 'SessionsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i7.SessionsPage();
    },
  );
}

/// generated route for
/// [_i8.SettingsPage]
class SettingsRoute extends _i9.PageRouteInfo<void> {
  const SettingsRoute({List<_i9.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i8.SettingsPage();
    },
  );
}
