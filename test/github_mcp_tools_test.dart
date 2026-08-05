import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:maid_kit/agent/local_mcp_server.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/github/github_models.dart';
import 'package:maid_kit/github/github_providers.dart';
import 'package:maid_kit/github/github_repository.dart';
import 'package:maid_kit/github/github_token_store.dart';
import 'package:maid_kit/servers/server_providers.dart';

/// LocalMcpToolExecutor takes a Riverpod [Ref]; the test provider yields one
/// bound to the container under test.
final testExecutorProvider = Provider<LocalMcpToolExecutor>((ref) {
  return LocalMcpToolExecutor(ref);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        return Directory.systemTemp.path;
      });

  group('LocalMcpToolExecutor GitHub surface', () {
    late AppDatabase database;
    late ProviderContainer container;
    late InMemoryGitHubTokenStorage storage;

    setUp(() {
      final directory = Directory.systemTemp.createTempSync('github_mcp_test');
      database = AppDatabase(filePath: '${directory.path}/test.sqlite');
      storage = InMemoryGitHubTokenStorage();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          githubTokenStoreProvider.overrideWithValue(storage),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    Future<void> waitForToken() async {
      final subscription = container.listen(
        githubTokenForConnectionProvider,
        (previous, next) {},
      );
      try {
        for (var i = 0; i < 40; i++) {
          if (subscription.read().value != null) return;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        fail('GitHub token never became available.');
      } finally {
        subscription.close();
      }
    }

    test(
      'hides GitHub tools until an account with a token is signed in',
      () async {
        final executor = container.read(testExecutorProvider);

        final before = await executor.toolDefinitions;
        final beforeNames = [for (final tool in before) tool['name']];
        expect(beforeNames, isNot(contains('github_list_runs')));
        expect(beforeNames, contains('list_servers'));

        final repository = GitHubRepository(database, storage);
        await repository.saveConnection(
          const GitHubAccount(login: 'octocat', name: '', avatarUrl: ''),
        );
        await repository.saveToken('octocat', 'secret');
        await waitForToken();

        final after = await executor.toolDefinitions;
        final afterNames = [for (final tool in after) tool['name']];
        expect(afterNames, contains('github_list_runs'));
        expect(afterNames, contains('github_list_jobs'));
        expect(afterNames, hasLength(greaterThan(beforeNames.length)));
      },
    );

    test(
      'hides GitHub tools when only the metadata synced without a token',
      () async {
        final repository = GitHubRepository(database, storage);
        // A connection row (e.g. synced from another device) with no token on
        // this device must still hide the tools.
        await repository.saveConnection(
          const GitHubAccount(login: 'octocat', name: '', avatarUrl: ''),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final executor = container.read(testExecutorProvider);
        final definitions = await executor.toolDefinitions;
        final names = [for (final tool in definitions) tool['name']];
        expect(names, isNot(contains('github_open_prs')));
      },
    );
  });
}
