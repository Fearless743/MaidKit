import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/github/github_models.dart';
import 'package:maid_kit/github/github_repository.dart';
import 'package:maid_kit/github/github_token_store.dart';
import 'package:maid_kit/servers/database_backup_service.dart';
import 'package:maid_kit/servers/vault_service.dart';

/// drift_flutter resolves its native database directory through
/// path_provider; point it at the system temp directory in tests.
void _mockPathProvider() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        return Directory.systemTemp.path;
      });
}

AppDatabase _database() {
  final directory = Directory.systemTemp.createTempSync('github_test');
  return AppDatabase(filePath: '${directory.path}/test.sqlite');
}

Map<String, Object?> _emptyPayload() => {
  'version': 3,
  'servers': <Object>[],
  'savedCredentials': <Object>[],
  'composeProjectLinks': <Object>[],
  'containerCacheEntries': <Object>[],
  'deploymentProjects': <Object>[],
  'deploymentResources': <Object>[],
  'scriptSnippets': <Object>[],
};

void main() {
  _mockPathProvider();

  group('GitHubRepository', () {
    test('saveConnection inserts then updates the same login', () async {
      final database = _database();
      addTearDown(database.close);
      final repository = GitHubRepository(
        database,
        InMemoryGitHubTokenStorage(),
      );

      final first = await repository.saveConnection(
        const GitHubAccount(
          login: 'octocat',
          name: 'Octo Cat',
          avatarUrl: 'https://example.com/a.png',
        ),
      );
      final second = await repository.saveConnection(
        const GitHubAccount(
          login: 'octocat',
          name: 'Octocat',
          avatarUrl: 'https://example.com/b.png',
        ),
      );
      expect(second.id, first.id);
      expect(await repository.watchConnections().first, hasLength(1));
      expect(second.accountName, 'Octocat');
      expect(second.avatarUrl, 'https://example.com/b.png');
    });

    test('pinRepo is idempotent and unpin removes the pin', () async {
      final database = _database();
      addTearDown(database.close);
      final repository = GitHubRepository(
        database,
        InMemoryGitHubTokenStorage(),
      );
      final connection = await repository.saveConnection(
        const GitHubAccount(login: 'octocat', name: '', avatarUrl: ''),
      );

      const repo = GitHubRepoRef(owner: 'octocat', name: 'hello');
      await repository.pinRepo(connection.id, repo);
      await repository.pinRepo(connection.id, repo);
      var pins = await repository.watchRepoPins().first;
      expect(pins, hasLength(1));
      expect(pins.single.name, 'hello');

      await repository.unpinRepo(pins.single);
      pins = await repository.watchRepoPins().first;
      expect(pins, isEmpty);
    });

    test('token stays out of the database', () async {
      final database = _database();
      addTearDown(database.close);
      final storage = InMemoryGitHubTokenStorage();
      final repository = GitHubRepository(database, storage);
      await repository.saveToken('octocat', 'secret-token');
      expect(await repository.tokenFor('octocat'), 'secret-token');
      await repository.removeToken('octocat');
      expect(await repository.tokenFor('octocat'), isNull);
    });

    test('removeConnection cascades pins', () async {
      final database = _database();
      addTearDown(database.close);
      final repository = GitHubRepository(
        database,
        InMemoryGitHubTokenStorage(),
      );
      final connection = await repository.saveConnection(
        const GitHubAccount(login: 'octocat', name: '', avatarUrl: ''),
      );
      await repository.pinRepo(
        connection.id,
        const GitHubRepoRef(owner: 'o', name: 'r'),
      );
      await repository.removeConnection(connection);
      expect(await repository.watchRepoPins().first, isEmpty);
      expect(await repository.watchConnections().first, isEmpty);
    });
  });

  group('DatabaseBackupService GitHub sync', () {
    test('exportPayload includes GitHub metadata', () async {
      final database = _database();
      addTearDown(database.close);
      final repository = GitHubRepository(
        database,
        InMemoryGitHubTokenStorage(),
      );
      await repository.saveConnection(
        const GitHubAccount(
          login: 'octocat',
          name: 'Octo Cat',
          avatarUrl: 'https://example.com/a.png',
        ),
      );
      final service = DatabaseBackupService(database, VaultService(database));
      final payload = jsonDecode(await service.exportPayload()) as Map;
      final connections = payload['githubConnections'] as List;
      expect(connections, hasLength(1));
      final connection = connections.single as Map;
      expect(connection['accountLogin'], 'octocat');
      // Tokens never enter the syncable payload.
      expect(connection.containsKey('token'), isFalse);
    });

    test('importPayload restores connections and pins', () async {
      final database = _database();
      addTearDown(database.close);
      final service = DatabaseBackupService(database, VaultService(database));
      final payload = {
        ..._emptyPayload(),
        'githubConnections': [
          {
            'id': 1,
            'accountLogin': 'octocat',
            'accountName': 'Octo Cat',
            'avatarUrl': 'https://example.com/a.png',
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        'githubRepoPins': [
          {
            'id': 1,
            'connectionId': 1,
            'owner': 'octocat',
            'name': 'hello',
            'pinnedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      };
      await service.importPayload(jsonEncode(payload));

      final repository = GitHubRepository(
        database,
        InMemoryGitHubTokenStorage(),
      );
      final connections = await repository.watchConnections().first;
      expect(connections.single.accountLogin, 'octocat');
      final pins = await repository.watchRepoPins().first;
      expect(pins.single.owner, 'octocat');
    });

    test('importPayload tolerates archives without GitHub keys', () async {
      final database = _database();
      addTearDown(database.close);
      final service = DatabaseBackupService(database, VaultService(database));
      await service.importPayload(jsonEncode(_emptyPayload()));
      final repository = GitHubRepository(
        database,
        InMemoryGitHubTokenStorage(),
      );
      expect(await repository.watchConnections().first, isEmpty);
      expect(await repository.watchRepoPins().first, isEmpty);
    });
  });
}
