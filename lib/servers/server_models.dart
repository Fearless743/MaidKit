import 'dart:convert';

enum CredentialType { password, privateKey }

class SavedCredentialDraft {
  const SavedCredentialDraft({required this.name, required this.credential});

  final String name;
  final ServerCredential credential;
}

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
    this.credential,
    this.credentialId,
    this.credentialName,
    this.collectStats = true,
    this.collectSystemInfo = true,
  });

  final String name;
  final String host;
  final int port;
  final String username;

  /// A new credential to save, or an existing [credentialId] to reuse.
  final ServerCredential? credential;
  final int? credentialId;
  final String? credentialName;
  final bool collectStats;
  final bool collectSystemInfo;
}

enum SessionStatus { connecting, connected, failed, closed }

class ServerStats {
  const ServerStats({
    required this.collectorId,
    required this.updatedAt,
    this.loadAverage,
    this.loadAverage5,
    this.loadAverage15,
    this.cpuCount,
    this.memoryTotalKb,
    this.memoryAvailableKb,
    this.swapTotalKb,
    this.swapFreeKb,
    this.diskTotalKb,
    this.diskAvailableKb,
    this.uptime,
  });

  final String collectorId;
  final DateTime updatedAt;
  final double? loadAverage;
  final double? loadAverage5;
  final double? loadAverage15;
  final int? cpuCount;
  final int? memoryTotalKb;
  final int? memoryAvailableKb;
  final int? swapTotalKb;
  final int? swapFreeKb;
  final int? diskTotalKb;
  final int? diskAvailableKb;
  final Duration? uptime;
}

class ServerProcess {
  const ServerProcess({
    required this.pid,
    required this.user,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.rssKb,
    required this.command,
  });

  final int pid;
  final String user;
  final double cpuPercent;
  final double memoryPercent;
  final int rssKb;
  final String command;
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
