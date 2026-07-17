import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maid_kit/app.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/maidkit_window_scaffold.dart';

void main() {
  testWidgets('shows vault setup on first run', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          desktopWindowProvider.overrideWith((ref) => false),
          serversProvider.overrideWith((ref) => Stream.value(<Server>[])),
          vaultExistsProvider.overrideWith((ref) => Future.value(false)),
        ],
        child: const MaidKitApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Create your vault'), findsOneWidget);
  });
}
