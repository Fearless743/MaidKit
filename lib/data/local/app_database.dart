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
}

@DriftDatabase(tables: [Servers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'maid_kit'));

  @override
  int get schemaVersion => 1;

  Stream<List<Server>> watchServers() => select(servers).watch();
}
