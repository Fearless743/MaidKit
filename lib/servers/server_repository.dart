import '../data/local/app_database.dart';

class ServerRepository {
  const ServerRepository(this._database);

  final AppDatabase _database;

  Stream<List<Server>> watchAll() => _database.watchServers();
}
