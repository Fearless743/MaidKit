import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/theme.dart';

void main() {
  testWidgets('opens Settings from the desktop navigation rail', (
    WidgetTester tester,
  ) async {
    final router = AppRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serversProvider.overrideWith((ref) => Stream.value(<Server>[])),
          biometricUnlockEnabledProvider.overrideWith(
            (ref) => Future.value(false),
          ),
        ],
        child: MaterialApp.router(
          theme: createMaidKitTheme(Brightness.light),
          routerConfig: router.config(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Terminal renderer'), findsOneWidget);
  });
}
