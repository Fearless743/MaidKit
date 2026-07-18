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

/// Structured result of `docker|podman inspect` for a single container.
class ContainerInspectDetail {
  const ContainerInspectDetail({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.created,
    required this.startedAt,
    required this.finishedAt,
    required this.exitCode,
    required this.platform,
    required this.restartPolicy,
    required this.networkMode,
    required this.workingDir,
    required this.user,
    required this.entrypoint,
    required this.command,
    required this.env,
    required this.ports,
    required this.binds,
    required this.mounts,
    required this.labels,
    required this.networks,
    required this.rawJson,
  });

  final String id;
  final String name;
  final String image;
  final String state;
  final String status;
  final String? created;
  final String? startedAt;
  final String? finishedAt;
  final int? exitCode;
  final String? platform;
  final String restartPolicy;
  final String networkMode;
  final String? workingDir;
  final String? user;
  final List<String> entrypoint;
  final List<String> command;
  final List<String> env;
  final List<String> ports;
  final List<String> binds;
  final List<String> mounts;
  final Map<String, String> labels;
  final List<String> networks;
  final String rawJson;

  bool get isRunning {
    final value = state.toLowerCase();
    return value.contains('running') || value == 'up';
  }

  /// Best-effort `run` command reconstructed from inspect data.
  ///
  /// Not every HostConfig flag is preserved; this covers the options MaidKit
  /// exposes in the run form and common production mounts/ports/env.
  String rerunCommand(ContainerRuntime runtime) {
    final parts = <String>[runtime.name, 'run', '-d'];
    final cleanName = name.startsWith('/') ? name.substring(1) : name;
    if (cleanName.isNotEmpty) {
      parts.addAll(['--name', cleanName]);
    }
    if (restartPolicy.isNotEmpty && restartPolicy != 'no') {
      parts.addAll(['--restart', restartPolicy]);
    }
    if (networkMode.isNotEmpty &&
        networkMode != 'default' &&
        networkMode != 'bridge') {
      parts.addAll(['--network', networkMode]);
    }
    if (user != null && user!.isNotEmpty) {
      parts.addAll(['--user', user!]);
    }
    if (workingDir != null && workingDir!.isNotEmpty) {
      parts.addAll(['-w', workingDir!]);
    }
    for (final port in ports) {
      parts.addAll(['-p', port]);
    }
    for (final bind in binds) {
      parts.addAll(['-v', bind]);
    }
    for (final variable in env) {
      // Skip PATH-like image defaults that make re-run noisy when empty-ish.
      if (variable.startsWith('PATH=')) continue;
      parts.addAll(['-e', variable]);
    }
    for (final entry in labels.entries) {
      // Compose labels are noisy in re-run copies.
      if (entry.key.startsWith('com.docker.compose.') ||
          entry.key.startsWith('io.podman.compose.')) {
        continue;
      }
      parts.addAll(['--label', '${entry.key}=${entry.value}']);
    }
    parts.add(image.isEmpty ? '<image>' : image);
    if (command.isNotEmpty) {
      parts.addAll(command);
    }
    return parts.map(_shellToken).join(' ');
  }

  static String _shellToken(String value) {
    if (RegExp(r'^[a-zA-Z0-9_./:@%+=,-]+$').hasMatch(value)) return value;
    return "'${value.replaceAll("'", "'\\''")}'";
  }
}
