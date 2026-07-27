import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:openmls/openmls.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Configuration is deliberately opt-in and scoped to one local vault.
class CloudSyncConfiguration {
  const CloudSyncConfiguration({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceSlug,
    required this.blobId,
    required this.revision,
    required this.cursor,
    this.lastSyncedAt,
  });

  final String workspaceId;
  final String workspaceName;
  final String workspaceSlug;
  final String blobId;
  final int revision;
  final int cursor;
  final DateTime? lastSyncedAt;

  Map<String, Object?> toJson() => {
    'workspaceId': workspaceId,
    'workspaceName': workspaceName,
    'workspaceSlug': workspaceSlug,
    'blobId': blobId,
    'revision': revision,
    'cursor': cursor,
    'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
  };

  factory CloudSyncConfiguration.fromJson(Map<String, dynamic> json) =>
      CloudSyncConfiguration(
        workspaceId: json['workspaceId'] as String,
        workspaceName: json['workspaceName'] as String,
        workspaceSlug: json['workspaceSlug'] as String,
        blobId: json['blobId'] as String? ?? const Uuid().v4(),
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        cursor: (json['cursor'] as num?)?.toInt() ?? 0,
        lastSyncedAt: DateTime.tryParse(json['lastSyncedAt'] as String? ?? ''),
      );
}

class CloudWorkspace {
  const CloudWorkspace({
    required this.id,
    required this.slug,
    required this.name,
    required this.plan,
  });

  final String id;
  final String slug;
  final String name;
  final int plan;
  bool get supportsSync => plan >= 1;

  factory CloudWorkspace.fromJson(Map<String, dynamic> json) => CloudWorkspace(
    id: json['id']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Untitled workspace',
    plan: (json['plan'] as num?)?.toInt() ?? 0,
  );
}

class CloudUser {
  const CloudUser({required this.name, required this.handle, this.avatarUrl});

  final String name;
  final String handle;
  final String? avatarUrl;

  String get initials {
    final value = name.trim();
    return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
  }

  factory CloudUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : const <String, dynamic>{};
    final picture = profile['picture'] ?? json['picture'];
    final pictureData = picture is Map
        ? Map<String, dynamic>.from(picture)
        : const <String, dynamic>{};
    final storageUrl =
        pictureData['storage_url']?.toString() ??
        pictureData['storageUrl']?.toString() ??
        pictureData['url']?.toString();
    final id = pictureData['id']?.toString();
    final handle = json['name']?.toString() ?? '';
    final displayName = json['nick']?.toString();
    return CloudUser(
      name: displayName?.isNotEmpty == true
          ? displayName!
          : handle.isNotEmpty
          ? '@$handle'
          : 'Solar Network user',
      handle: handle.isEmpty ? '' : '@$handle',
      avatarUrl:
          storageUrl ??
          (id == null ? null : '${CloudSyncService.apiBase}/drive/files/$id'),
    );
  }
}

class CloudSyncException implements Exception {
  const CloudSyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

String _apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final values = Map<String, dynamic>.from(data);
    final message = values['detail'] ?? values['message'] ?? values['error'];
    if (message != null && message.toString().isNotEmpty) {
      return message.toString();
    }
  }
  final status = error.response?.statusCode;
  return status == null
      ? 'Unable to reach Solarpass. Check your connection and try again.'
      : 'Solarpass request failed (HTTP $status).';
}

/// Solarpass authorization, encrypted MLS state, and Flywheel transport.
class CloudSyncService {
  CloudSyncService({
    required String vaultId,
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  }) : _vaultKey = base64UrlEncode(utf8.encode(vaultId)),
       _storage = secureStorage ?? const FlutterSecureStorage(),
       _dio = dio ?? Dio();

  static const apiBase = 'https://api.solian.app';
  static const appId = 'dev.solsynth.maidkit';
  static const _clientId = 'maidkit';
  static const _callbackScheme = 'maidkit';
  static const _redirectUri = '$_callbackScheme://oauth/callback';
  static const _sessionKey = 'maidkit_solar_network_oauth_session';
  static const _schemeVersion = 1;
  static const _ciphersuite =
      MlsCiphersuite.mls128DhkemX25519Aes128GcmSha256Ed25519;

  final String _vaultKey;
  final FlutterSecureStorage _storage;
  final Dio _dio;

