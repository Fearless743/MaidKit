import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'server_models.dart';
import 'vault_service.dart';

class ServerRepository {
  ServerRepository(this._database, this._vault);

  final AppDatabase _database;
  final VaultService _vault;
  final Uuid _uuid = const Uuid();

  Stream<List<Server>> watchAll() => _database.watchServers();

  Future<List<Server>> all() => (_database.select(
    _database.servers,
  )..where((table) => table.deletedAt.isNull())).get();

  Future<Server> create(ServerDraft draft) async {
    final encrypted = await _vault.encrypt(
      draft.credential.encode(),
      context: 'server-credential',
    );
    final now = DateTime.now().toUtc();
    final id = await _database
        .into(_database.servers)
        .insert(
          ServersCompanion.insert(
            name: draft.name.trim(),
            host: draft.host.trim(),
            port: Value(draft.port),
            username: draft.username.trim(),
            syncId: Value(_uuid.v4()),
            createdAt: Value(now),
            updatedAt: Value(now),
            credentialType: Value(draft.credential.type.name),
            encryptedCredential: Value(encrypted.bytes),
            credentialNonce: Value(encrypted.nonce),
            collectStats: Value(draft.collectStats),
            collectSystemInfo: Value(draft.collectSystemInfo),
          ),
        );
    return (_database.select(
      _database.servers,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> update(Server server, ServerDraft draft) async {
    final encrypted = await _vault.encrypt(
      draft.credential.encode(),
      context: 'server-credential',
    );
    await (_database.update(
      _database.servers,
    )..where((table) => table.id.equals(server.id))).write(
      ServersCompanion(
        name: Value(draft.name.trim()),
        host: Value(draft.host.trim()),
        port: Value(draft.port),
        username: Value(draft.username.trim()),
        credentialType: Value(draft.credential.type.name),
        encryptedCredential: Value(encrypted.bytes),
        credentialNonce: Value(encrypted.nonce),
        collectStats: Value(draft.collectStats),
        collectSystemInfo: Value(draft.collectSystemInfo),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<ServerCredential> credentialFor(Server server) async {
    final value = await _vault.decrypt(
      EncryptedValue(
        bytes: server.encryptedCredential!,
        nonce: server.credentialNonce!,
      ),
      context: 'server-credential',
    );
    return ServerCredential.decode(value);
  }

  Future<void> markConnected(int id) =>
      (_database.update(
        _database.servers,
      )..where((t) => t.id.equals(id))).write(
        ServersCompanion(
          lastConnectedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> rememberHostKey(int id, HostKeyPrompt hostKey) =>
      (_database.update(
        _database.servers,
      )..where((table) => table.id.equals(id))).write(
        ServersCompanion(
          hostKeyAlgorithm: Value(hostKey.algorithm),
          hostKeyFingerprint: Value(hostKey.fingerprint),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> delete(Server server) =>
      (_database.update(
        _database.servers,
      )..where((t) => t.id.equals(server.id))).write(
        ServersCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<String> exportArchive(String vaultPassword) async {
    final servers = await _database.select(_database.servers).get();
    final records = servers
        .map(
          (server) => {
            'syncId': server.syncId,
            'name': server.name,
            'host': server.host,
            'port': server.port,
            'username': server.username,
            'lastConnectedAt': server.lastConnectedAt?.toIso8601String(),
            'createdAt': server.createdAt?.toIso8601String(),
            'updatedAt': server.updatedAt?.toIso8601String(),
            'deletedAt': server.deletedAt?.toIso8601String(),
            'credentialType': server.credentialType,
            'encryptedCredential': server.encryptedCredential,
            'credentialNonce': server.credentialNonce,
            'collectStats': server.collectStats,
            'collectSystemInfo': server.collectSystemInfo,
          },
        )
        .toList();
    return _vault.encryptPortable(
      jsonEncode({'version': 1, 'servers': records}),
      vaultPassword,
    );
  }

  Future<List<PortableServerRecord>> previewImport(
    String archive,
    String vaultPassword,
  ) async {
    final plain = await _vault.decryptPortable(archive, vaultPassword);
    final payload = jsonDecode(plain) as Map<String, dynamic>;
    final local = await _database.select(_database.servers).get();
    return (payload['servers'] as List<dynamic>).map((item) {
      final value = item as Map<String, dynamic>;
      final existing = local
          .where((s) => s.syncId == value['syncId'])
          .firstOrNull;
      return PortableServerRecord(value, existing);
    }).toList();
  }

  Future<void> applyImport(Iterable<PortableServerRecord> records) async {
    await _database.batch((batch) {
      for (final record in records.where((r) => r.useImported)) {
        final value = record.value;
        final companion = ServersCompanion(
          name: Value(value['name'] as String),
          host: Value(value['host'] as String),
          port: Value(value['port'] as int),
          username: Value(value['username'] as String),
          syncId: Value(value['syncId'] as String),
          credentialType: Value(value['credentialType'] as String?),
          encryptedCredential: Value(value['encryptedCredential'] as String?),
          credentialNonce: Value(value['credentialNonce'] as String?),
          collectStats: Value(value['collectStats'] as bool? ?? true),
          collectSystemInfo: Value(value['collectSystemInfo'] as bool? ?? true),
          createdAt: Value(DateTime.parse(value['createdAt'] as String)),
          updatedAt: Value(DateTime.parse(value['updatedAt'] as String)),
          deletedAt: Value(
            value['deletedAt'] == null
                ? null
                : DateTime.parse(value['deletedAt'] as String),
          ),
        );
        if (record.local == null) {
          batch.insert(_database.servers, companion);
        } else {
          batch.update(
            _database.servers,
            companion,
            where: (t) => t.id.equals(record.local!.id),
          );
        }
      }
    });
  }
}

class PortableServerRecord {
  PortableServerRecord(this.value, this.local);
  final Map<String, dynamic> value;
  final Server? local;
  bool useImported = false;
  bool get hasConflict => local != null;
}
