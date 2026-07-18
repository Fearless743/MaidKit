import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'container_models.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});

final composeProjectLinksProvider = StreamProvider<List<ComposeProjectLink>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

class ProjectRepository {
  ProjectRepository(this._database);

  final AppDatabase _database;

  Stream<List<ComposeProjectLink>> watchAll() =>
      _database.watchComposeProjectLinks();

  Future<void> saveLink({
    int? id,
    required int serverId,
    required String name,
    required String directory,
    required ContainerRuntime runtime,
    required ContainerScope scope,
  }) async {
    final existing = id == null
        ? await (_database.select(_database.composeProjectLinks)..where(
                (table) =>
                    table.serverId.equals(serverId) &
                    table.directory.equals(directory) &
                    table.scope.equals(scope.name),
              ))
              .getSingleOrNull()
        : null;
    final values = ComposeProjectLinksCompanion(
      serverId: Value(serverId),
      name: Value(name),
      directory: Value(directory),
      runtime: Value(runtime.name),
      scope: Value(scope.name),
      linkedAt: Value(DateTime.now().toUtc()),
    );
    if (id == null && existing == null) {
      await _database.into(_database.composeProjectLinks).insert(values);
    } else {
      await (_database.update(
        _database.composeProjectLinks,
      )..where((table) => table.id.equals(id ?? existing!.id))).write(values);
    }
  }

  Future<void> deleteLink(int id) => (_database.delete(
    _database.composeProjectLinks,
  )..where((table) => table.id.equals(id))).go();
}
