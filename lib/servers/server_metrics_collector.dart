import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'server_models.dart';

abstract interface class ServerMetricsCollector {
  String get id;
  String get label;

  Future<ServerStats?> collect(SSHClient client);
}

/// Selects the first collector that can return a valid result for the host.
class AutoServerMetricsCollector implements ServerMetricsCollector {
  AutoServerMetricsCollector({List<ServerMetricsCollector>? collectors})
    : _collectors =
          collectors ??
          const [LinuxProcfsMetricsCollector(), UptimeMetricsCollector()];

  final List<ServerMetricsCollector> _collectors;

  @override
  String get id => 'auto';

  @override
  String get label => 'Automatic';

  @override
  Future<ServerStats?> collect(SSHClient client) async {
    for (final collector in _collectors) {
      try {
        final stats = await collector.collect(client);
        if (stats != null) return stats;
      } catch (_) {
        // Try the next compatible collector.
      }
    }
    return null;
  }
}

class LinuxProcfsMetricsCollector implements ServerMetricsCollector {
  const LinuxProcfsMetricsCollector();

  @override
  String get id => 'linux-procfs';

  @override
  String get label => 'Linux procfs';

  @override
  Future<ServerStats?> collect(SSHClient client) async {
    final output = await _run(
      client,
      "sh -c 'cat /proc/loadavg; echo --MEM--; cat /proc/meminfo; echo --UPTIME--; cut -d. -f1 /proc/uptime'",
    );
    final sections = output.split('--MEM--');
    if (sections.length != 2) return null;
    final load = double.tryParse(sections.first.trim().split(' ').first);
    final memoryAndUptime = sections[1].split('--UPTIME--');
    if (memoryAndUptime.length != 2 || load == null) return null;
    int? valueFor(String label) {
      final match = RegExp('$label:\\s+(\\d+)').firstMatch(memoryAndUptime[0]);
      return match == null ? null : int.tryParse(match.group(1)!);
    }

    return ServerStats(
      collectorId: id,
      updatedAt: DateTime.now(),
      loadAverage: load,
      memoryTotalKb: valueFor('MemTotal'),
      memoryAvailableKb: valueFor('MemAvailable'),
      uptime: Duration(seconds: int.tryParse(memoryAndUptime[1].trim()) ?? 0),
    );
  }
}

/// A portable fallback for POSIX-like hosts where procfs is unavailable.
class UptimeMetricsCollector implements ServerMetricsCollector {
  const UptimeMetricsCollector();

  @override
  String get id => 'uptime';

  @override
  String get label => 'Uptime command';

  @override
  Future<ServerStats?> collect(SSHClient client) async {
    final output = await _run(client, 'uptime');
    final match = RegExp(
      r'load average[s]?:\s*([0-9.]+)',
      caseSensitive: false,
    ).firstMatch(output);
    final load = match == null ? null : double.tryParse(match.group(1)!);
    if (load == null) return null;
    return ServerStats(
      collectorId: id,
      updatedAt: DateTime.now(),
      loadAverage: load,
    );
  }
}

Future<String> _run(SSHClient client, String command) async {
  final session = await client.execute(command);
  final output = await utf8.decoder.bind(session.stdout).join();
  await session.done;
  return output;
}
