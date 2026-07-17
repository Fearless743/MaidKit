import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maid_kit/app.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/maidkit_window_scaffold.dart';

void main() {
  testWidgets('shows the server workspace', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          desktopWindowProvider.overrideWith((ref) => false),
          serversProvider.overrideWith((ref) => Stream.value(<Server>[])),
        ],
        child: const MaidKitApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Servers'), findsWidgets);
  });
}
