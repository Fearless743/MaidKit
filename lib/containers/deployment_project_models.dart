import 'dart:convert';

/// Resource categories that can be assembled into one deployment project.
/// Unknown kinds are preserved during import/export for forward compatibility.
enum DeploymentResourceKind {
  server,
  serverFolder,
  container,
  compose,
  webServer,
  firewallRule,
  systemdService,
  database,
  other,
}

DeploymentResourceKind deploymentResourceKindFromId(String id) {
  return DeploymentResourceKind.values.firstWhere(
    (kind) => kind.name == id,
    orElse: () => DeploymentResourceKind.other,
  );
}

class DeploymentProjectBundle {
  const DeploymentProjectBundle({
    required this.name,
    this.description,
    this.resources = const [],
  });

  final String name;
  final String? description;
  final List<DeploymentResourceBundle> resources;
}

class DeploymentResourceBundle {
  const DeploymentResourceBundle({
    required this.kind,
    required this.name,
    this.serverId,
    this.configuration = const {},
  });

  final String kind;
  final String name;
  final int? serverId;
  final Map<String, Object?> configuration;

  String get configurationJson => jsonEncode(configuration);
}
