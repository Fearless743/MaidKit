import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Servers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get host => text()();
  IntColumn get port => integer().withDefault(const Constant(22))();
  TextColumn get username => text()();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get credentialType => text().nullable()();
  TextColumn get encryptedCredential => text().nullable()();
  TextColumn get credentialNonce => text().nullable()();
  TextColumn get hostKeyAlgorithm => text().nullable()();
  TextColumn get hostKeyFingerprint => text().nullable()();
  BoolColumn get collectStats => boolean().withDefault(const Constant(true))();
  BoolColumn get collectSystemInfo =>
      boolean().withDefault(const Constant(true))();
}

class VaultMetadata extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get formatVersion => integer()();
  TextColumn get salt => text()();
  TextColumn get wrappedDataKey => text()();
  TextColumn get wrappedDataKeyNonce => text()();
  TextColumn get verifier => text()();
  TextColumn get verifierNonce => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Locally remembered Compose folders. A link is intentionally metadata only:
/// its compose file and credentials remain on the managed server.
class ComposeProjectLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer()();
  TextColumn get name => text()();
  TextColumn get directory => text()();
  TextColumn get runtime => text()();
  TextColumn get scope => text()();
  DateTimeColumn get linkedAt => dateTime()();
}

/// Last successfully read container state. It is a UI cache, not an authority
/// for remote state, and contains no credentials or compose-file contents.
class ContainerCacheEntries extends Table {
  IntColumn get serverId => integer()();
  TextColumn get runtime => text()();
  TextColumn get scope => text()();
  TextColumn get containerId => text()();
  TextColumn get name => text()();
  TextColumn get image => text()();
  TextColumn get state => text()();
  TextColumn get status => text()();
  TextColumn get composeProject => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, runtime, scope, containerId};
}

@DriftDatabase(
  tables: [Servers, VaultMetadata, ComposeProjectLinks, ContainerCacheEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'maid_kit'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX servers_sync_id_unique ON servers (sync_id)',
      );
      await customStatement(
        'CREATE UNIQUE INDEX compose_project_links_location_unique '
        'ON compose_project_links (server_id, directory, scope)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(servers, servers.syncId);
        await m.addColumn(servers, servers.createdAt);
        await m.addColumn(servers, servers.updatedAt);
        await m.addColumn(servers, servers.deletedAt);
        await m.addColumn(servers, servers.credentialType);
        await m.addColumn(servers, servers.encryptedCredential);
        await m.addColumn(servers, servers.credentialNonce);
        await m.createTable(vaultMetadata);
        await customStatement(
          'CREATE UNIQUE INDEX servers_sync_id_unique ON servers (sync_id)',
        );
      }
      if (from < 3) {
        await m.addColumn(servers, servers.hostKeyAlgorithm);
        await m.addColumn(servers, servers.hostKeyFingerprint);
      }
      if (from < 4) {
        await m.addColumn(servers, servers.collectStats);
        await m.addColumn(servers, servers.collectSystemInfo);
      }
      if (from < 5) {
        await m.createTable(composeProjectLinks);
        await customStatement(
          'CREATE UNIQUE INDEX compose_project_links_location_unique '
          'ON compose_project_links (server_id, directory, scope)',
        );
      }
      if (from < 6) {
        await m.createTable(containerCacheEntries);
      }
    },
  );

  Stream<List<Server>> watchServers() =>
      (select(servers)..where((table) => table.deletedAt.isNull())).watch();

  Stream<List<ComposeProjectLink>> watchComposeProjectLinks() =>
      select(composeProjectLinks).watch();

  Stream<List<ContainerCacheEntry>> watchContainerCacheEntries() =>
      select(containerCacheEntries).watch();
}
