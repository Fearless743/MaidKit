/// A container runtime available on a managed server.
enum ContainerRuntime { docker, podman }

/// Containers can belong either to the connected user or to the host root
/// environment. Root operations require passwordless sudo on the server.
enum ContainerScope { user, root }

enum ContainerAction { start, stop, restart }

enum ComposeProjectAction { stop, restart, recreate }

class ServerContainer {
  const ServerContainer({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    this.composeProject,
  });

  final String id;
  final String name;
  final String image;
  final String state;
  final String status;

  /// The Docker or Podman Compose project label assigned to this container.
  final String? composeProject;
}

/// Live resource sample from `docker stats` / `podman stats`.
class ContainerStats {
  const ContainerStats({
    required this.id,
    required this.name,
    this.cpuPercent,
    this.memUsage = '',
    this.memPercent,
    this.memUsedBytes,
    this.memLimitBytes,
    this.netIO = '',
    this.netRxBytes,
    this.netTxBytes,
    this.blockIO = '',
    this.blockReadBytes,
    this.blockWriteBytes,
    this.pids,
  });

  final String id;
  final String name;
  final double? cpuPercent;
  final String memUsage;
  final double? memPercent;
  final int? memUsedBytes;
  final int? memLimitBytes;
  final String netIO;
  final int? netRxBytes;
  final int? netTxBytes;
  final String blockIO;
  final int? blockReadBytes;
  final int? blockWriteBytes;
  final int? pids;
}

class ContainerEnvironment {
  const ContainerEnvironment({
    required this.runtime,
    required this.scope,
    this.containers = const [],
    this.error,
  });

  final ContainerRuntime runtime;
  final ContainerScope scope;
  final List<ServerContainer> containers;
  final String? error;

  bool get isAvailable => error == null;
}
