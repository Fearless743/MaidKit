import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage for GitHub access tokens. Tokens deliberately never enter the
/// vault database, backups, or cloud sync: each device keeps its own token
/// under a key derived from the account login, so a synced connection that
/// has no token on this device renders as signed-out.
abstract interface class GitHubTokenStorage {
  Future<String?> read(String login);

  Future<void> write(String login, String token);

  Future<void> delete(String login);
}

/// Keychain-backed token storage through [FlutterSecureStorage].
class SecureGitHubTokenStorage implements GitHubTokenStorage {
  SecureGitHubTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _prefix = 'maidkit_github_token';

  String _key(String login) => '${_prefix}_$login';

  @override
  Future<String?> read(String login) => _storage.read(key: _key(login));

  @override
  Future<void> write(String login, String token) =>
      _storage.write(key: _key(login), value: token);

  @override
  Future<void> delete(String login) => _storage.delete(key: _key(login));
}

/// In-memory token storage for tests.
class InMemoryGitHubTokenStorage implements GitHubTokenStorage {
  final Map<String, String> _tokens = {};

  @override
  Future<String?> read(String login) async => _tokens[login];

  @override
  Future<void> write(String login, String token) async =>
      _tokens[login] = token;

  @override
  Future<void> delete(String login) async => _tokens.remove(login);
}
