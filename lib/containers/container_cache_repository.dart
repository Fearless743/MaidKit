import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/local/app_database.dart';
import '../servers/server_providers.dart';
import 'container_models.dart';

final containerCacheRepositoryProvider = Provider<ContainerCacheRepository>(
  (ref) => ContainerCacheRepository(ref.watch(databaseProvider)),
);

final containerCacheEntriesProvider = StreamProvider<List<ContainerCacheEntry>>(
  (ref) => ref.watch(containerCacheRepositoryProvider).watchAll(),
);

class ContainerCacheRepository {
  ContainerCacheRepository(this._database);

  final AppDatabase _database;

  Stream<List<ContainerCacheEntry>> watchAll() =>
      _database.watchContainerCacheEntries();

  Future<void> replaceForServer(
    int serverId,
    Iterable<ContainerEnvironment> environments,
  ) => _database.transaction(() async {
    for (final environment in environments.where((item) => item.isAvailable)) {
      await (_database.delete(_database.containerCacheEntries)..where(
            (table) =>
                table.serverId.equals(serverId) &
                table.runtime.equals(environment.runtime.name) &
                table.scope.equals(environment.scope.name),
          ))
          .go();
      final now = DateTime.now().toUtc();
      for (final container in environment.containers) {
        await _database
            .into(_database.containerCacheEntries)
            .insert(
              ContainerCacheEntriesCompanion.insert(
                serverId: serverId,
                runtime: environment.runtime.name,
                scope: environment.scope.name,
                containerId: container.id,
                name: container.name,
                image: container.image,
                state: container.state,
                status: container.status,
                composeProject: Value(container.composeProject),
                cachedAt: now,
              ),
            );
      }
    }
  });

  static Map<int, List<ContainerEnvironment>> groupByServer(
    Iterable<ContainerCacheEntry> entries,
  ) {
    final groups = <(int, String, String), List<ContainerCacheEntry>>{};
    for (final entry in entries) {
      groups
          .putIfAbsent((entry.serverId, entry.runtime, entry.scope), () => [])
          .add(entry);
    }
    final byServer = <int, List<ContainerEnvironment>>{};
    for (final item in groups.entries) {
      final (serverId, runtimeName, scopeName) = item.key;
      final runtime = ContainerRuntime.values.byName(runtimeName);
      final scope = ContainerScope.values.byName(scopeName);
      byServer
          .putIfAbsent(serverId, () => [])
          .add(
            ContainerEnvironment(
              runtime: runtime,
              scope: scope,
              containers: [
                for (final entry in item.value)
                  ServerContainer(
                    id: entry.containerId,
                    name: entry.name,
                    image: entry.image,
                    state: entry.state,
                    status: entry.status,
                    composeProject: entry.composeProject,
                  ),
              ],
            ),
          );
    }
    return byServer;
  }
}
