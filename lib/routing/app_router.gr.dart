// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i12;
import 'package:flutter/material.dart' as _i13;
import 'package:maid_kit/agent/agent_page.dart' as _i2;
import 'package:maid_kit/containers/container_detail_page.dart' as _i4;
import 'package:maid_kit/containers/container_models.dart' as _i15;
import 'package:maid_kit/containers/project_detail_page.dart' as _i5;
import 'package:maid_kit/containers/projects_page.dart' as _i6;
import 'package:maid_kit/data/local/app_database.dart' as _i14;
import 'package:maid_kit/servers/about_page.dart' as _i1;
import 'package:maid_kit/servers/assets_page.dart' as _i3;
import 'package:maid_kit/servers/server_detail_page.dart' as _i7;
import 'package:maid_kit/servers/server_workspace_page.dart' as _i8;
import 'package:maid_kit/servers/servers_page.dart' as _i9;
import 'package:maid_kit/servers/settings_page.dart' as _i10;
import 'package:maid_kit/snippets/snippets_page.dart' as _i11;

/// generated route for
/// [_i1.AboutPage]
class AboutRoute extends _i12.PageRouteInfo<void> {
  const AboutRoute({List<_i12.PageRouteInfo>? children})
    : super(AboutRoute.name, initialChildren: children);

  static const String name = 'AboutRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutPage();
    },
  );
}

/// generated route for
/// [_i2.AgentPage]
class AgentRoute extends _i12.PageRouteInfo<void> {
  const AgentRoute({List<_i12.PageRouteInfo>? children})
    : super(AgentRoute.name, initialChildren: children);

  static const String name = 'AgentRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i2.AgentPage();
    },
  );
}

/// generated route for
/// [_i3.AssetsPage]
class AssetsRoute extends _i12.PageRouteInfo<void> {
  const AssetsRoute({List<_i12.PageRouteInfo>? children})
    : super(AssetsRoute.name, initialChildren: children);

  static const String name = 'AssetsRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i3.AssetsPage();
    },
  );
}

/// generated route for
/// [_i4.ContainerDetailPage]
class ContainerDetailRoute
    extends _i12.PageRouteInfo<ContainerDetailRouteArgs> {
  ContainerDetailRoute({
    _i13.Key? key,
    required _i14.Server server,
    required _i15.ContainerRuntime runtime,
    required _i15.ContainerScope scope,
    required String containerId,
    required String containerName,
    List<_i12.PageRouteInfo>? children,
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

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ContainerDetailRouteArgs>();
      return _i4.ContainerDetailPage(
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

  final _i13.Key? key;

  final _i14.Server server;

  final _i15.ContainerRuntime runtime;

  final _i15.ContainerScope scope;

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
/// [_i5.ProjectDetailPage]
class ProjectDetailRoute extends _i12.PageRouteInfo<ProjectDetailRouteArgs> {
  ProjectDetailRoute({
    _i13.Key? key,
    int? projectId,
    int? linkId,
    List<_i12.PageRouteInfo>? children,
  }) : super(
         ProjectDetailRoute.name,
         args: ProjectDetailRouteArgs(
           key: key,
           projectId: projectId,
           linkId: linkId,
         ),
         initialChildren: children,
       );

  static const String name = 'ProjectDetailRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProjectDetailRouteArgs>(
        orElse: () => const ProjectDetailRouteArgs(),
      );
      return _i5.ProjectDetailPage(
        key: args.key,
        projectId: args.projectId,
        linkId: args.linkId,
      );
    },
  );
}

class ProjectDetailRouteArgs {
  const ProjectDetailRouteArgs({this.key, this.projectId, this.linkId});

  final _i13.Key? key;

  final int? projectId;

  final int? linkId;

  @override
  String toString() {
    return 'ProjectDetailRouteArgs{key: $key, projectId: $projectId, linkId: $linkId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProjectDetailRouteArgs) return false;
    return key == other.key &&
        projectId == other.projectId &&
        linkId == other.linkId;
  }

  @override
  int get hashCode => key.hashCode ^ projectId.hashCode ^ linkId.hashCode;
}

/// generated route for
/// [_i6.ProjectsPage]
class ProjectsRoute extends _i12.PageRouteInfo<void> {
  const ProjectsRoute({List<_i12.PageRouteInfo>? children})
    : super(ProjectsRoute.name, initialChildren: children);

  static const String name = 'ProjectsRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i6.ProjectsPage();
    },
  );
}

/// generated route for
/// [_i7.ServerDetailPage]
class ServerDetailRoute extends _i12.PageRouteInfo<ServerDetailRouteArgs> {
  ServerDetailRoute({
    _i13.Key? key,
    required _i14.Server server,
    int initialTab = 0,
    String? initialComposeProject,
    bool embedded = false,
    List<_i12.PageRouteInfo>? children,
  }) : super(
         ServerDetailRoute.name,
         args: ServerDetailRouteArgs(
           key: key,
           server: server,
           initialTab: initialTab,
           initialComposeProject: initialComposeProject,
           embedded: embedded,
         ),
         initialChildren: children,
       );

  static const String name = 'ServerDetailRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServerDetailRouteArgs>();
      return _i7.ServerDetailPage(
        key: args.key,
        server: args.server,
        initialTab: args.initialTab,
        initialComposeProject: args.initialComposeProject,
        embedded: args.embedded,
      );
    },
  );
}

class ServerDetailRouteArgs {
  const ServerDetailRouteArgs({
    this.key,
    required this.server,
    this.initialTab = 0,
    this.initialComposeProject,
    this.embedded = false,
  });

  final _i13.Key? key;

  final _i14.Server server;

  final int initialTab;

  final String? initialComposeProject;

  final bool embedded;

  @override
  String toString() {
    return 'ServerDetailRouteArgs{key: $key, server: $server, initialTab: $initialTab, initialComposeProject: $initialComposeProject, embedded: $embedded}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServerDetailRouteArgs) return false;
    return key == other.key &&
        server == other.server &&
        initialTab == other.initialTab &&
        initialComposeProject == other.initialComposeProject &&
        embedded == other.embedded;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      server.hashCode ^
      initialTab.hashCode ^
      initialComposeProject.hashCode ^
      embedded.hashCode;
}

/// generated route for
/// [_i8.ServerWorkspacePage]
class ServerWorkspaceRoute extends _i12.PageRouteInfo<void> {
  const ServerWorkspaceRoute({List<_i12.PageRouteInfo>? children})
    : super(ServerWorkspaceRoute.name, initialChildren: children);

  static const String name = 'ServerWorkspaceRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i8.ServerWorkspacePage();
    },
  );
}

/// generated route for
/// [_i9.ServersPage]
class ServersRoute extends _i12.PageRouteInfo<void> {
  const ServersRoute({List<_i12.PageRouteInfo>? children})
    : super(ServersRoute.name, initialChildren: children);

  static const String name = 'ServersRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i9.ServersPage();
    },
  );
}

/// generated route for
/// [_i10.SettingsPage]
class SettingsRoute extends _i12.PageRouteInfo<void> {
  const SettingsRoute({List<_i12.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i10.SettingsPage();
    },
  );
}

/// generated route for
/// [_i11.SnippetsPage]
class SnippetsRoute extends _i12.PageRouteInfo<void> {
  const SnippetsRoute({List<_i12.PageRouteInfo>? children})
    : super(SnippetsRoute.name, initialChildren: children);

  static const String name = 'SnippetsRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return const _i11.SnippetsPage();
    },
  );
}
