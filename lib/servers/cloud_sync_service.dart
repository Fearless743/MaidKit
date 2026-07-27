import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Configuration is deliberately opt-in and scoped to one local vault.
class CloudSyncConfiguration {
  const CloudSyncConfiguration({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceSlug,
    required this.cursor,
  });

  final String workspaceId;
  final String workspaceName;
  final String workspaceSlug;
  final int cursor;

  Map<String, Object> toJson() => {
    'workspaceId': workspaceId,
    'workspaceName': workspaceName,
    'workspaceSlug': workspaceSlug,
    'cursor': cursor,
  };

  factory CloudSyncConfiguration.fromJson(Map<String, dynamic> json) =>
      CloudSyncConfiguration(
        workspaceId: json['workspaceId'] as String,
        workspaceName: json['workspaceName'] as String,
        workspaceSlug: json['workspaceSlug'] as String,
        cursor: (json['cursor'] as num?)?.toInt() ?? 0,
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

/// Solar Network authorization and Flywheel stream setup.
///
/// The server receives only opaque, end-to-end encrypted operations. Enabling
/// this service creates no network activity until the user chooses a workspace.
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

  final String _vaultKey;
  final FlutterSecureStorage _storage;
  final Dio _dio;

  String get _configurationKey => 'maidkit_cloud_sync_$_vaultKey';

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
      final bootstrap = await _authorizedPost(
        '/flywheel/workspaces/${workspace.id}/apps/$appId/bootstrap',
        session,
      );
      final cursor =
          ((bootstrap.data as Map?)?['cursor'] as num?)?.toInt() ?? 0;
      final configuration = CloudSyncConfiguration(
        workspaceId: workspace.id,
        workspaceName: workspace.name,
        workspaceSlug: workspace.slug,
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

  Future<Response<dynamic>> _authorizedPost(String path, _Session session) =>
      _dio.post<dynamic>(
        '$apiBase$path',
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
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
