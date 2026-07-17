import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/local/app_database.dart';
import 'server_repository.dart';
import 'ssh_connection_manager.dart';
import 'server_models.dart';
import 'vault_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(
    ref.watch(databaseProvider),
    ref.watch(vaultServiceProvider),
  );
});

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService(ref.watch(databaseProvider));
});

final vaultExistsProvider = FutureProvider<bool>((ref) {
  return ref.watch(vaultServiceProvider).hasVault();
});

final connectionManagerProvider = Provider<SshConnectionManager>((ref) {
  final manager = SshConnectionManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final sessionsProvider = StreamProvider<List<SshSessionInfo>>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return _watchSessions(manager);
});

Stream<List<SshSessionInfo>> _watchSessions(
  SshConnectionManager manager,
) async* {
  yield manager.current;
  yield* manager.sessions;
}

final serversProvider = StreamProvider<List<Server>>((ref) {
  return ref.watch(serverRepositoryProvider).watchAll();
});
