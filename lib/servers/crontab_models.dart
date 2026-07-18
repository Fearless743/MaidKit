/// A single line from a user or system crontab.
class CronEntry {
  const CronEntry({
    required this.raw,
    required this.kind,
    this.minute,
    this.hour,
    this.dayOfMonth,
    this.month,
    this.dayOfWeek,
    this.command,
    this.envName,
    this.envValue,
  });

  final String raw;
  final CronEntryKind kind;
  final String? minute;
  final String? hour;
  final String? dayOfMonth;
  final String? month;
  final String? dayOfWeek;
  final String? command;
  final String? envName;
  final String? envValue;

  bool get isJob => kind == CronEntryKind.job;
  bool get isEnv => kind == CronEntryKind.env;
  bool get isComment => kind == CronEntryKind.comment;
  bool get isBlank => kind == CronEntryKind.blank;

  String get scheduleLabel {
    if (!isJob) return '';
    return [
      minute,
      hour,
      dayOfMonth,
      month,
      dayOfWeek,
    ].whereType<String>().join(' ');
  }

  /// Human-friendly schedule summary for list tiles.
  String get scheduleSummary {
    if (!isJob) return '';
    final m = minute ?? '*';
    final h = hour ?? '*';
    final dom = dayOfMonth ?? '*';
    final mon = month ?? '*';
    final dow = dayOfWeek ?? '*';
    if (m == '*' && h == '*' && dom == '*' && mon == '*' && dow == '*') {
      return 'Every minute';
    }
    if (m.startsWith('*/') &&
        h == '*' &&
        dom == '*' &&
        mon == '*' &&
        dow == '*') {
      return 'Every ${m.substring(2)} minutes';
    }
    if (m != '*' &&
        !m.contains(',') &&
        !m.contains('-') &&
        !m.contains('/') &&
        h != '*' &&
        !h.contains(',') &&
        !h.contains('-') &&
        !h.contains('/') &&
        dom == '*' &&
        mon == '*' &&
        dow == '*') {
      return 'Daily at ${h.padLeft(2, '0')}:${m.padLeft(2, '0')}';
    }
    return scheduleLabel;
  }

  CronEntry copyWith({
    String? raw,
    CronEntryKind? kind,
    String? minute,
    String? hour,
    String? dayOfMonth,
    String? month,
    String? dayOfWeek,
    String? command,
  }) => CronEntry(
    raw: raw ?? this.raw,
    kind: kind ?? this.kind,
    minute: minute ?? this.minute,
    hour: hour ?? this.hour,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    month: month ?? this.month,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    command: command ?? this.command,
    envName: envName,
    envValue: envValue,
  );

  /// Builds a crontab job line from schedule fields and command.
  static String formatJob({
    required String minute,
    required String hour,
    required String dayOfMonth,
    required String month,
    required String dayOfWeek,
    required String command,
  }) {
    return '${minute.trim()} ${hour.trim()} ${dayOfMonth.trim()} '
        '${month.trim()} ${dayOfWeek.trim()} ${command.trim()}';
  }
}

enum CronEntryKind { job, env, comment, blank, unknown }

class CrontabDocument {
  const CrontabDocument({
    required this.entries,
    this.exists = true,
    this.error,
  });

  final List<CronEntry> entries;
  final bool exists;
  final String? error;

  List<CronEntry> get jobs =>
      entries.where((entry) => entry.isJob).toList(growable: false);

  /// Reconstructs crontab text for `crontab -`.
  String toCrontabText() {
    if (entries.isEmpty) return '';
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln(entry.raw);
    }
    return buffer.toString();
  }

  CrontabDocument replacingJob(int jobIndex, CronEntry newJob) {
    var seen = 0;
    final next = <CronEntry>[];
    for (final entry in entries) {
      if (entry.isJob) {
        if (seen == jobIndex) {
          next.add(newJob);
        } else {
          next.add(entry);
        }
        seen++;
      } else {
        next.add(entry);
      }
    }
    return CrontabDocument(entries: next, exists: true);
  }

  CrontabDocument removingJob(int jobIndex) {
    var seen = 0;
    final next = <CronEntry>[];
    for (final entry in entries) {
      if (entry.isJob) {
        if (seen != jobIndex) next.add(entry);
        seen++;
      } else {
        next.add(entry);
      }
    }
    return CrontabDocument(entries: next, exists: true);
  }

  CrontabDocument addingJob(CronEntry job) =>
      CrontabDocument(entries: [...entries, job], exists: true);
}

/// Parses standard user crontab text into structured entries.
CrontabDocument parseCrontab(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  // crontab -l often ends with a trailing newline; keep blank lines only if mid-file.
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  final entries = <CronEntry>[];
  for (final line in lines) {
    entries.add(_parseCronLine(line));
  }
  return CrontabDocument(entries: entries, exists: true);
}

CronEntry _parseCronLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return CronEntry(raw: line, kind: CronEntryKind.blank);
  }
  if (trimmed.startsWith('#')) {
    return CronEntry(raw: line, kind: CronEntryKind.comment);
  }
  // Environment assignment: NAME=value (no spaces around = required by cron).
  final envMatch = RegExp(
    r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$',
  ).firstMatch(trimmed);
  if (envMatch != null && !trimmed.startsWith('@')) {
    // A job line always has at least 6 fields; env rarely collides.
    final maybeFields = trimmed.split(RegExp(r'\s+'));
    if (maybeFields.length < 6) {
      return CronEntry(
        raw: line,
        kind: CronEntryKind.env,
        envName: envMatch.group(1),
        envValue: envMatch.group(2),
      );
    }
  }
  // @reboot, @daily, etc.
  if (trimmed.startsWith('@')) {
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return CronEntry(
        raw: line,
        kind: CronEntryKind.job,
        minute: parts[0],
        hour: '',
        dayOfMonth: '',
        month: '',
        dayOfWeek: '',
        command: parts.sublist(1).join(' '),
      );
    }
  }
  final fields = trimmed.split(RegExp(r'\s+'));
  if (fields.length >= 6) {
    return CronEntry(
      raw: line,
      kind: CronEntryKind.job,
      minute: fields[0],
      hour: fields[1],
      dayOfMonth: fields[2],
      month: fields[3],
      dayOfWeek: fields[4],
      command: fields.sublist(5).join(' '),
    );
  }
  return CronEntry(raw: line, kind: CronEntryKind.unknown);
}
