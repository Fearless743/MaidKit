import 'package:flutter_test/flutter_test.dart';
import 'package:maid_kit/servers/caddy_web_server_adapter.dart';
import 'package:maid_kit/servers/nginx_web_server_adapter.dart';
import 'package:maid_kit/servers/web_server_adapter.dart';
import 'package:maid_kit/servers/web_server_adapters.dart';
import 'package:maid_kit/servers/web_server_models.dart';

void main() {
  test('built-in adapters are registered as nginx and caddy', () {
    expect(builtInWebServerAdapters.map((a) => a.id), ['nginx', 'caddy']);
    expect(webServerAdapterById('nginx'), isA<NginxWebServerAdapter>());
    expect(webServerAdapterById('caddy'), isA<CaddyWebServerAdapter>());
    expect(webServerAdapterById('apache'), isNull);
  });

  test('parses nginx site listing', () {
    const listing = '''
FILE\tdefault\t/etc/nginx/sites-enabled/default\tyes\texample.com www.example.com\t80 443 ssl
FILE\tapi\t/etc/nginx/conf.d/api.conf\tyes\tapi.example.com\t8080
FILE\tskip\trelative/path\tyes\tskip.me\t80
''';
    final sites = parseNginxSiteListing(listing);
    expect(sites, hasLength(2));
    expect(sites.first.name, 'api');
    expect(sites.first.serverNames, ['api.example.com']);
    expect(sites.first.listen, ['8080']);
    final def = sites.firstWhere((s) => s.name == 'default');
    expect(def.path, '/etc/nginx/sites-enabled/default');
    expect(def.serverNames, ['example.com', 'www.example.com']);
  });

  test('parses Caddyfile site addresses', () {
    const caddyfile = '''
{
  email admin@example.com
}

example.com, www.example.com {
  reverse_proxy localhost:8080
}

:80 {
  redir https://{host}{uri}
}

(logging) {
  log {
    output file /var/log/caddy/access.log
  }
}

import /etc/caddy/conf.d/*

api.internal {
  reverse_proxy 127.0.0.1:3000
}
''';
    final sites = parseCaddyfileSiteAddresses(caddyfile);
    expect(
      sites,
      containsAll(['example.com', 'www.example.com', ':80', 'api.internal']),
    );
    expect(sites, isNot(contains('import')));
    expect(sites, isNot(contains('(logging)')));
  });

  test('isSafeConfigPath rejects shell metacharacters', () {
    expect(isSafeConfigPath('/etc/nginx/nginx.conf'), isTrue);
    expect(isSafeConfigPath('/etc/caddy/Caddyfile'), isTrue);
    expect(isSafeConfigPath('nginx.conf'), isFalse);
    expect(isSafeConfigPath('/etc/nginx/../passwd'), isFalse);
    expect(isSafeConfigPath('/tmp/foo; rm -rf /'), isFalse);
  });

  test('WebServerAction systemctl verbs match enum names', () {
    expect(WebServerAction.reload.systemctlVerb, 'reload');
    expect(WebServerAction.start.isDestructive, isFalse);
    expect(WebServerAction.stop.isDestructive, isTrue);
  });

  test('summarizeCommandOutput prefers error and success lines', () {
    expect(
      summarizeCommandOutput(
        'nginx: the configuration file /etc/nginx/nginx.conf syntax is ok\n'
        'nginx: configuration file /etc/nginx/nginx.conf test is successful\n',
      ),
      contains('successful'),
    );
    expect(
      summarizeCommandOutput(
        'Validating configuration...\n'
        'Error: adapting config: invalid host\n',
      ),
      contains('Error'),
    );
  });

  test('fake remote drives nginx adapter install check', () async {
    final remote = _FakeRemote({
      'command -v nginx': const WebServerCommandResult(
        stdout: '/usr/sbin/nginx\n',
        stderr: '',
        exitCode: 0,
      ),
    });
    const adapter = NginxWebServerAdapter();
    expect(await adapter.isInstalled(remote), isTrue);

    final missing = _FakeRemote({
      'command -v nginx': const WebServerCommandResult(
        stdout: '',
        stderr: '',
        exitCode: 1,
      ),
    });
    expect(await adapter.isInstalled(missing), isFalse);
  });
}

class _FakeRemote implements WebServerRemote {
  _FakeRemote(this.responses);

  final Map<String, WebServerCommandResult> responses;

  @override
  Future<WebServerCommandResult> run(
    String command, {
    bool privileged = false,
    String? stdinPayload,
  }) async {
    final exact = responses[command];
    if (exact != null) return exact;
    for (final entry in responses.entries) {
      if (command.contains(entry.key) || entry.key.contains(command)) {
        return entry.value;
      }
    }
    return const WebServerCommandResult(
      stdout: '',
      stderr: 'not mocked',
      exitCode: 1,
    );
  }

  @override
  String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
}
