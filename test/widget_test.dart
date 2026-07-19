import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maid_kit/app.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/maidkit_window_scaffold.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('shows vault setup on first run', (WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          overrides: [
            desktopWindowProvider.overrideWith((ref) => false),
            databaseProvider.overrideWith((ref) => AppDatabase()),
            serversProvider.overrideWith((ref) => Stream.value(<Server>[])),
            vaultExistsProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: const MaidKitApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create your vault'), findsOneWidget);
  });
}
