import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../shared/presentation/maidkit_alert.dart';

/// Configuration is deliberately opt-in and scoped to one local vault.
class CloudSyncConfiguration {
  const CloudSyncConfiguration({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceSlug,
    required this.blobId,
    required this.revision,
    this.pendingDownload = false,
    this.lastSyncedAt,
    this.lastContentFingerprint,
  });

  /// The WebDAV connection identifier ('webdav'). Kept for compatibility with
  /// the previous Solarpass configuration shape.
  final String workspaceId;

  /// Display name of the WebDAV connection.
  final String workspaceName;

  final String workspaceSlug;
  final String blobId;
  final int revision;
  final bool pendingDownload;
  final DateTime? lastSyncedAt;

  /// SHA-256 of the syncable content at the last successful sync. A matching
  /// fingerprint means the local database is unchanged and no upload is needed.
  final String? lastContentFingerprint;

  Map<String, Object?> toJson() => {
    'workspaceId': workspaceId,
    'workspaceName': workspaceName,
    'workspaceSlug': workspaceSlug,
    'blobId': blobId,
    'revision': revision,
    'pendingDownload': pendingDownload,
    'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
    'lastContentFingerprint': lastContentFingerprint,
  };

  factory CloudSyncConfiguration.fromJson(Map<String, dynamic> json) =>
      CloudSyncConfiguration(
        workspaceId: json['workspaceId'] as String? ?? 'webdav',
        workspaceName: json['workspaceName'] as String? ?? 'WebDAV',
        workspaceSlug: json['workspaceSlug'] as String? ?? 'webdav',
        blobId: json['blobId'] as String? ?? '',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        pendingDownload: json['pendingDownload'] == true,
        lastSyncedAt: DateTime.tryParse(
          json['lastSyncedAt'] as String? ?? '',
        )?.toLocal(),
        lastContentFingerprint: json['lastContentFingerprint'] as String?,
      );
}

