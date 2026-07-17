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
    this.collectStats = true,
    this.collectSystemInfo = true,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final ServerCredential credential;
  final bool collectStats;
  final bool collectSystemInfo;
}

enum SessionStatus { connecting, connected, failed, closed }

class ServerStats {
  const ServerStats({
    required this.collectorId,
    required this.updatedAt,
    this.loadAverage,
    this.memoryTotalKb,
    this.memoryAvailableKb,
    this.uptime,
  });

  final String collectorId;
  final DateTime updatedAt;
  final double? loadAverage;
  final int? memoryTotalKb;
  final int? memoryAvailableKb;
  final Duration? uptime;
}

class ServerSystemInfo {
  const ServerSystemInfo({this.distribution, this.kernel});

  final String? distribution;
  final String? kernel;
}

class SshSessionInfo {
  const SshSessionInfo({
    required this.serverId,
    required this.serverName,
    required this.connectedAt,
    required this.status,
    this.error,
    this.stats,
    this.systemInfo,
  });

  final int serverId;
  final String serverName;
  final DateTime connectedAt;
  final SessionStatus status;
  final String? error;
  final ServerStats? stats;
  final ServerSystemInfo? systemInfo;

  SshSessionInfo copyWith({
    SessionStatus? status,
    String? error,
    ServerStats? stats,
    ServerSystemInfo? systemInfo,
  }) => SshSessionInfo(
    serverId: serverId,
    serverName: serverName,
    connectedAt: connectedAt,
    status: status ?? this.status,
    error: error ?? this.error,
    stats: stats ?? this.stats,
    systemInfo: systemInfo ?? this.systemInfo,
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
