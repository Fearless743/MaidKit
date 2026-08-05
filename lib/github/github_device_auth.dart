import 'package:dio/dio.dart';

import 'github_models.dart';

enum DeviceFlowError { expired, denied, network }

class DeviceFlowException implements Exception {
  const DeviceFlowException(this.kind, this.message);

  final DeviceFlowError kind;
  final String message;

  @override
  String toString() => message;
}

/// The GitHub OAuth device flow. The client shows a verification URL and user
/// code, then polls for the token. No client secret is involved: the flow
/// does not require one, and a secret shipped in a desktop binary would be
/// extractable anyway.
class GithubDeviceAuth {
  GithubDeviceAuth({required this.clientId, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://github.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  final String clientId;
  final Dio _dio;

  /// Client ID injected at build time with `--dart-define=GITHUB_CLIENT_ID`.
  /// Defaults to the registered MaidKit OAuth App; the value is public by
  /// design (the device flow never uses a client secret).
  static const configuredClientId = String.fromEnvironment(
    'GITHUB_CLIENT_ID',
    defaultValue: 'Ov23litQFe90XESYASt8',
  );

  /// The scopes this integration needs: `repo` reads Actions runs, jobs,
  /// check-runs, releases, and pull requests; `read:user` reads the profile.
  static const scope = 'repo read:user';

  Future<GitHubDeviceCode> requestDeviceCode({
    String scope = GithubDeviceAuth.scope,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/login/device/code',
        data: {'client_id': clientId, 'scope': scope},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // Without this header GitHub answers with form-encoded text
          // instead of JSON, which dio would hand back as a raw string.
          headers: const {'Accept': 'application/json'},
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const DeviceFlowException(
          DeviceFlowError.network,
          'Unexpected GitHub device-flow response.',
        );
      }
      return GitHubDeviceCode.fromJson(data);
    } on DioException catch (error) {
      throw DeviceFlowException(
        DeviceFlowError.network,
        'Could not start GitHub sign-in: ${error.message}',
      );
    }
  }

  /// Polls for the access token. Returns the token once the user authorizes,
  /// `null` while GitHub still waits (`authorization_pending` / `slow_down`),
  /// and throws on `expired_token` / `access_denied`.
  Future<String?> pollAccessToken(GitHubDeviceCode code) async {
    try {
      final response = await _dio.post<dynamic>(
        '/login/oauth/access_token',
        data: {
          'client_id': clientId,
          'device_code': code.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const DeviceFlowException(
          DeviceFlowError.network,
          'Unexpected GitHub token response.',
        );
      }
      final error = data['error'] as String?;
      if (error != null) {
        switch (error) {
          case 'authorization_pending':
          case 'slow_down':
            return null;
          case 'expired_token':
            throw const DeviceFlowException(
              DeviceFlowError.expired,
              'The sign-in code expired. Start again.',
            );
          case 'access_denied':
            throw const DeviceFlowException(
              DeviceFlowError.denied,
              'Sign-in was declined.',
            );
          default:
            throw DeviceFlowException(
              DeviceFlowError.network,
              'GitHub sign-in failed: $error',
            );
        }
      }
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const DeviceFlowException(
          DeviceFlowError.network,
          'GitHub returned no access token.',
        );
      }
      return token;
    } on DioException catch (error) {
      throw DeviceFlowException(
        DeviceFlowError.network,
        'Could not reach GitHub: ${error.message}',
      );
    }
  }
}
