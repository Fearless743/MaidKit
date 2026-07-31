import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maid_kit/agent/billing_service.dart';

void main() {
  test(
    'reads billing policy directly beneath the Personality base URL',
    () async {
      late http.Request request;
      final service = PersonalityBillingService(
        client: MockClient((received) async {
          request = received;
          return http.Response(
            '{"usage": {"hourly_usage": {"golds": {"used": "1.50000000", '
            '"max": "100"}, "points": {"used": "0.00000000", "max": "100"}}, '
            '"daily_usage": {"golds": {"used": "18.00000000", "max": "500"}, '
            '"points": {"used": "0.00000000", "max": "500"}}}, '
            '"blacklisted": false}',
            200,
          );
        }),
      );

      final policy = await service.getMyBilling(
        baseUrl: 'https://api.solian.app/personality/',
        accessToken: 'solar-token',
      );

      expect(
        request.url.toString(),
        'https://api.solian.app/personality/billing/me',
      );
      expect(request.headers['authorization'], 'Bearer solar-token');
      expect(policy.hourlyGolds?.used, 1.5);
      expect(policy.hourlyGolds?.max, 100);
      expect(policy.dailyGolds?.used, 18);
      expect(policy.dailyGolds?.max, 500);
      expect(policy.hourlyPoints?.max, 100);
      expect(policy.dailyPoints?.max, 500);
      expect(policy.blacklisted, isFalse);
    },
  );

  test('settles billing now', () async {
    late http.Request request;
    final service = PersonalityBillingService(
      client: MockClient((received) async {
        request = received;
        return http.Response('{}', 200);
      }),
    );

    await service.settle(
      baseUrl: 'https://api.solian.app/personality',
      accessToken: 'solar-token',
    );

    expect(request.method, 'POST');
    expect(
      request.url.toString(),
      'https://api.solian.app/personality/billing/me/settle',
    );
  });

  test('surfaces server errors as PersonalityBillingException', () async {
    final service = PersonalityBillingService(
      client: MockClient(
        (received) async =>
            http.Response('{"error": "account is blacklisted"}', 403),
      ),
    );

    expect(
      () => service.getMyBilling(
        baseUrl: 'https://api.solian.app/personality',
        accessToken: 'solar-token',
      ),
      throwsA(isA<PersonalityBillingException>()),
    );
  });
}
