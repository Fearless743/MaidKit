import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../data/local/app_database.dart';
import 'server_models.dart';
import 'terminal_session_adapter.dart';

typedef HostKeyApproval = Future<bool> Function(HostKeyPrompt prompt);

class SshConnectionManager {
  SshConnectionManager(this._terminalAdapterFactory);

  final TerminalSessionAdapterFactory Function() _terminalAdapterFactory;
  final _sessions = <int, SSHClient>{};
  final _shells = <int, SSHSession>{};
  final _terminalBindings = <int, TerminalSessionBinding>{};
  final _controller = StreamController<List<SshSessionInfo>>.broadcast();
  final _states = <int, SshSessionInfo>{};

  Stream<List<SshSessionInfo>> get sessions => _controller.stream;
  List<SshSessionInfo> get current => _states.values.toList();

  TerminalSessionAdapter? terminalFor(int serverId) =>
      _terminalBindings[serverId]?.adapter;

  Future<TerminalSessionAdapter> openTerminal(int serverId) async {
    final existing = _terminalBindings[serverId];
    if (existing != null) return existing.adapter;
    final client = _sessions[serverId];
    if (client == null || client.isClosed) {
      throw StateError('Connect to this server before opening a terminal.');
    }
    final shell = await client.shell(
      pty: const SSHPtyConfig(type: 'xterm-256color', width: 120, height: 36),
    );
    final terminal = _terminalAdapterFactory().create();
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
    _shells[serverId] = shell;
    _terminalBindings[serverId] = binding;
    unawaited(
      shell.done.whenComplete(() {
        if (identical(_shells[serverId], shell)) {
          _shells.remove(serverId);
          unawaited(_closeTerminal(serverId));
        }
      }),
    );
    return terminal;
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
          if (match != null) {
            serverAuthMethods = match.group(1);
          }
        },
        handshakeTimeout: const Duration(seconds: 15),
        authTimeout: const Duration(seconds: 15),
      );
      await client.authenticated;
      _sessions[server.id] = client;
      _set(_states[server.id]!.copyWith(status: SessionStatus.connected));
      unawaited(
        client.done.whenComplete(() {
          _sessions.remove(server.id);
          unawaited(_closeShell(server.id));
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
    await _closeShell(serverId);
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
    for (final serverId in _sessions.keys.toList()) {
      await _closeShell(serverId);
    }
    for (final client in _sessions.values) {
      client.close();
    }
    await _controller.close();
  }

  Future<void> _closeShell(int serverId) async {
    final shell = _shells.remove(serverId);
    await shell?.stdin.close();
    await _closeTerminal(serverId);
  }

  Future<void> _closeTerminal(int serverId) async {
    await _terminalBindings.remove(serverId)?.close();
  }
}
