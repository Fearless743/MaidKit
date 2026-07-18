/// Systemd unit lifecycle actions exposed in the Services tab.
enum SystemdUnitAction { start, stop, restart, enable, disable }

extension SystemdUnitActionX on SystemdUnitAction {
  String get label => switch (this) {
    SystemdUnitAction.start => 'Start',
    SystemdUnitAction.stop => 'Stop',
    SystemdUnitAction.restart => 'Restart',
    SystemdUnitAction.enable => 'Enable',
    SystemdUnitAction.disable => 'Disable',
  };

  String get pastLabel => switch (this) {
    SystemdUnitAction.start => 'Started',
    SystemdUnitAction.stop => 'Stopped',
    SystemdUnitAction.restart => 'Restarted',
    SystemdUnitAction.enable => 'Enabled',
    SystemdUnitAction.disable => 'Disabled',
  };

  String get systemctlVerb => name;

  bool get isDestructive =>
      this == SystemdUnitAction.stop || this == SystemdUnitAction.disable;
}

/// A host-level systemd service unit.
class SystemdUnit {
  const SystemdUnit({
    required this.name,
    required this.loadState,
    required this.activeState,
    required this.subState,
    required this.description,
    this.unitFileState = '',
  });

  /// Full unit name, e.g. `nginx.service`.
  final String name;
  final String loadState;
  final String activeState;
  final String subState;
  final String description;

  /// From `list-unit-files`: enabled, disabled, static, masked, …
  final String unitFileState;

  bool get isActive => activeState.toLowerCase() == 'active';
  bool get isFailed => activeState.toLowerCase() == 'failed';
  bool get isInactive =>
      activeState.toLowerCase() == 'inactive' ||
      activeState.toLowerCase() == 'failed' ||
      activeState.toLowerCase() == 'dead';

  bool get isEnabled {
    final state = unitFileState.toLowerCase();
    return state == 'enabled' || state == 'enabled-runtime';
  }

  bool get isDisabled {
    final state = unitFileState.toLowerCase();
    return state == 'disabled' || state == 'disabled-runtime';
  }

  bool get canEnable => isDisabled;

  bool get canDisable => isEnabled;

  /// Short label for chips: running, failed, inactive, …
  String get statusLabel {
    if (isFailed) return 'failed';
    if (isActive) {
      final sub = subState.trim();
      return sub.isEmpty ? 'active' : sub;
    }
    final active = activeState.trim();
    return active.isEmpty ? 'unknown' : active;
  }

  String get enablementLabel {
    final state = unitFileState.trim();
    return state.isEmpty ? '—' : state;
  }

  SystemdUnit copyWith({
    String? loadState,
    String? activeState,
    String? subState,
    String? description,
    String? unitFileState,
  }) {
    return SystemdUnit(
      name: name,
      loadState: loadState ?? this.loadState,
      activeState: activeState ?? this.activeState,
      subState: subState ?? this.subState,
      description: description ?? this.description,
      unitFileState: unitFileState ?? this.unitFileState,
    );
  }
}

/// Result of probing systemd on a host.
class SystemdUnitsSnapshot {
  const SystemdUnitsSnapshot({
    required this.available,
    this.units = const [],
    this.error,
  });

  final bool available;
  final List<SystemdUnit> units;
  final String? error;

  int get failedCount => units.where((u) => u.isFailed).length;
  int get activeCount => units.where((u) => u.isActive).length;
}

/// Safe systemd unit name (no shell metacharacters).
final RegExp systemdUnitNamePattern = RegExp(r'^[A-Za-z0-9:._@\\-]+\.service$');

bool isValidSystemdUnitName(String name) =>
    systemdUnitNamePattern.hasMatch(name.trim());

