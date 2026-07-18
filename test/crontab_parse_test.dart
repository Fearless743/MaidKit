import 'package:flutter_test/flutter_test.dart';
import 'package:maid_kit/servers/crontab_models.dart';

void main() {
  test('parses standard jobs, comments, and env vars', () {
    const text = '''
# nightly backup
SHELL=/bin/bash
0 2 * * * /usr/local/bin/backup.sh
*/15 * * * * /usr/bin/check
@reboot /usr/local/bin/start.sh
''';
    final document = parseCrontab(text);
    expect(document.jobs, hasLength(3));
    expect(document.entries.where((e) => e.isEnv), hasLength(1));
    expect(document.entries.where((e) => e.isComment), hasLength(1));
    expect(document.jobs.first.command, '/usr/local/bin/backup.sh');
    expect(document.jobs.first.scheduleSummary, 'Daily at 02:00');
    expect(document.jobs[1].scheduleSummary, 'Every 15 minutes');
    expect(document.jobs[2].minute, '@reboot');
  });

  test('round-trips crontab text for install', () {
    const text = '0 * * * * echo hi\nPATH=/usr/bin\n';
    final document = parseCrontab(text.trimRight());
    final rebuilt = document.toCrontabText();
    expect(rebuilt.contains('0 * * * * echo hi'), isTrue);
    expect(rebuilt.contains('PATH=/usr/bin'), isTrue);
  });

  test('add replace remove jobs keep non-job lines', () {
    final base = parseCrontab('# keep\n0 1 * * * a\n0 2 * * * b\n');
    final withNew = base.addingJob(
      CronEntry(
        raw: '0 3 * * * c',
        kind: CronEntryKind.job,
        minute: '0',
        hour: '3',
        dayOfMonth: '*',
        month: '*',
        dayOfWeek: '*',
        command: 'c',
      ),
    );
    expect(withNew.jobs, hasLength(3));
    final removed = withNew.removingJob(0);
    expect(removed.jobs.map((j) => j.command), ['b', 'c']);
    expect(removed.entries.first.isComment, isTrue);
  });
}