  String get _configurationKey => 'maidkit_cloud_sync_$_vaultKey';
  String get _deviceIdKey => 'maidkit_mls_device_$_vaultKey';
  String get _databaseKey => 'maidkit_mls_database_key_$_vaultKey';
  String get _signerPrivateKey => 'maidkit_mls_signer_private_$_vaultKey';
  String get _signerPublicKey => 'maidkit_mls_signer_public_$_vaultKey';

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

  Future<CloudUser?> currentUser() async {
    final session = await _validSession();
    if (session == null) return null;
    final response = await _authorizedGet('/passport/accounts/me', session);
    final data = response.data;
    return data is Map
        ? CloudUser.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  Future<CloudUser> signIn() async {
    try {
      await _signIn();
      final user = await currentUser();
      if (user == null) {
        throw const CloudSyncException('Unable to load the signed-in account.');
      }
      return user;
    } on DioException catch (error) {
      throw CloudSyncException(_apiErrorMessage(error));
    }
  }

  Future<List<CloudWorkspace>> listWorkspaces() async {
    final session = await _validSession();
    return session == null ? const [] : _listWorkspaces(session);
  }

  Future<List<CloudWorkspace>> signInAndListWorkspaces() async {
    try {
      final session = await _validSession() ?? await _signIn();
      return _listWorkspaces(session);
    } on DioException catch (error) {
      throw CloudSyncException(_apiErrorMessage(error));
    }
  }

  Future<List<CloudWorkspace>> _listWorkspaces(_Session session) async {
    final response = await _authorizedGet('/valve/workspaces', session);
    final entries = response.data;
    if (entries is! List) {
      throw const CloudSyncException('Invalid workspace response.');
    }
    return entries
        .whereType<Map>()
        .map(
          (entry) => CloudWorkspace.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((workspace) => workspace.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<CloudSyncConfiguration> enable(CloudWorkspace workspace) async {
    try {
      final session = await _validSession();
      if (session == null) {
        throw const CloudSyncException(
          'Sign in is required to enable cloud sync.',
        );
      }
      final planResponse = await _authorizedGet(
        '/valve/workspaces/${workspace.id}/plan/status',
        session,
      );
      final plan = ((planResponse.data as Map?)?['plan'] as num?)?.toInt() ?? 0;
      if (plan < 1) {
        throw const CloudSyncException(
          'Cloud sync requires a Pro or Enterprise workspace.',
        );
      }
      // Start from the beginning. A newly linked device needs the most recent
      // encrypted snapshot already in the stream, not just future updates.
      final cursor = 0;
      final configuration = CloudSyncConfiguration(
        workspaceId: workspace.id,
        workspaceName: workspace.name,
        workspaceSlug: workspace.slug,
        blobId: const Uuid().v4(),
        revision: 0,
        cursor: cursor,
      );
      await _storage.write(
        key: _configurationKey,
        value: jsonEncode(configuration.toJson()),
      );
      return configuration;
    } on DioException catch (error) {
      throw CloudSyncException(_apiErrorMessage(error));
    }
  }

  /// Uploads/downloads a client-encrypted archive. Flywheel never decrypts it.
  Future<CloudSyncConfiguration> sync({
    required String archive,
    required Future<void> Function(String archive) applyArchive,
    bool pullRemote = true,
  }) async {
    final configuration = await this.configuration();
    if (configuration == null) throw const CloudSyncException('Link this vault to a cloud workspace first.');
    try {
      final session = await _validSession();
      if (session == null) throw const CloudSyncException('Sign in is required to sync this vault.');
      var revision = configuration.revision;
      if (pullRemote) {
        var remoteRevision = 0;
        try {
          final metadata = await _authorizedGet('/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/blobs/${configuration.blobId}', session);
          remoteRevision = ((metadata.data as Map?)?['current_revision'] as num?)?.toInt() ?? 0;
        } on DioException catch (error) {
          if (error.response?.statusCode != 404) rethrow;
        }
        if (remoteRevision > revision) {
          final content = await _dio.get<List<int>>('$apiBase/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/blobs/${configuration.blobId}/content', options: Options(headers: {'Authorization': 'Bearer ${session.accessToken}'}, responseType: ResponseType.bytes));
          final remoteArchive = utf8.decode(content.data ?? const []);
          await applyArchive(remoteArchive);
          final updated = CloudSyncConfiguration(workspaceId: configuration.workspaceId, workspaceName: configuration.workspaceName, workspaceSlug: configuration.workspaceSlug, blobId: configuration.blobId, revision: remoteRevision, cursor: configuration.cursor, lastSyncedAt: DateTime.now());
          await _storage.write(key: _configurationKey, value: jsonEncode(updated.toJson()));
          return updated;
        }
      }
      final response = await _dio.put<Map<String, dynamic>>('$apiBase/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/blobs/${configuration.blobId}', data: FormData.fromMap({'file': MultipartFile.fromBytes(utf8.encode(archive), filename: 'vault.mkb'), 'scheme_version': _schemeVersion, 'expected_revision': revision}), options: Options(headers: {'Authorization': 'Bearer ${session.accessToken}'}));
      revision = (response.data?['revision'] as num?)?.toInt() ?? (revision + 1);
      final updated = CloudSyncConfiguration(workspaceId: configuration.workspaceId, workspaceName: configuration.workspaceName, workspaceSlug: configuration.workspaceSlug, blobId: configuration.blobId, revision: revision, cursor: configuration.cursor, lastSyncedAt: DateTime.now());
      await _storage.write(key: _configurationKey, value: jsonEncode(updated.toJson()));
      return updated;
    } on DioException catch (error) { throw CloudSyncException(_apiErrorMessage(error)); }
  }

  /// Legacy MLS implementation retained temporarily for migration testing.
  /// Pulls remote MLS messages, applies their newest vault snapshot, and then
  /// uploads this device's current snapshot. [applyPayload] is invoked only
  /// after OpenMLS authenticates and decrypts an application message.
  Future<CloudSyncConfiguration> syncMlsLegacy({
    required String payload,
    required Future<void> Function(String payload) applyPayload,
    bool pullRemote = true,
  }) async {
    final configuration = await this.configuration();
    if (configuration == null) {
      throw const CloudSyncException(
        'Link this vault to a cloud workspace first.',
      );
    }
    try {
      final session = await _validSession();
      if (session == null) {
        throw const CloudSyncException(
          'Sign in is required to sync this vault.',
        );
      }
      final deviceId = await _deviceId();
      await _authorizedPost(
        '/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/devices',
        session,
        data: {'device_id': deviceId, 'label': Platform.operatingSystem},
      );
      await Openmls.init();
      final engine = await _engine();
      try {
        final signer = await _signer();
        final groupId = 'flywheel:${configuration.workspaceId}:$appId';
        final groupIdBytes = Uint8List.fromList(utf8.encode(groupId));
        final canUploadSnapshot = await _ensureGroup(
          engine: engine,
          signer: signer,
          groupId: groupId,
          groupIdBytes: groupIdBytes,
          deviceId: deviceId,
          configuration: configuration,
          session: session,
        );

        var cursor = configuration.cursor;
        while (pullRemote) {
          final response = await _authorizedGet(
            '/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/'
            'operations?after=$cursor&limit=100',
            session,
          );
          final records = response.data is List
              ? List<Map<String, dynamic>>.from(
                  (response.data as List).whereType<Map>().map(
                    Map<String, dynamic>.from,
                  ),
                )
              : const <Map<String, dynamic>>[];
          if (records.isEmpty) break;
          for (final record in records) {
            cursor = (record['cursor'] as num?)?.toInt() ?? cursor;
            if (record['device_id']?.toString() == deviceId) continue;
            final ciphertext = record['ciphertext'];
            if (ciphertext is! String) continue;
            try {
              final processed = await engine.processMessage(
                groupIdBytes: groupIdBytes,
                messageBytes: base64Decode(ciphertext),
              );
              if (processed.hasStagedCommit) {
                await engine.mergePendingCommit(groupIdBytes: groupIdBytes);
              }
              final message = processed.applicationMessage;
              if (message == null) continue;
              final envelope = jsonDecode(utf8.decode(message));
              if (envelope is Map && envelope['type'] == 'vault-snapshot') {
                final remotePayload = envelope['payload'];
                if (remotePayload is String) await applyPayload(remotePayload);
              }
            } catch (_) {
              // MLS intentionally cannot decrypt messages from before this
              // device joined the group. Later operations remain valid.
            }
          }
          if (records.length < 100) break;
        }
        if (canUploadSnapshot) {
          final ciphertext = await engine.createMessage(
            groupIdBytes: groupIdBytes,
            signerBytes: signer.bytes,
            message: utf8.encode(
              jsonEncode({'type': 'vault-snapshot', 'payload': payload}),
            ),
          );
          await _authorizedPost(
            '/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/operations',
            session,
            data: {
              'device_id': deviceId,
              'operations': [
                {
                  'operation_id': const Uuid().v4(),
                  'scheme_version': _schemeVersion,
                  'ciphertext': base64Encode(ciphertext.ciphertext),
                },
              ],
            },
          );
        }
        if (cursor > configuration.cursor) {
          await _authorizedPost(
            '/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/acknowledgements',
            session,
            data: {'device_id': deviceId, 'cursor': cursor},
          );
        }
        final updated = CloudSyncConfiguration(
          workspaceId: configuration.workspaceId,
          workspaceName: configuration.workspaceName,
          workspaceSlug: configuration.workspaceSlug,
          blobId: configuration.blobId,
          revision: configuration.revision,
          cursor: cursor,
          lastSyncedAt: DateTime.now(),
        );
        await _storage.write(
          key: _configurationKey,
          value: jsonEncode(updated.toJson()),
        );
        return updated;
      } finally {
        await engine.close();
      }
    } on DioException catch (error) {
      throw CloudSyncException(_apiErrorMessage(error));
    } on CloudSyncException {
      rethrow;
    } catch (error) {
      throw CloudSyncException('Unable to encrypt or sync this vault: $error');
    }
  }

  Future<bool> _ensureGroup({
    required MlsEngine engine,
    required _StoredSigner signer,
    required String groupId,
    required Uint8List groupIdBytes,
    required String deviceId,
    required CloudSyncConfiguration configuration,
    required _Session session,
  }) async {
    // OpenMLS throws "No group found in storage" for a first sync rather than
    // returning false. That is the normal new-device path, not a failure.
    try {
      if (await engine.groupIsActive(groupIdBytes: groupIdBytes)) return true;
    } catch (_) {
      // Create or externally join below.
    }
    try {
      // Padlock gates group-info access on a device membership. Bootstrap only
      // creates the group state; it deliberately does not add this device.
      await _registerMlsMembership(session, deviceId, groupId, epoch: 0);
      final response = await _authorizedE2eeGet(
        '/padlock/e2ee/mls/groups/$groupId/groupinfo',
        session,
        deviceId,
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final groupInfo = data['group_info']?.toString();
      if (groupInfo == null || groupInfo.isEmpty) {
        throw const CloudSyncException(
          'Cloud MLS group information is missing.',
        );
      }
      final external = await engine.joinGroupExternalCommit(
        config: MlsGroupConfig.defaultConfig(ciphersuite: _ciphersuite),
        groupInfoBytes: base64Decode(groupInfo),
        ratchetTreeBytes: data['ratchet_tree'] == null
            ? null
            : base64Decode(data['ratchet_tree'].toString()),
        signerBytes: signer.bytes,
        credentialIdentity: utf8.encode(deviceId),
        signerPublicKey: signer.publicKey,
      );
      // An external join is itself an MLS commit. Distribute it through the
      // opaque Flywheel stream before merging local state, so existing devices
      // advance to the same epoch before they see later application messages.
      await _authorizedPost(
        '/flywheel/workspaces/${configuration.workspaceId}/apps/$appId/operations',
        session,
        data: {
          'device_id': deviceId,
          'operations': [
            {
              'operation_id': const Uuid().v4(),
              'scheme_version': _schemeVersion,
              'ciphertext': base64Encode(external.commit),
            },
          ],
        },
      );
      await engine.mergePendingCommit(groupIdBytes: external.groupId);
      final epoch = await engine.groupEpoch(groupIdBytes: groupIdBytes);
      await _registerMlsMembership(
        session,
        deviceId,
        groupId,
        epoch: epoch.toInt(),
      );
      await _uploadGroupInfo(
        engine,
        signer,
        groupId,
        groupIdBytes,
        session,
        deviceId,
      );
      // A joining device must wait for an existing device to publish a new
      // snapshot after it processes the commit. It cannot read old MLS data.
      return false;
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
      await _authorizedE2eePost(
        '/padlock/e2ee/mls/groups/$groupId/bootstrap',
        session,
        deviceId,
        data: {
          'epoch': 0,
          'state_version': 1,
          'meta': {'bootstrap_device_id': deviceId},
        },
      );
      await engine.createGroup(
        config: MlsGroupConfig.defaultConfig(ciphersuite: _ciphersuite),
        signerBytes: signer.bytes,
        credentialIdentity: utf8.encode(deviceId),
        signerPublicKey: signer.publicKey,
        groupId: groupIdBytes,
      );
      await _registerMlsMembership(session, deviceId, groupId, epoch: 0);
      await _uploadGroupInfo(
        engine,
        signer,
        groupId,
        groupIdBytes,
        session,
        deviceId,
      );
      return true;
    }
  }

  Future<void> _registerMlsMembership(
    _Session session,
    String deviceId,
    String groupId, {
    required int epoch,
  }) => _authorizedE2eePost(
    '/padlock/e2ee/mls/devices/$deviceId/membership',
    session,
    deviceId,
    data: {'group_id': groupId, 'epoch': epoch},
  );

  Future<void> _uploadGroupInfo(
    MlsEngine engine,
    _StoredSigner signer,
    String groupId,
    Uint8List groupIdBytes,
    _Session session,
    String deviceId,
  ) async {
    final groupInfo = await engine.exportGroupInfo(
      groupIdBytes: groupIdBytes,
      signerBytes: signer.bytes,
    );
    final ratchetTree = await engine.exportRatchetTree(
      groupIdBytes: groupIdBytes,
    );
    final epoch = await engine.groupEpoch(groupIdBytes: groupIdBytes);
    await _authorizedE2eePut(
      '/padlock/e2ee/mls/groups/$groupId/groupinfo',
      session,
      deviceId,
      data: {
        'group_info': base64Encode(groupInfo),
        'ratchet_tree': base64Encode(ratchetTree),
        'epoch': epoch.toInt(),
      },
    );
  }

  Future<String> _deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final value = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: value);
    return value;
  }

  Future<MlsEngine> _engine() async {
    var encodedKey = await _storage.read(key: _databaseKey);
    if (encodedKey == null) {
      encodedKey = base64Encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await _storage.write(key: _databaseKey, value: encodedKey);
    }
    final directory = await getApplicationSupportDirectory();
    final mlsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}mls',
    );
    if (!await mlsDirectory.exists()) {
      await mlsDirectory.create(recursive: true);
    }
    return MlsEngine.create(
      dbPath: '${mlsDirectory.path}${Platform.pathSeparator}$_vaultKey.db',
      encryptionKey: base64Decode(encodedKey),
    );
  }

  Future<_StoredSigner> _signer() async {
    final privateEncoded = await _storage.read(key: _signerPrivateKey);
    final publicEncoded = await _storage.read(key: _signerPublicKey);
    if (privateEncoded != null && publicEncoded != null) {
      final privateKey = base64Decode(privateEncoded);
      final publicKey = base64Decode(publicEncoded);
      return _StoredSigner(privateKey, publicKey);
    }
    final pair = MlsSignatureKeyPair.generate(ciphersuite: _ciphersuite);
    final privateKey = pair.privateKey();
    final publicKey = pair.publicKey();
    await _storage.write(
      key: _signerPrivateKey,
      value: base64Encode(privateKey),
    );
    await _storage.write(key: _signerPublicKey, value: base64Encode(publicKey));
    return _StoredSigner(privateKey, publicKey);
  }

  Future<_Session> _signIn() async {
    final configuration = await _discover();
    final verifier = _randomUrlSafe(64);
    final state = _randomUrlSafe(32);
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    final url = configuration.authorizationEndpoint.replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': '*',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );
    final callback = Uri.parse(
      await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: _callbackScheme,
      ),
    );
    if (callback.queryParameters['state'] != state) {
      throw const CloudSyncException(
        'The authorization response could not be verified.',
      );
    }
    final error = callback.queryParameters['error'];
    if (error != null) {
      throw CloudSyncException(
        callback.queryParameters['error_description'] ?? error,
      );
    }
    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const CloudSyncException(
        'The authorization server did not return an authorization code.',
      );
    }
    final session = await _exchange(configuration.tokenEndpoint, {
      'grant_type': 'authorization_code',
      'client_id': _clientId,
      'code': code,
      'redirect_uri': _redirectUri,
      'code_verifier': verifier,
    });
    await _saveSession(session);
    return session;
  }

  Future<_Session?> _validSession() async {
    final session = await _readSession();
    if (session == null || !session.needsRefresh) return session;
    if (session.refreshToken == null || session.refreshToken!.isEmpty) {
      return null;
    }
    try {
      final refreshed = await _exchange((await _discover()).tokenEndpoint, {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': session.refreshToken!,
      }, previous: session);
      await _saveSession(refreshed);
      return refreshed;
    } on DioException {
      return null;
    }
  }

  Future<_OidcConfiguration> _discover() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$apiBase/.well-known/openid-configuration',
    );
    final data = response.data;
    if (data == null) {
      throw const CloudSyncException('Unable to load sign-in configuration.');
    }
    return _OidcConfiguration.fromJson(data);
  }

  Future<Response<dynamic>> _authorizedGet(String path, _Session session) =>
      _dio.get<dynamic>(
        '$apiBase$path',
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );

  Future<Response<dynamic>> _authorizedPost(
    String path,
    _Session session, {
    Object? data,
  }) => _dio.post<dynamic>(
    '$apiBase$path',
    data: data,
    options: Options(
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    ),
  );

  Future<Response<dynamic>> _authorizedE2eeGet(
    String path,
    _Session session,
    String deviceId,
  ) => _dio.get<dynamic>(
    '$apiBase$path',
    options: Options(
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'X-Device-Id': deviceId,
      },
    ),
  );

  Future<Response<dynamic>> _authorizedE2eePost(
    String path,
    _Session session,
    String deviceId, {
    Object? data,
  }) => _dio.post<dynamic>(
    '$apiBase$path',
    data: data,
    options: Options(
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'X-Device-Id': deviceId,
      },
    ),
  );

  Future<Response<dynamic>> _authorizedE2eePut(
    String path,
    _Session session,
    String deviceId, {
    required Object data,
  }) => _dio.put<dynamic>(
    '$apiBase$path',
    data: data,
    options: Options(
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'X-Device-Id': deviceId,
      },
    ),
  );

  Future<_Session> _exchange(
    Uri endpoint,
    Map<String, String> fields, {
    _Session? previous,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint.toString(),
      data: fields,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = response.data ?? const <String, dynamic>{};
    final accessToken = (data['access_token'] ?? data['token']) as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const CloudSyncException(
        'The token response did not include an access token.',
      );
    }
    return _Session(
      accessToken: accessToken,
      refreshToken: data['refresh_token'] as String? ?? previous?.refreshToken,
      expiresAt: data['expires_in'] is num
          ? DateTime.now().add(
              Duration(seconds: (data['expires_in'] as num).toInt()),
            )
          : null,
    );
  }

  Future<_Session?> _readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return _Session.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  Future<void> _saveSession(_Session session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  String _randomUrlSafe(int length) => base64UrlEncode(
    List<int>.generate(length, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
}

class _OidcConfiguration {
  const _OidcConfiguration(this.authorizationEndpoint, this.tokenEndpoint);
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  factory _OidcConfiguration.fromJson(Map<String, dynamic> json) =>
      _OidcConfiguration(
        Uri.parse(json['authorization_endpoint'] as String),
        Uri.parse(json['token_endpoint'] as String),
      );
}

class _Session {
  const _Session({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  bool get needsRefresh =>
      expiresAt != null &&
      DateTime.now().isAfter(expiresAt!.subtract(const Duration(seconds: 30)));
  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
  };
  factory _Session.fromJson(Map<String, dynamic> json) => _Session(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String?,
    expiresAt: DateTime.tryParse(
      json['expires_at'] as String? ?? '',
    )?.toLocal(),
  );
}

class _StoredSigner {
  const _StoredSigner(this.privateKey, this.publicKey);

  final List<int> privateKey;
  final List<int> publicKey;

  Uint8List get bytes => serializeSigner(
    ciphersuite: CloudSyncService._ciphersuite,
    privateKey: privateKey,
    publicKey: publicKey,
  );
}
