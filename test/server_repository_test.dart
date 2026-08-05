import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_models.dart';
import 'package:maid_kit/servers/server_repository.dart';
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

void main() {
  _mockPathProvider();

  group('ServerRepository server configuration', () {
    late AppDatabase database;
    late ServerRepository repository;

    setUp(() {
      final directory = Directory.systemTemp.createTempSync(
        'server_config_test',
      );
      database = AppDatabase(filePath: '${directory.path}/test.sqlite');
      repository = ServerRepository(database, VaultService(database));
    });

    tearDown(() => database.close());

    Future<int> insertCredential() => database
        .into(database.savedCredentials)
        .insert(
          SavedCredentialsCompanion.insert(
            name: 'test',
            credentialType: CredentialType.password.name,
            encryptedCredential: 'x',
            credentialNonce: 'y',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    test('create persists environment, snippets, and tags', () async {
      final credentialId = await insertCredential();
      final server = await repository.create(
        ServerDraft(
          name: 'prod-db',
          host: '10.0.0.1',
          port: 22,
          username: 'root',
          credentialId: credentialId,
          environment: {'KUBECONFIG': '/etc/kubernetes/admin.conf'},
          initialSnippets: [3, 7],
          tags: ['prod', 'eu-west'],
        ),
      );

      expect(decodeEnvironmentMap(server.environment), {
        'KUBECONFIG': '/etc/kubernetes/admin.conf',
      });
      expect(decodeSnippetIdList(server.initialSnippets), [3, 7]);
      expect(decodeStringList(server.tags), ['prod', 'eu-west']);
    });

    test('update replaces the stored configuration', () async {
      final credentialId = await insertCredential();
      final server = await repository.create(
        ServerDraft(
          name: 'web',
          host: '10.0.0.2',
          port: 22,
          username: 'deploy',
          credentialId: credentialId,
          environment: {'STAGE': 'staging'},
          tags: ['staging'],
        ),
      );
      await repository.update(
        server,
        ServerDraft(
          name: 'web',
          host: '10.0.0.2',
          port: 22,
          username: 'deploy',
          credentialId: credentialId,
          environment: {'STAGE': 'production', 'PORT': '8080'},
          initialSnippets: [9],
          tags: ['prod'],
        ),
      );

      final updated = (await repository.all()).single;
      expect(decodeEnvironmentMap(updated.environment), {
        'STAGE': 'production',
        'PORT': '8080',
      });
      expect(decodeSnippetIdList(updated.initialSnippets), [9]);
      expect(decodeStringList(updated.tags), ['prod']);
    });

    test('empty configuration is stored as null', () async {
      final credentialId = await insertCredential();
      final server = await repository.create(
        ServerDraft(
          name: 'plain',
          host: '10.0.0.3',
          port: 22,
          username: 'user',
          credentialId: credentialId,
        ),
      );

      expect(server.environment, isNull);
      expect(server.initialSnippets, isNull);
      expect(server.tags, isNull);
      expect(decodeEnvironmentMap(server.environment), isEmpty);
      expect(decodeSnippetIdList(server.initialSnippets), isEmpty);
      expect(decodeStringList(server.tags), isEmpty);
    });
  });
}