/// Units that stopping/disabling can strand remote access or networking.
bool isCriticalSystemdUnit(String name) {
  final base = name.trim().toLowerCase();
  const critical = {
    'sshd.service',
    'ssh.service',
    'networkmanager.service',
    'networking.service',
    'systemd-networkd.service',
    'systemd-resolved.service',
    'dbus.service',
    'dbus-broker.service',
    'firewalld.service',
    'ufw.service',
    'nftables.service',
  };
  if (critical.contains(base)) return true;
  // Template instances such as getty@tty1.service are less critical than ssh.
  if (base.startsWith('sshd@') || base.startsWith('ssh@')) return true;
  return false;
}

/// Normalizes a user-facing unit name to a `.service` unit when possible.
String normalizeSystemdUnitName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return name;
  if (name.contains('.')) return name;
  return '$name.service';
}

/// Parses `systemctl list-units --type=service --all --plain --no-legend`.
///
/// Columns: UNIT LOAD ACTIVE SUB DESCRIPTION
Map<String, SystemdUnit> parseSystemdListUnits(String output) {
  final result = <String, SystemdUnit>{};
  for (final rawLine in output.split('\n')) {
    var line = rawLine.trimRight();
    if (line.isEmpty) continue;
    // Leading ● / ○ glyphs on some versions.
    line = line.replaceFirst(RegExp(r'^[●○*]+\s*'), '').trimLeft();
    if (line.startsWith('UNIT ') || line.startsWith('LOAD ')) continue;
    final match = RegExp(
      r'^(\S+\.service)\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*)$',
    ).firstMatch(line);
    if (match == null) continue;
    final name = match.group(1)!;
    if (!isValidSystemdUnitName(name)) continue;
    result[name] = SystemdUnit(
      name: name,
      loadState: match.group(2)!,
      activeState: match.group(3)!,
      subState: match.group(4)!,
      description: (match.group(5) ?? '').trim(),
    );
  }
  return result;
}

/// Parses `systemctl list-unit-files --type=service --plain --no-legend`.
///
/// Columns: UNIT FILE STATE [PRESET]
Map<String, String> parseSystemdListUnitFiles(String output) {
  final result = <String, String>{};
  for (final rawLine in output.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('UNIT FILE') || line.startsWith('STATE ')) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final name = parts[0];
    if (!name.endsWith('.service') || !isValidSystemdUnitName(name)) continue;
    result[name] = parts[1];
  }
  return result;
}

/// Merges list-units and list-unit-files into a sorted unit list.
List<SystemdUnit> mergeSystemdListings({
  required String listUnitsOutput,
  required String listUnitFilesOutput,
}) {
  final units = parseSystemdListUnits(listUnitsOutput);
  final files = parseSystemdListUnitFiles(listUnitFilesOutput);

  // Include enabled-but-inactive units that only appear in unit-files.
  for (final entry in files.entries) {
    final existing = units[entry.key];
    if (existing != null) {
      units[entry.key] = existing.copyWith(unitFileState: entry.value);
    } else {
      units[entry.key] = SystemdUnit(
        name: entry.key,
        loadState: 'not-found',
        activeState: 'inactive',
        subState: 'dead',
        description: '',
        unitFileState: entry.value,
      );
    }
  }

  int rank(SystemdUnit u) {
    if (u.isFailed) return 0;
    if (u.isActive) return 1;
    return 2;
  }

  final list = units.values.toList()
    ..sort((a, b) {
      // Failed first, then active, then name.
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return list;
}

/// Parses the remote probe script output into a snapshot.
SystemdUnitsSnapshot parseSystemdProbeOutput(String stdout) {
  if (stdout.contains('--NOSYSTEMD--')) {
    return const SystemdUnitsSnapshot(
      available: false,
      error: 'systemctl was not found on this host (systemd may be absent).',
    );
  }

  String section(String name) {
    final start = stdout.indexOf('--$name--');
    if (start < 0) return '';
    final from = start + name.length + 4;
    final next = stdout.indexOf('\n--', from);
    final body = next < 0
        ? stdout.substring(from)
        : stdout.substring(from, next);
    return body.trim();
  }

  final units = mergeSystemdListings(
    listUnitsOutput: section('UNITS'),
    listUnitFilesOutput: section('FILES'),
  );
  return SystemdUnitsSnapshot(available: true, units: units);
}
