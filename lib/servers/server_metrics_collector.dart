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
      "sh -c 'cat /proc/loadavg; echo --CPU--; getconf _NPROCESSORS_ONLN 2>/dev/null || nproc; echo --MEM--; cat /proc/meminfo; echo --DISK--; df -Pk / | tail -n 1; echo --UPTIME--; cut -d. -f1 /proc/uptime'",
    );
    final sections = output.split('--CPU--');
    if (sections.length != 2) return null;
    final loads = sections.first.trim().split(RegExp(r'\s+'));
    final load = double.tryParse(loads.first);
    final cpuAndRest = sections[1].split('--MEM--');
    if (cpuAndRest.length != 2 || load == null) return null;
    final memoryAndRest = cpuAndRest[1].split('--DISK--');
    if (memoryAndRest.length != 2) return null;
    final diskAndUptime = memoryAndRest[1].split('--UPTIME--');
    if (diskAndUptime.length != 2) return null;
    int? valueFor(String label) {
      final match = RegExp('$label:\\s+(\\d+)').firstMatch(memoryAndRest[0]);
      return match == null ? null : int.tryParse(match.group(1)!);
    }

    final diskFields = diskAndUptime[0].trim().split(RegExp(r'\s+'));

    return ServerStats(
      collectorId: id,
      updatedAt: DateTime.now(),
      loadAverage: load,
      loadAverage5: loads.length > 1 ? double.tryParse(loads[1]) : null,
      loadAverage15: loads.length > 2 ? double.tryParse(loads[2]) : null,
      cpuCount: int.tryParse(cpuAndRest[0].trim()),
      memoryTotalKb: valueFor('MemTotal'),
      memoryAvailableKb: valueFor('MemAvailable'),
      swapTotalKb: valueFor('SwapTotal'),
      swapFreeKb: valueFor('SwapFree'),
      diskTotalKb: diskFields.length > 1 ? int.tryParse(diskFields[1]) : null,
      diskAvailableKb: diskFields.length > 3
          ? int.tryParse(diskFields[3])
          : null,
      uptime: Duration(seconds: int.tryParse(diskAndUptime[1].trim()) ?? 0),
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
