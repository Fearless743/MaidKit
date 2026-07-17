import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../containers/container_models.dart';
import '../data/local/app_database.dart';
import 'server_metrics_collector.dart';
import 'server_models.dart';
import 'terminal_session_adapter.dart';

typedef HostKeyApproval = Future<bool> Function(HostKeyPrompt prompt);

class SshConnectionManager {
  SshConnectionManager(
    this._terminalAdapterFactory, {
    ServerMetricsCollector? metricsCollector,
  }) : _metricsCollector = metricsCollector ?? AutoServerMetricsCollector();

  final TerminalSessionAdapterFactory Function() _terminalAdapterFactory;
  final ServerMetricsCollector _metricsCollector;

  /// These clients are used exclusively for collecting server information.
  /// Terminal shells keep their own clients so reconnecting statistics never
  /// interrupts an interactive session.
  final _sessions = <int, SSHClient>{};
  final _terminals = <String, _TerminalConnection>{};
  final _controller = StreamController<List<SshSessionInfo>>.broadcast();
  final _states = <int, SshSessionInfo>{};
  var _nextTerminalId = 0;

  Stream<List<SshSessionInfo>> get sessions => _controller.stream;
  List<SshSessionInfo> get current => _states.values.toList();

  /// Returns the retained authenticated client for [serverId], if available.
  ///
  /// Feature code should reuse this client for remote operations instead of
  /// opening a second transport connection.
  SSHClient? clientFor(int serverId) {
    final client = _sessions[serverId];
    return client == null || client.isClosed ? null : client;
  }

  Future<T> withClient<T>(
    int serverId,
    Future<T> Function(SSHClient client) run,
  ) {
    final client = clientFor(serverId);
    if (client == null) {
      throw StateError('Connect to this server before running an operation.');
    }
    return run(client);
  }

