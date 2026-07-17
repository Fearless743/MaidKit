import 'dart:convert';

enum CredentialType { password, privateKey }

class ServerCredential {
  const ServerCredential.password(this.password)
    : type = CredentialType.password,
      privateKey = null,
      keyPassphrase = null;

  const ServerCredential.privateKey({
    required this.privateKey,
    this.keyPassphrase,
  }) : type = CredentialType.privateKey,
       password = null;

  final CredentialType type;
  final String? password;
  final String? privateKey;
  final String? keyPassphrase;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'password': password,
    'privateKey': privateKey,
    'keyPassphrase': keyPassphrase,
  };

  String encode() => jsonEncode(toJson());

  factory ServerCredential.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    final type = CredentialType.values.byName(json['type'] as String);
    return switch (type) {
      CredentialType.password => ServerCredential.password(
        json['password'] as String,
      ),
      CredentialType.privateKey => ServerCredential.privateKey(
        privateKey: json['privateKey'] as String,
        keyPassphrase: json['keyPassphrase'] as String?,
      ),
    };
  }
}

class ServerDraft {
  const ServerDraft({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.credential,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final ServerCredential credential;
}

enum SessionStatus { connecting, connected, failed, closed }

class SshSessionInfo {
  const SshSessionInfo({
    required this.serverId,
    required this.serverName,
    required this.connectedAt,
    required this.status,
    this.error,
  });

  final int serverId;
  final String serverName;
  final DateTime connectedAt;
  final SessionStatus status;
  final String? error;

  SshSessionInfo copyWith({SessionStatus? status, String? error}) =>
      SshSessionInfo(
        serverId: serverId,
        serverName: serverName,
        connectedAt: connectedAt,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

class HostKeyPrompt {
  const HostKeyPrompt({
    required this.algorithm,
    required this.fingerprint,
    this.replacesExisting = false,
  });

  final String algorithm;
  final String fingerprint;
  final bool replacesExisting;
}
