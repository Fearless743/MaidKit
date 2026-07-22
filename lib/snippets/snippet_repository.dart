import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_providers.dart';

final snippetRepositoryProvider = Provider<SnippetRepository>((ref) {
  return SnippetRepository(ref.watch(databaseProvider));
});

final scriptSnippetsProvider = StreamProvider<List<ScriptSnippet>>((ref) {
  return ref.watch(snippetRepositoryProvider).watchAll();
});

class SnippetRepository {
  SnippetRepository(this._database);

  final AppDatabase _database;

  Stream<List<ScriptSnippet>> watchAll() => _database.watchScriptSnippets();

  Future<int> save({int? id, required String name, required String script}) {
    final now = DateTime.now().toUtc();
    final values = ScriptSnippetsCompanion(
      name: Value(name.trim()),
      script: Value(script),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    if (id == null) {
      return _database.into(_database.scriptSnippets).insert(values);
    }
    return (_database.update(
      _database.scriptSnippets,
    )..where((table) => table.id.equals(id))).write(values).then((_) => id);
  }

  Future<void> delete(int id) => (_database.delete(
    _database.scriptSnippets,
  )..where((table) => table.id.equals(id))).go();
}
