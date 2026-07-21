import 'dart:convert';

import 'web_server_models.dart';

/// Result of one remote shell command run for a web server adapter.
class WebServerCommandResult {
  const WebServerCommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;

  String get output {
    final out = stdout.trim();
    if (out.isNotEmpty) return stdout;
    return stderr;
  }

  String get combined {
    final parts = <String>[
      if (stdout.trim().isNotEmpty) stdout.trimRight(),
      if (stderr.trim().isNotEmpty) stderr.trimRight(),
    ];
    return parts.join('\n');
  }
}

/// SSH-backed command surface exposed to [WebServerAdapter] implementations.
///
/// Adapters never import dartssh2; they only issue shell snippets and parse
/// stdout. Privilege escalation is handled by the connection manager.
abstract interface class WebServerRemote {
  /// Runs [command] on the host.
  ///
  /// When [privileged] is true, the runner prefixes sudo/root as needed.
  ///
  /// [stdinPayload] is written to the remote process stdin. For privileged
  /// sudo -S sessions the password is sent as the first line automatically;
  /// remaining payload is available to the command (e.g. `tee`).
  Future<WebServerCommandResult> run(
    String command, {
    bool privileged = false,
    String? stdinPayload,
  });

  /// Shell-safe single-quoted form of [value].
  String quote(String value);
}

/// Backend-specific web server management (nginx, caddy, …).
///
/// Each adapter owns product-specific CLI commands and output parsing.
abstract interface class WebServerAdapter {
  /// Stable id used in UI selection and persistence (`nginx`, `caddy`).
  String get id;

  /// Human-readable product name.
  String get label;

  /// Executable looked up with `command -v` (e.g. `nginx`).
  String get binaryName;

  /// Default systemd unit name (e.g. `nginx.service`).
  String get serviceUnit;

  /// True when [binaryName] is on PATH.
  Future<bool> isInstalled(WebServerRemote remote);

  /// Full status + site listing for the management tab.
  Future<WebServerStatus> loadStatus(WebServerRemote remote);

  /// Service lifecycle: start/stop/restart/reload/enable/disable.
  Future<void> runAction(WebServerRemote remote, WebServerAction action);

  /// Validate the main configuration; returns the tool's output text.
  ///
  /// Throws [StateError] when validation fails.
  Future<String> validateConfig(WebServerRemote remote);

  /// Read config text for [siteId], or the main config when [siteId] is null.
  Future<String> readConfig(WebServerRemote remote, {String? siteId});

  /// Write config text for [siteId], or the main config when [siteId] is null.
  Future<void> writeConfig(
    WebServerRemote remote, {
    required String content,
    String? siteId,
  });

  /// Recent service logs (journalctl / error log tail).
  Future<String> getLogs(WebServerRemote remote, {int lines = 200});
}

/// Shared helpers used by concrete adapters when probing systemd services.
mixin WebServerSystemdHelpers {
  String get binaryName;
  String get serviceUnit;

  Future<({bool running, bool enabled})> readServiceState(
    WebServerRemote remote,
  ) async {
    final unit = serviceUnit;
    final active = await remote.run(
      'systemctl is-active ${remote.quote(unit)} 2>/dev/null || true',
    );
    final enabled = await remote.run(
      'systemctl is-enabled ${remote.quote(unit)} 2>/dev/null || true',
    );
    final activeText = active.output.trim().toLowerCase();
    final enabledText = enabled.output.trim().toLowerCase();
    return (
      running: activeText == 'active',
      enabled: enabledText == 'enabled' || enabledText == 'enabled-runtime',
    );
  }

  Future<void> runSystemctl(
    WebServerRemote remote,
    WebServerAction action,
  ) async {
    final verb = action.systemctlVerb;
    final unit = serviceUnit;
    final result = await remote.run(
      'systemctl $verb ${remote.quote(unit)}',
      privileged: true,
    );
    if (result.exitCode != 0) {
      final message = result.combined.trim();
      throw StateError(
        message.isEmpty
            ? 'systemctl $verb $unit failed (exit ${result.exitCode}).'
            : message,
      );
    }
  }

  Future<String> readJournal(WebServerRemote remote, {int lines = 200}) async {
    final n = lines.clamp(1, 2000);
    final unit = serviceUnit;
    final result = await remote.run(
      'journalctl -u ${remote.quote(unit)} -n $n --no-pager -o short-iso',
      privileged: true,
    );
    if (result.exitCode != 0 && result.stdout.trim().isEmpty) {
      final message = result.combined.trim();
      throw StateError(
        message.isEmpty ? 'Could not read journal for $unit.' : message,
      );
    }
    final text = result.stdout.trim().isNotEmpty
        ? result.stdout
        : result.stderr;
    return text.trim().isEmpty ? 'No journal entries for $unit.' : text;
  }

  Future<String?> resolveBinaryPath(WebServerRemote remote) async {
    final result = await remote.run('command -v $binaryName');
    if (result.exitCode != 0) return null;
    final path = result.stdout.trim();
    return path.isEmpty ? null : path;
  }

  Future<String> readFile(
    WebServerRemote remote,
    String path, {
    bool privileged = true,
  }) async {
    final result = await remote.run(
      'cat ${remote.quote(path)}',
      privileged: privileged,
    );
    if (result.exitCode != 0) {
      final message = result.combined.trim();
      throw StateError(message.isEmpty ? 'Could not read $path.' : message);
    }
    return result.stdout;
  }

  /// Writes [content] to [path] via privileged `tee` (sudo-safe).
  Future<void> writeFile(
    WebServerRemote remote,
    String path,
    String content,
  ) async {
    if (!isSafeConfigPath(path)) {
      throw ArgumentError.value(path, 'path', 'Unsafe config path.');
    }
    final bytes = utf8.encode(content);
    if (bytes.length > webServerMaxEditableBytes) {
      throw StateError(
        'Config is larger than 1 MB and cannot be saved from the editor.',
      );
    }
    final result = await remote.run(
      'tee ${remote.quote(path)} > /dev/null',
      privileged: true,
      stdinPayload: content,
    );
    if (result.exitCode != 0) {
      final message = result.combined.trim();
      throw StateError(message.isEmpty ? 'Could not write $path.' : message);
    }
  }
}

/// Parses a simple `key=value` probe block produced by adapters.
Map<String, String> parseProbeLines(String text) {
  final map = <String, String>{};
  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    if (key.isNotEmpty) map[key] = value;
  }
  return map;
}

/// True when [path] is a safe absolute config path (no shell metacharacters).
bool isSafeConfigPath(String path) {
  if (!path.startsWith('/')) return false;
  if (path.contains('..')) return false;
  return RegExp(r'^/[A-Za-z0-9_./@+-]+$').hasMatch(path);
}

/// First meaningful line from tool output for status banners.
String summarizeCommandOutput(String text, {int maxLength = 160}) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return '';
  // Prefer an error/warn line when present.
  for (final line in lines.reversed) {
    final lower = line.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('emerg') ||
        lower.contains('invalid')) {
      return _truncate(line, maxLength);
    }
  }
  // Prefer a success line when present.
  for (final line in lines.reversed) {
    final lower = line.toLowerCase();
    if (lower.contains('successful') ||
        lower.contains('syntax is ok') ||
        lower.contains('test is successful') ||
        lower.contains('valid configuration')) {
      return _truncate(line, maxLength);
    }
  }
  return _truncate(lines.last, maxLength);
}

String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength - 1)}…';
}
