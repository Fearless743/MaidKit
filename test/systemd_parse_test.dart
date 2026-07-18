import 'package:flutter_test/flutter_test.dart';
import 'package:maid_kit/servers/systemd_models.dart';

void main() {
  test('parses list-units and merges unit-file enablement', () {
    const units = '''
nginx.service loaded active running A high performance web server
sshd.service  loaded active running OpenSSH server daemon
cron.service  loaded inactive dead Regular background program processing
broken.service loaded failed failed Example failed unit
''';
    const files = '''
nginx.service enabled enabled
sshd.service  enabled enabled
cron.service  disabled disabled
broken.service enabled enabled
ghost.service disabled disabled
''';
    final merged = mergeSystemdListings(
      listUnitsOutput: units,
      listUnitFilesOutput: files,
    );
    expect(
      merged.map((u) => u.name),
      containsAll([
        'broken.service',
        'nginx.service',
        'sshd.service',
        'cron.service',
        'ghost.service',
      ]),
    );
    // Failed units sort first.
    expect(merged.first.name, 'broken.service');
    expect(merged.first.isFailed, isTrue);

    final nginx = merged.firstWhere((u) => u.name == 'nginx.service');
    expect(nginx.isActive, isTrue);
    expect(nginx.isEnabled, isTrue);
    expect(nginx.description, contains('web server'));

    final ghost = merged.firstWhere((u) => u.name == 'ghost.service');
    expect(ghost.isActive, isFalse);
    expect(ghost.isDisabled, isTrue);
  });

  test('parseSystemdProbeOutput handles missing systemctl', () {
    final snapshot = parseSystemdProbeOutput('--NOSYSTEMD--\n');
    expect(snapshot.available, isFalse);
    expect(snapshot.error, isNotNull);
  });

  test('parseSystemdProbeOutput reads sectioned probe output', () {
    const stdout = '''
--UNITS--
foo.service loaded active running Foo service
--FILES--
foo.service enabled enabled
''';
    final snapshot = parseSystemdProbeOutput(stdout);
    expect(snapshot.available, isTrue);
    expect(snapshot.units, hasLength(1));
    expect(snapshot.units.single.name, 'foo.service');
    expect(snapshot.units.single.isEnabled, isTrue);
  });

  test('validates unit names and critical units', () {
    expect(isValidSystemdUnitName('nginx.service'), isTrue);
    expect(isValidSystemdUnitName('user@1000.service'), isTrue);
    expect(isValidSystemdUnitName('nginx; rm -rf /'), isFalse);
    expect(isValidSystemdUnitName('nginx'), isFalse);
    expect(normalizeSystemdUnitName('nginx'), 'nginx.service');
    expect(isCriticalSystemdUnit('sshd.service'), isTrue);
    expect(isCriticalSystemdUnit('nginx.service'), isFalse);
  });

  test('strips status glyphs from list-units lines', () {
    const units = '● sshd.service loaded active running OpenSSH daemon\n';
    final parsed = parseSystemdListUnits(units);
    expect(parsed.keys, ['sshd.service']);
    expect(parsed['sshd.service']!.isActive, isTrue);
  });
}
