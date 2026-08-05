import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/github/github_models.dart';
import 'package:maid_kit/github/github_page.dart';
import 'package:maid_kit/github/github_providers.dart';
import 'package:maid_kit/github/github_token_store.dart';

class _AwaitingUserNotifier extends GitHubSignInNotifier {
  @override
  GitHubSignInState build() => const GitHubSignInState(
    phase: GitHubSignInPhase.awaitingUser,
    userCode: 'ABCD-EFGH',
    verificationUri: 'https://github.com/login/device',
  );
}

/// Renders [GitHubPage] with every data source overridden, so the widget test
/// never touches the database (drift's isolate executor deadlocks inside
/// `testWidgets`' FakeAsync zone).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return Directory.systemTemp.path;
        });
  });

  GitHubRunsSnapshot snapshotWithFailures() => GitHubRunsSnapshot(
    repos: [
      PinnedRepoRuns(
        owner: 'octocat',
        name: 'hello',
        runs: [
          WorkflowRun(
            id: 1,
            name: 'CI',
            displayTitle: 'Build',
            headBranch: 'main',
            headSha: 'abc',
            status: WorkflowRunStatus.completed,
            conclusion: WorkflowRunConclusion.failure,
            runNumber: 3,
            actorLogin: 'octocat',
          ),
        ],
      ),
    ],
    fetchedAt: DateTime.now(),
    errors: const [],
  );

  testWidgets('device code card is selectable and has a copy button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          overrides: [
            githubTokenStoreProvider.overrideWithValue(
              InMemoryGitHubTokenStorage(),
            ),
            githubConnectionsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            githubSignInProvider.overrideWith(_AwaitingUserNotifier.new),
          ],
          child: const MaterialApp(
            locale: Locale('en', 'US'),
            home: GitHubPage(),
          ),
        ),
      ),
    );
    // The waiting spinner animates indefinitely, so bounded pumps instead of
    // pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    // The copy action must not throw on the mocked clipboard channel.
    await tester.tap(find.byTooltip('commonCopy'.tr()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('add repository button is visible with no pinned repos', (
    WidgetTester tester,
  ) async {
    final connection = GitHubConnection(
      id: 1,
      accountLogin: 'octocat',
      accountName: 'Octo Cat',
      avatarUrl: '',
      createdAt: DateTime.now(),
    );
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          overrides: [
            githubTokenStoreProvider.overrideWithValue(
              InMemoryGitHubTokenStorage(),
            ),
            githubConnectionsProvider.overrideWith(
              (ref) => Stream.value([connection]),
            ),
            githubTokenForConnectionProvider.overrideWith(
              (ref) async => (connection: connection, token: 'secret'),
            ),
            githubPinnedReposProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            githubRunsProvider.overrideWith(
              (ref) => Stream.value(
                GitHubRunsSnapshot(
                  repos: const [],
                  fetchedAt: DateTime.now(),
                  errors: const [],
                ),
              ),
            ),
            githubPullRequestsProvider.overrideWith((ref) async => const []),
            githubReleasesProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            locale: Locale('en', 'US'),
            home: GitHubPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('githubNoPinnedRepos'.tr()), findsWidgets);
    expect(find.text('githubAddRepo'.tr()), findsOneWidget);
  });

  testWidgets('renders the sign-in card when no account is connected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          overrides: [
            githubTokenStoreProvider.overrideWithValue(
              InMemoryGitHubTokenStorage(),
            ),
            githubConnectionsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en', 'US'),
            home: GitHubPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('githubSignInTitle'.tr()), findsOneWidget);
    expect(find.text('githubSignIn'.tr()), findsOneWidget);
    expect(find.text('githubTokenLocalHint'.tr()), findsOneWidget);
  });

  testWidgets('renders the runs feed and failure banner when signed in', (
    WidgetTester tester,
  ) async {
    final connection = GitHubConnection(
      id: 1,
      accountLogin: 'octocat',
      accountName: 'Octo Cat',
      avatarUrl: '',
      createdAt: DateTime.now(),
    );
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          overrides: [
            githubTokenStoreProvider.overrideWithValue(
              InMemoryGitHubTokenStorage(),
            ),
            githubConnectionsProvider.overrideWith(
              (ref) => Stream.value([connection]),
            ),
            githubTokenForConnectionProvider.overrideWith(
              (ref) async => (connection: connection, token: 'secret'),
            ),
            githubPinnedReposProvider.overrideWith(
              (ref) => Stream.value([
                GitHubRepoPin(
                  id: 1,
                  connectionId: 1,
                  owner: 'octocat',
                  name: 'hello',
                  pinnedAt: DateTime.now(),
                ),
              ]),
            ),
            githubRunsProvider.overrideWith(
              (ref) => Stream.value(snapshotWithFailures()),
            ),
            githubPullRequestsProvider.overrideWith((ref) async => const []),
            githubReleasesProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            locale: Locale('en', 'US'),
            home: GitHubPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('octocat'), findsOneWidget);
    expect(find.text('githubRuns'.tr()), findsOneWidget);
    expect(find.text('githubFailureBanner'.tr(args: ['1'])), findsOneWidget);
    expect(find.text('Build'), findsOneWidget);
    expect(find.text('githubConclusionFailure'.tr()), findsOneWidget);
    expect(find.text('githubAddRepo'.tr()), findsOneWidget);
  });
}
