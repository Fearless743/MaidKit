import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maid_kit/agent/personality_service.dart';

void main() {
  test('lists agents directly beneath the Personality base URL', () async {
    late http.Request request;
    final service = PersonalityService(
      client: MockClient((received) async {
        request = received;
        return http.Response(
          '[{"id":"ops","name":"Operations","description":""}]',
          200,
        );
      }),
    );

    final agents = await service.listAgents(
      baseUrl: 'https://api.solian.app/personality/',
      accessToken: 'solar-token',
    );

    expect(request.url.toString(), 'https://api.solian.app/personality/agents');
    expect(request.headers['authorization'], 'Bearer solar-token');
    expect(agents.single.id, 'ops');
  });
}
