import 'package:drift/drift.dart';

import 'package:maid_kit/data/local/app_database.dart';

import 'github_models.dart';
import 'github_token_store.dart';

/// Persistence for the GitHub integration. Connections, repo pins, and
/// project-workflow links are plain vault data (they sync with the vault);
/// access tokens are handled through [GitHubTokenStorage] and stay on-device.
class GitHubRepository {
  GitHubRepository(this._database, this._tokenStore);

  final AppDatabase _database;
  final GitHubTokenStorage _tokenStore;

  Stream<List<GitHubConnection>> watchConnections() =>
      _database.watchGitHubConnections();

  Stream<List<GitHubRepoPin>> watchRepoPins() =>
      _database.watchGitHubRepoPins();

  Stream<List<GitHubProjectWorkflowLink>> watchProjectWorkflowLinks() =>
      _database.watchGitHubProjectWorkflowLinks();

  Future<String?> tokenFor(String login) => _tokenStore.read(login);

  Future<void> saveToken(String login, String token) =>
      _tokenStore.write(login, token);

  Future<void> removeToken(String login) => _tokenStore.delete(login);

  Future<GitHubConnection> saveConnection(GitHubAccount account) async {
    final now = DateTime.now().toUtc();
    final existing =
        await (_database.select(_database.gitHubConnections)
              ..where((table) => table.accountLogin.equals(account.login)))
            .getSingleOrNull();
    if (existing != null) {
      await (_database.update(
        _database.gitHubConnections,
      )..where((table) => table.id.equals(existing.id))).write(
        GitHubConnectionsCompanion(
          accountName: Value(account.name),
          avatarUrl: Value(account.avatarUrl),
        ),
      );
      return (await _database.select(_database.gitHubConnections).get())
          .firstWhere((row) => row.id == existing.id);
    }
    final id = await _database
        .into(_database.gitHubConnections)
        .insert(
          GitHubConnectionsCompanion(
            accountLogin: Value(account.login),
            accountName: Value(account.name),
            avatarUrl: Value(account.avatarUrl),
            createdAt: Value(now),
          ),
        );
    return (await _database.select(_database.gitHubConnections).get())
        .firstWhere((row) => row.id == id);
  }

  /// Removes a connection and its pins. The device token must be removed
  /// separately with [removeToken]; the database never holds it.
  Future<void> removeConnection(GitHubConnection connection) =>
      _database.transaction(() async {
        await (_database.delete(
          _database.gitHubRepoPins,
        )..where((table) => table.connectionId.equals(connection.id))).go();
        await (_database.delete(
          _database.gitHubConnections,
        )..where((table) => table.id.equals(connection.id))).go();
      });

  Future<void> pinRepo(int connectionId, GitHubRepoRef repo) async {
    final existing =
        await (_database.select(_database.gitHubRepoPins)..where(
              (table) =>
                  table.connectionId.equals(connectionId) &
                  table.owner.equals(repo.owner) &
                  table.name.equals(repo.name),
            ))
            .getSingleOrNull();
    if (existing != null) return;
    await _database
        .into(_database.gitHubRepoPins)
        .insert(
          GitHubRepoPinsCompanion.insert(
            connectionId: connectionId,
            owner: repo.owner,
            name: repo.name,
            pinnedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> unpinRepo(GitHubRepoPin pin) => (_database.delete(
    _database.gitHubRepoPins,
  )..where((table) => table.id.equals(pin.id))).go();

  Future<List<GitHubProjectWorkflowLink>> linksForProject(int projectId) =>
      (_database.select(
        _database.gitHubProjectWorkflowLinks,
      )..where((table) => table.projectId.equals(projectId))).get();

  /// Links a project to a workflow. A project holds at most one link, so a
  /// previous link is replaced.
  Future<void> linkProjectWorkflow({
    required int projectId,
    required String owner,
    required String name,
    required String workflowName,
  }) => _database.transaction(() async {
    await (_database.delete(
      _database.gitHubProjectWorkflowLinks,
    )..where((table) => table.projectId.equals(projectId))).go();
    await _database
        .into(_database.gitHubProjectWorkflowLinks)
        .insert(
          GitHubProjectWorkflowLinksCompanion.insert(
            projectId: projectId,
            owner: owner,
            name: name,
            workflowName: workflowName,
            linkedAt: DateTime.now().toUtc(),
          ),
        );
  });

  Future<void> unlinkProjectWorkflow(GitHubProjectWorkflowLink link) =>
      (_database.delete(
        _database.gitHubProjectWorkflowLinks,
      )..where((table) => table.id.equals(link.id))).go();
}