/// A WebDAV vault directory discovered on the server.
class CloudWorkspace {
  const CloudWorkspace({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  factory CloudWorkspace.fromJson(Map<String, dynamic> json) => CloudWorkspace(
    id: json['id']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Untitled vault',
  );
}

/// A remote vault blob found on the WebDAV server.
class CloudVaultBlob {
  const CloudVaultBlob({
    required this.id,
    required this.revision,
    required this.updatedAt,
  });

  final String id;
  final int revision;
  final DateTime? updatedAt;

  factory CloudVaultBlob.fromJson(Map<String, dynamic> json) => CloudVaultBlob(
    id: json['blob_id']?.toString() ?? json['blobId']?.toString() ?? '',
    revision:
        (json['current_revision'] as num?)?.toInt() ??
        (json['currentRevision'] as num?)?.toInt() ??
        0,
    updatedAt: DateTime.tryParse(
      json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? '',
    )?.toLocal(),
  );
}

class CloudSyncException implements Exception {
  const CloudSyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum CloudSyncConflictResolution { downloadRemote, overwriteRemote }

/// Raised before either copy is changed when the WebDAV remote has a newer
/// revision.
class CloudSyncConflictException extends CloudSyncException {
  const CloudSyncConflictException({this.remoteRevision})
    : super('This vault has a newer cloud version.');

  final int? remoteRevision;
}

/// WebDAV transport for the encrypted vault archive.
///
/// Each vault syncs to a single `vault.mkb` archive plus a `vault.json`
/// sidecar that records the revision. Remote layout:
///
///   `maidkit-vaults/<blobId>/vault.mkb`
///   `maidkit-vaults/<blobId>/vault.json`
///
/// [blobId] is a stable per-vault identifier so multiple devices sharing one
/// WebDAV server can discover and adopt the same remote vault. The archive is
/// client-side encrypted with the vault passphrase (see [DatabaseBackupService]
/// and [VaultService.encryptPortable]); the server only ever sees ciphertext.
///
/// The WebDAV connection (server URL + credentials) is stored once in the
/// OS keychain under `maidkit_webdav_connection` and shared by all vaults.
class CloudSyncService {
  CloudSyncService({
    required String vaultId,
    FlutterSecureStorage? secureStorage,
  }) : _vaultKey = base64UrlEncode(utf8.encode(vaultId)),
       _storage = secureStorage ?? const FlutterSecureStorage();

  static const _connectionKey = 'maidkit_webdav_connection';
  static const _configurationKeyPrefix = 'maidkit_webdav_sync';
  static const _vaultRoot = 'maidkit-vaults';
  static const _vaultFileName = 'vault.mkb';
  static const _metadataFileName = 'vault.json';

  final String _vaultKey;
  final FlutterSecureStorage _storage;

  String get _configurationKey => '${_configurationKeyPrefix}_$_vaultKey';

  Future<CloudSyncConfiguration?> configuration() async {
    final raw = await _storage.read(key: _configurationKey);
    if (raw == null) return null;
    try {
      return CloudSyncConfiguration.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await disable();
      return null;
    }
  }

  Future<void> disable() => _storage.delete(key: _configurationKey);

  /// Whether WebDAV connection credentials have been configured.
  Future<bool> isConnected() async =>
      (await _storage.read(key: _connectionKey)) != null;

  /// The configured WebDAV connection, or null when not configured.
  Future<WebDavConnection?> connection() async {
    final raw = await _storage.read(key: _connectionKey);
    if (raw == null) return null;
    try {
      final values = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return WebDavConnection.fromJson(values);
    } catch (_) {
      return null;
    }
  }

  /// Stores the WebDAV connection credentials in the OS keychain.
  Future<void> saveConnection(WebDavConnection connection) => _storage.write(
    key: _connectionKey,
    value: jsonEncode(connection.toJson()),
  );

  Future<void> clearConnection() => _storage.delete(key: _connectionKey);

  /// Configures sync for this vault against a remote blob directory.
  ///
  /// When [existingBlob] is provided, the vault adopts that remote directory
  /// (used when downloading an existing remote vault).
  Future<CloudSyncConfiguration> enable({
    CloudVaultBlob? existingBlob,
    CloudWorkspace? workspace,
  }) async {
    final previous = await this.configuration();
    final reuseCurrentBlob =
        existingBlob == null &&
        previous?.workspaceId == 'webdav' &&
        previous?.blobId.isNotEmpty == true;
    final blobId =
        existingBlob?.id ??
        (reuseCurrentBlob ? previous!.blobId : const Uuid().v4());
    final configuration = CloudSyncConfiguration(
      workspaceId: 'webdav',
      workspaceName: workspace?.name ?? 'WebDAV',
      workspaceSlug: workspace?.slug ?? 'webdav',
      blobId: blobId,
      revision: reuseCurrentBlob
          ? previous!.revision
          : existingBlob?.revision ?? 0,
      pendingDownload: existingBlob != null,
      lastContentFingerprint: reuseCurrentBlob
          ? previous!.lastContentFingerprint
          : null,
    );
    await _storage.write(
      key: _configurationKey,
      value: jsonEncode(configuration.toJson()),
    );
    return configuration;
  }

  Future<void> completePendingDownload() async {
    final configuration = await this.configuration();
    if (configuration == null || !configuration.pendingDownload) return;
    await _saveConfiguration(
      CloudSyncConfiguration(
        workspaceId: configuration.workspaceId,
        workspaceName: configuration.workspaceName,
        workspaceSlug: configuration.workspaceSlug,
        blobId: configuration.blobId,
        revision: configuration.revision,
        lastSyncedAt: configuration.lastSyncedAt,
        lastContentFingerprint: configuration.lastContentFingerprint,
      ),
    );
  }

  /// Lists remote vault directories on the configured WebDAV server.
  Future<List<CloudVaultBlob>> listVaultBlobs() async {
    try {
      final client = await _client();
      final blobs = <CloudVaultBlob>[];
      final entries = await client.readDir(_vaultRoot);
      for (final entry in entries) {
        if (entry.isDir != true) continue;
        final blobId = entry.name;
        if (blobId == null || blobId.isEmpty) continue;
        final revision = await _readRevision(client, blobId);
        if (revision <= 0) continue;
        blobs.add(
          CloudVaultBlob(
            id: blobId,
            revision: revision,
            updatedAt: entry.mTime,
          ),
        );
      }
      blobs.sort((a, b) => b.revision.compareTo(a.revision));
      return blobs;
    } catch (error) {
      throw CloudSyncException(_friendly(error));
    }
  }

  /// Uploads/downloads a client-encrypted archive. The remote revision is
  /// always read first. When the remote is newer and no [conflictResolution]
  /// is given, the user is asked whether to take the remote copy or keep the
  /// local one.
  ///
  /// When [contentFingerprint] is provided, the upload is skipped if it matches
  /// the fingerprint stored at the last successful sync and the local revision
  /// was not superseded.
  Future<CloudSyncConfiguration> sync({
    required String archive,
    required Future<void> Function(String archive) applyArchive,
    Future<String> Function()? contentFingerprint,
    CloudSyncConflictResolution? conflictResolution,
    int conflictRetryCount = 0,
  }) async {
    final configuration = await this.configuration();
    if (configuration == null) {
      throw const CloudSyncException('Link this vault to WebDAV sync first.');
    }
    try {
      final client = await _client();
      var remoteRevision = 0;
      try {
        remoteRevision = await _readRevision(client, configuration.blobId);
      } catch (_) {
        remoteRevision = 0;
      }
      var revision = configuration.revision;
      if (remoteRevision > revision) {
        final resolution =
            conflictResolution ?? await _resolveConflict(remoteRevision);
        if (resolution == CloudSyncConflictResolution.downloadRemote) {
          final bytes = await client.read(
            '$_vaultRoot/${configuration.blobId}/$_vaultFileName',
          );
          final remoteArchive = utf8.decode(bytes);
          await applyArchive(remoteArchive);
          final updated = _updatedConfiguration(
            configuration,
            revision: remoteRevision,
            contentFingerprint: await contentFingerprint?.call(),
          );
          await _saveConfiguration(updated);
          return updated;
        }
        revision = remoteRevision;
      }
      final fingerprint = await contentFingerprint?.call();
      if (fingerprint != null &&
          fingerprint == configuration.lastContentFingerprint &&
          revision == configuration.revision) {
        return configuration;
      }
      await client.write(
        '$_vaultRoot/${configuration.blobId}/$_vaultFileName',
        Uint8List.fromList(utf8.encode(archive)),
      );
      await _writeRevision(client, configuration.blobId, revision);
      final updated = _updatedConfiguration(
        configuration,
        revision: revision,
        contentFingerprint: fingerprint,
      );
      await _saveConfiguration(updated);
      return updated;
    } on CloudSyncException {
      rethrow;
    } catch (error) {
      throw CloudSyncException(_friendly(error));
    }
  }

  Future<CloudSyncConflictResolution> _resolveConflict(
    int remoteRevision,
  ) async {
    final useCloud = await showMaidKitCloudSyncConflictAlert(
      remoteRevision: remoteRevision,
    );
    return useCloud
        ? CloudSyncConflictResolution.downloadRemote
        : CloudSyncConflictResolution.overwriteRemote;
  }

  CloudSyncConfiguration _updatedConfiguration(
    CloudSyncConfiguration configuration, {
    required int revision,
    String? contentFingerprint,
  }) => CloudSyncConfiguration(
    workspaceId: configuration.workspaceId,
    workspaceName: configuration.workspaceName,
    workspaceSlug: configuration.workspaceSlug,
    blobId: configuration.blobId,
    revision: revision,
    pendingDownload: configuration.pendingDownload,
    lastSyncedAt: DateTime.now(),
    lastContentFingerprint:
        contentFingerprint ?? configuration.lastContentFingerprint,
  );

  Future<void> _saveConfiguration(CloudSyncConfiguration configuration) =>
      _storage.write(
        key: _configurationKey,
        value: jsonEncode(configuration.toJson()),
      );

  Future<webdav.Client> _client() async {
    final raw = await _storage.read(key: _connectionKey);
    if (raw == null) {
      throw const CloudSyncException(
        'WebDAV is not configured. Open Settings to set up your server.',
      );
    }
    final connection = WebDavConnection.tryParse(raw);
    if (connection == null) {
      throw const CloudSyncException('Invalid WebDAV configuration.');
    }
    final client = webdav.newClient(
      connection.url,
      user: connection.username,
      password: connection.password,
    );
    client.setConnectTimeout(15000);
    client.setSendTimeout(30000);
    client.setReceiveTimeout(60000);
    return client;
  }

  Future<int> _readRevision(webdav.Client client, String blobId) async {
    final path = '$_vaultRoot/$blobId';
    final entries = await client.readDir(path);
    for (final entry in entries) {
      if (entry.name == _metadataFileName) {
        final bytes = await client.read('$path/$_metadataFileName');
        try {
          final values = Map<String, dynamic>.from(
            jsonDecode(utf8.decode(bytes)) as Map,
          );
          return (values['revision'] as num?)?.toInt() ?? 0;
        } catch (_) {
          return 0;
        }
      }
    }
    return 0;
  }

  Future<void> _writeRevision(
    webdav.Client client,
    String blobId,
    int revision,
  ) async {
    await client.write(
      '$_vaultRoot/$blobId/$_metadataFileName',
      Uint8List.fromList(utf8.encode(jsonEncode({'revision': revision}))),
    );
  }

  String _friendly(Object error) {
    final message = error.toString();
    if (message.contains('401') || message.contains('403')) {
      return 'WebDAV authentication failed. Check your server URL and credentials.';
    }
    if (message.contains('404')) {
      return 'The WebDAV vault was not found on the server.';
    }
    if (message.contains('Connection') ||
        message.contains('Socket') ||
        message.contains('Timeout')) {
      return 'Unable to reach the WebDAV server. Check your connection and try again.';
    }
    return 'WebDAV request failed: $message';
  }
}

/// WebDAV server connection credentials stored in the OS keychain.
class WebDavConnection {
  const WebDavConnection({
    required this.url,
    required this.username,
    required this.password,
    this.name = 'WebDAV',
  });

  final String url;
  final String username;
  final String password;
  final String name;

  Map<String, Object?> toJson() => {
    'url': url,
    'username': username,
    'password': password,
    'name': name,
  };

  factory WebDavConnection.fromJson(Map<String, dynamic> json) =>
      WebDavConnection(
        url: json['url']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        password: json['password']?.toString() ?? '',
        name: json['name']?.toString() ?? 'WebDAV',
      );

  static WebDavConnection? tryParse(String raw) {
    try {
      return WebDavConnection.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
