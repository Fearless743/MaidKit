import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:maid_kit/data/local/app_database.dart';

import 'vault_service.dart';

/// Creates portable, password-encrypted snapshots of the user-managed data.
///
/// Vault metadata is deliberately excluded: it is tied to the vault on this
/// device. Credentials are decrypted only while the archive is assembled and
/// are encrypted again with the destination vault key during import.
class DatabaseBackupService {
  DatabaseBackupService(this._database, this._vault);

  static const _formatVersion = 3;

  final AppDatabase _database;
  final VaultService _vault;

  Future<String> exportArchive(String password) async {
    final servers = await _database.select(_database.servers).get();
    final credentials = await _database
        .select(_database.savedCredentials)
        .get();
    final serverRecords = <Map<String, dynamic>>[];
    for (final server in servers) {
      final record = server.toJson()
        ..remove('encryptedCredential')
        ..remove('credentialNonce');
      if (server.encryptedCredential != null &&
          server.credentialNonce != null) {
        record['credential'] = await _vault.decrypt(
          EncryptedValue(
            bytes: server.encryptedCredential!,
            nonce: server.credentialNonce!,
          ),
          context: 'server-credential',
        );
      }
      serverRecords.add(record);
    }
    final credentialRecords = <Map<String, dynamic>>[];
    for (final credential in credentials) {
      final record = credential.toJson()
        ..remove('encryptedCredential')
        ..remove('credentialNonce');
      record['credential'] = await _vault.decrypt(
        EncryptedValue(
          bytes: credential.encryptedCredential,
          nonce: credential.credentialNonce,
        ),
        context: 'server-credential',
      );
      credentialRecords.add(record);
    }

    final archive = <String, Object?>{
      'version': _formatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'servers': serverRecords,
      'savedCredentials': credentialRecords,
      'composeProjectLinks':
          (await _database.select(_database.composeProjectLinks).get())
              .map((record) => record.toJson())
              .toList(),
      'containerCacheEntries':
          (await _database.select(_database.containerCacheEntries).get())
              .map((record) => record.toJson())
              .toList(),
      'deploymentProjects':
          (await _database.select(_database.deploymentProjects).get())
              .map((record) => record.toJson())
              .toList(),
      'deploymentResources':
          (await _database.select(_database.deploymentResources).get())
              .map((record) => record.toJson())
              .toList(),
      'scriptSnippets': (await _database.select(_database.scriptSnippets).get())
          .map((record) => record.toJson())
          .toList(),
    };
    return _vault.encryptPortable(jsonEncode(archive), password);
  }

  /// Replaces the portable database content while retaining this device's
  /// vault metadata and biometric setting.
  Future<void> importArchive(String archive, String password) async {
    final clearText = await _vault.decryptPortable(archive, password);
    final payload = jsonDecode(clearText);
    if (payload is! Map<String, dynamic> ||
        payload['version'] != _formatVersion) {
      throw const FormatException('Unsupported MaidKit backup.');
    }

    final servers = _records(payload, 'servers');
    final credentials = _records(payload, 'savedCredentials');
    final composeLinks = _records(payload, 'composeProjectLinks');
    final cacheEntries = _records(payload, 'containerCacheEntries');
    final projects = _records(payload, 'deploymentProjects');
    final resources = _records(payload, 'deploymentResources');
    final snippets = _records(payload, 'scriptSnippets');

    await _database.transaction(() async {
      await _database.delete(_database.deploymentResources).go();
      await _database.delete(_database.deploymentProjects).go();
      await _database.delete(_database.containerCacheEntries).go();
      await _database.delete(_database.composeProjectLinks).go();
      await _database.delete(_database.scriptSnippets).go();
      await _database.delete(_database.servers).go();
      await _database.delete(_database.savedCredentials).go();

      for (final record in credentials) {
        final credential = SavedCredential.fromJson(record);
        final clearText = record['credential'];
        if (clearText is! String) {
          throw const FormatException('Invalid saved credential.');
        }
        final encrypted = await _vault.encrypt(
          clearText,
          context: 'server-credential',
        );
        await _database
            .into(_database.savedCredentials)
            .insert(
              SavedCredentialsCompanion(
                id: Value(credential.id),
                name: Value(credential.name),
                credentialType: Value(credential.credentialType),
                encryptedCredential: Value(encrypted.bytes),
                credentialNonce: Value(encrypted.nonce),
                createdAt: Value(credential.createdAt),
                updatedAt: Value(credential.updatedAt),
              ),
            );
      }

      for (final record in servers) {
        final server = Server.fromJson(record);
        final credential = record['credential'];
        final encrypted = credential is String
            ? await _vault.encrypt(credential, context: 'server-credential')
            : null;
        await _database
            .into(_database.servers)
            .insert(
              ServersCompanion(
                id: Value(server.id),
                name: Value(server.name),
                host: Value(server.host),
                port: Value(server.port),
                username: Value(server.username),
                lastConnectedAt: Value(server.lastConnectedAt),
                syncId: Value(server.syncId),
                createdAt: Value(server.createdAt),
                updatedAt: Value(server.updatedAt),
                deletedAt: Value(server.deletedAt),
                credentialType: Value(server.credentialType),
                encryptedCredential: Value(encrypted?.bytes),
                credentialNonce: Value(encrypted?.nonce),
                credentialId: Value(server.credentialId),
                hostKeyAlgorithm: Value(server.hostKeyAlgorithm),
                hostKeyFingerprint: Value(server.hostKeyFingerprint),
                collectStats: Value(server.collectStats),
                collectSystemInfo: Value(server.collectSystemInfo),
              ),
            );
      }
      for (final record in composeLinks) {
        await _database
            .into(_database.composeProjectLinks)
            .insert(ComposeProjectLink.fromJson(record).toCompanion(false));
      }
      for (final record in cacheEntries) {
        await _database
            .into(_database.containerCacheEntries)
            .insert(ContainerCacheEntry.fromJson(record).toCompanion(false));
      }
      for (final record in projects) {
        await _database
            .into(_database.deploymentProjects)
            .insert(DeploymentProject.fromJson(record).toCompanion(false));
      }
      for (final record in resources) {
        await _database
            .into(_database.deploymentResources)
            .insert(DeploymentResource.fromJson(record).toCompanion(false));
      }
      for (final record in snippets) {
        await _database
            .into(_database.scriptSnippets)
            .insert(ScriptSnippet.fromJson(record).toCompanion(false));
      }
    });
  }

  List<Map<String, dynamic>> _records(
    Map<String, dynamic> payload,
    String key,
  ) {
    final records = payload[key];
    if (records is! List) throw FormatException('Invalid $key in backup.');
    return records.map((record) {
      if (record is! Map) throw FormatException('Invalid $key record.');
      return Map<String, dynamic>.from(record);
    }).toList();
  }
}