  Future<TerminalSessionHandle> openTerminal(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
  }) async {
    final client = await _createClient(
      server,
      credential,
      approve,
      knownHostKeyFingerprint: knownHostKeyFingerprint,
    );
    late SSHSession shell;
    try {
      shell = await client.shell(
        pty: const SSHPtyConfig(type: 'xterm-256color', width: 120, height: 36),
      );
    } catch (_) {
      client.close();
      rethrow;
    }
    final terminal = _terminalAdapterFactory().create();
    final terminalId = 'terminal-${_nextTerminalId++}';
    final binding = TerminalSessionBinding(
      adapter: terminal,
      stdout: shell.stdout,
      stderr: shell.stderr,
      send: shell.write,
      resize: (event) => shell.resizeTerminal(
        event.columns,
        event.rows,
        event.pixelWidth,
        event.pixelHeight,
      ),
    );
    _terminals[terminalId] = _TerminalConnection(
      serverId: server.id,
      client: client,
      shell: shell,
      binding: binding,
    );
    unawaited(
      shell.done.whenComplete(() {
        if (identical(_terminals[terminalId]?.shell, shell)) {
          unawaited(closeTerminal(terminalId));
        }
      }),
    );
    return TerminalSessionHandle(
      id: terminalId,
      adapter: terminal,
      done: shell.done,
    );
  }

  Future<void> closeTerminal(String terminalId) async {
    final terminal = _terminals.remove(terminalId);
    if (terminal == null) return;
    await terminal.shell.stdin.close();
    await terminal.binding.close();
    terminal.client.close();
  }

  Future<void> refreshServerInfo(Server server) async {
    final client = clientFor(server.id);
    final state = _states[server.id];
    if (client == null || client.isClosed || state == null) return;
    if (server.collectStats) await _refreshStats(client, state);
    if (server.collectSystemInfo) {
      await _refreshSystemInfo(client, _states[server.id] ?? state);
    }
  }

  /// Refreshes only the dynamic, low-cost metrics used by server lists and
  /// background connections. Detail pages call [refreshServerInfo] instead.
  Future<void> refreshBasicServerInfo(Server server) async {
    final client = clientFor(server.id);
    final state = _states[server.id];
    if (client == null || client.isClosed || state == null) return;
    if (server.collectStats) await _refreshStats(client, state);
  }

  Future<List<ServerProcess>> listProcesses(int serverId) async {
    return withClient(serverId, (client) async {
      final session = await client.execute(
        'LC_ALL=C ps -eo pid=,user=,%cpu=,%mem=,rss=,comm= --sort=-%cpu | head -n 20',
      );
      final output = await utf8.decoder.bind(session.stdout).join();
      await session.done;
      return output
          .split('\n')
          .map(_parseProcess)
          .whereType<ServerProcess>()
          .toList();
    });
  }

  /// Lists every installed Docker and Podman environment for both the SSH user
  /// and root. Root is intentionally non-interactive: MaidKit never requests
  /// or transports a sudo password.
  Future<List<ContainerEnvironment>> listContainers(
    int serverId, {
    String? sudoPassword,
  }) async {
    return withClient(serverId, (client) async {
      final environments = <ContainerEnvironment>[];
      for (final runtime in ContainerRuntime.values) {
        final available = await _runtimeAvailable(client, runtime);
        if (!available) continue;
        for (final scope in ContainerScope.values) {
          environments.add(
            await _listContainerEnvironment(
              client,
              runtime,
              scope,
              sudoPassword: sudoPassword,
            ),
          );
        }
      }
      return environments;
    });
  }

  Future<void> runContainerAction(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String containerId,
    required ContainerAction action,
    String? sudoPassword,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]*$').hasMatch(containerId)) {
      throw ArgumentError.value(
        containerId,
        'containerId',
        'Invalid container ID.',
      );
    }
    await withClient(serverId, (client) async {
      final result = await _execute(
        client,
        '${_scopePrefix(scope, sudoPassword)}${runtime.name} ${action.name} $containerId',
        stdin: scope == ContainerScope.root ? sudoPassword : null,
      );
      if (result.exitCode != 0) {
        throw StateError(_commandError(result));
      }
    });
  }

  Future<bool> _runtimeAvailable(
    SSHClient client,
    ContainerRuntime runtime,
  ) async {
    final result = await _execute(client, 'command -v ${runtime.name}');
    return result.exitCode == 0;
  }

  Future<ContainerEnvironment> _listContainerEnvironment(
    SSHClient client,
    ContainerRuntime runtime,
    ContainerScope scope, {
    String? sudoPassword,
  }) async {
    final result = await _execute(
      client,
      '${_scopePrefix(scope, sudoPassword)}${runtime.name} ps -a --format "{{.ID}}\\t{{.Names}}\\t{{.Image}}\\t{{.State}}\\t{{.Status}}"',
      stdin: scope == ContainerScope.root ? sudoPassword : null,
    );
    if (result.exitCode != 0) {
      return ContainerEnvironment(
        runtime: runtime,
        scope: scope,
        error: _commandError(result),
      );
    }
    return ContainerEnvironment(
      runtime: runtime,
      scope: scope,
      containers: result.stdout
          .split('\n')
          .map(_parseContainer)
          .whereType<ServerContainer>()
          .toList(),
    );
  }

  Future<_CommandResult> _execute(
    SSHClient client,
    String command, {
    String? stdin,
  }) async {
    final session = await client.execute(command);
    final stdout = utf8.decoder.bind(session.stdout).join();
    final stderr = utf8.decoder.bind(session.stderr).join();
    if (stdin != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode('$stdin\n')));
      await session.stdin.close();
    }
    await session.done;
    return _CommandResult(
      stdout: await stdout,
      stderr: await stderr,
      exitCode: session.exitCode ?? 1,
    );
  }

  ServerContainer? _parseContainer(String line) {
    final fields = line.split('\t');
    if (fields.length != 5 || fields.any((field) => field.isEmpty)) return null;
    return ServerContainer(
      id: fields[0],
      name: fields[1],
      image: fields[2],
      state: fields[3],
      status: fields[4],
    );
  }

  String _scopePrefix(ContainerScope scope, String? sudoPassword) =>
      switch (scope) {
        ContainerScope.user => '',
        ContainerScope.root =>
          sudoPassword == null ? 'sudo -n ' : 'sudo -S -p "" ',
      };

  String _commandError(_CommandResult result) {
    final message = result.stderr.trim().isNotEmpty
        ? result.stderr.trim()
        : result.stdout.trim();
    return message.isEmpty
        ? 'The command exited with code ${result.exitCode}.'
        : message;
  }

  Future<void> _refreshStats(SSHClient client, SshSessionInfo state) async {
    try {
      final stats = await _metricsCollector.collect(client);
      if (stats != null && identical(_sessions[state.serverId], client)) {
        _set((_states[state.serverId] ?? state).copyWith(stats: stats));
      }
    } catch (_) {
      // Statistics are optional and can be unavailable on non-Linux hosts.
    }
  }

  Future<void> _refreshSystemInfo(
    SSHClient client,
    SshSessionInfo state,
  ) async {
    try {
      final session = await client.execute(
        "sh -c 'if [ -r /etc/os-release ]; then . /etc/os-release; printf \"%s\\n\" \"\$PRETTY_NAME\"; else uname -s; fi; uname -r'",
      );
      final output = await utf8.decoder.bind(session.stdout).join();
      await session.done;
      final values = output.trim().split('\n');
      if (values.isNotEmpty && identical(_sessions[state.serverId], client)) {
        _set(
          (_states[state.serverId] ?? state).copyWith(
            systemInfo: ServerSystemInfo(
              distribution: values.firstOrNull,
              kernel: values.length > 1 ? values[1] : null,
            ),
          ),
        );
      }
    } catch (_) {
      // System information is optional on restricted or non-POSIX hosts.
    }
  }

  Future<void> connect(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
  }) async {
    await disconnect(server.id);
    _set(
      SshSessionInfo(
        serverId: server.id,
        serverName: server.name,
        connectedAt: DateTime.now(),
        status: SessionStatus.connecting,
      ),
    );
    String? serverAuthMethods;
    try {
      final client = await _createClient(
        server,
        credential,
        approve,
        knownHostKeyFingerprint: knownHostKeyFingerprint,
        onAuthMethods: (methods) => serverAuthMethods = methods,
      );
      _sessions[server.id] = client;
      _set(_states[server.id]!.copyWith(status: SessionStatus.connected));
      unawaited(refreshServerInfo(server));
      unawaited(
        client.done.whenComplete(() {
          if (!identical(_sessions[server.id], client)) return;
          _sessions.remove(server.id);
          unawaited(_closeTerminalsFor(server.id));
          final state = _states[server.id];
          if (state != null && state.status == SessionStatus.connected) {
            _set(state.copyWith(status: SessionStatus.closed));
          }
        }),
      );
    } catch (error) {
      final message = error is SSHAuthFailError
          ? serverAuthMethods == null || serverAuthMethods!.isEmpty
                ? 'The server rejected the supplied password.'
                : 'The server rejected the supplied password. It advertises: $serverAuthMethods.'
          : error.toString();
      _set(
        _states[server.id]!.copyWith(
          status: SessionStatus.failed,
          error: message,
        ),
      );
      rethrow;
    }
  }

  Future<void> disconnect(int serverId) async {
    final client = _sessions.remove(serverId);
    client?.close();
    final state = _states[serverId];
    if (state != null) _set(state.copyWith(status: SessionStatus.closed));
  }

  void _set(SshSessionInfo value) {
    _states[value.serverId] = value;
    _controller.add(current);
  }

  Future<void> dispose() async {
    for (final terminalId in _terminals.keys.toList()) {
      await closeTerminal(terminalId);
    }
    for (final client in _sessions.values) {
      client.close();
    }
    await _controller.close();
  }

  Future<void> _closeTerminalsFor(int serverId) async {
    final terminalIds = _terminals.entries
        .where((entry) => entry.value.serverId == serverId)
        .map((entry) => entry.key)
        .toList();
    for (final terminalId in terminalIds) {
      await closeTerminal(terminalId);
    }
  }

  ServerProcess? _parseProcess(String line) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < 6) return null;
    final pid = int.tryParse(fields[0]);
    final cpuPercent = double.tryParse(fields[2]);
    final memoryPercent = double.tryParse(fields[3]);
    final rssKb = int.tryParse(fields[4]);
    if (pid == null ||
        cpuPercent == null ||
        memoryPercent == null ||
        rssKb == null) {
      return null;
    }
    return ServerProcess(
      pid: pid,
      user: fields[1],
      cpuPercent: cpuPercent,
      memoryPercent: memoryPercent,
      rssKb: rssKb,
      command: fields.sublist(5).join(' '),
    );
  }

  Future<SSHClient> _createClient(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    void Function(String? methods)? onAuthMethods,
  }) async {
    final identities = credential.type == CredentialType.privateKey
        ? SSHKeyPair.fromPem(credential.privateKey!, credential.keyPassphrase)
        : null;
    final client = SSHClient(
      await SSHSocket.connect(server.host, server.port),
      username: server.username,
      identities: identities,
      onPasswordRequest: credential.type == CredentialType.password
          ? () => credential.password
          : null,
      onUserInfoRequest: credential.type == CredentialType.password
          ? (request) => List<String>.filled(
              request.prompts.length,
              credential.password!,
            )
          : null,
      onVerifyHostKey: (algorithm, fingerprint) {
        final presented =
            'SHA256:${base64Encode(fingerprint).replaceAll('=', '')}';
        if (knownHostKeyFingerprint == presented) return true;
        return approve(
          HostKeyPrompt(
            algorithm: algorithm,
            fingerprint: presented,
            replacesExisting: knownHostKeyFingerprint != null,
          ),
        );
      },
      printTrace: (message) {
        final match = RegExp(
          r'SSH_Message_Userauth_Failure\(methodsLeft: \[(.*?)\]',
        ).firstMatch(message ?? '');
        if (match != null) onAuthMethods?.call(match.group(1));
      },
      handshakeTimeout: const Duration(seconds: 15),
      authTimeout: const Duration(seconds: 15),
    );
    await client.authenticated;
    return client;
  }
}

class TerminalSessionHandle {
  const TerminalSessionHandle({
    required this.id,
    required this.adapter,
    required this.done,
  });

  final String id;
  final TerminalSessionAdapter adapter;
  final Future<void> done;
}

class _TerminalConnection {
  const _TerminalConnection({
    required this.serverId,
    required this.client,
    required this.shell,
    required this.binding,
  });

  final int serverId;
  final SSHClient client;
  final SSHSession shell;
  final TerminalSessionBinding binding;
}

class _CommandResult {
  const _CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}
