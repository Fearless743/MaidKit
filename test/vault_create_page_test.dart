import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maid_kit/servers/cloud_sync_service.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/servers/vault_create_page.dart';

class _FailingCloudSyncService extends CloudSyncService {
  _FailingCloudSyncService() : super(vaultId: 'test');

  @override
  Future<WebDavConnection?> connection() async => const WebDavConnection(
    url: 'https://dav.example.com',
    username: 'user',
    password: 'pass',
  );

  @override
  Future<List<CloudVaultBlob>> listVaultBlobs() async {
    throw const CloudSyncException('WebDAV request failed.');
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('shows the WebDAV error on the cloud choices view', (
    tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          overrides: [
            cloudSyncServiceProvider.overrideWithValue(
              _FailingCloudSyncService(),
            ),
          ],
          child: const MaterialApp(home: VaultCreatePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('vaultCreateFromCloudAction'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('WebDAV request failed.'), findsOneWidget);
    expect(find.text('commonCancel'.tr()), findsOneWidget);
  });
}
