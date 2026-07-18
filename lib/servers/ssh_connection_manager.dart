import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'package:maid_kit/containers/container_models.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'activity_models.dart';
import 'crontab_models.dart';
import 'firewall_models.dart';
import 'server_metrics_collector.dart';
import 'server_models.dart';
import 'terminal_session_adapter.dart';

typedef HostKeyApproval = Future<bool> Function(HostKeyPrompt prompt);

class SshConnectionManager {
  SshConnectionManager(
    this._terminalAdapterFactory, {
    ServerMetricsCollector? metricsCollector,
  }) : _metricsCollector = metricsCollector ?? AutoServerMetricsCollector();

  final TerminalSessionAdapterFactory Function() _terminalAdapterFactory;
  final ServerMetricsCollector _metricsCollector;

  /// These clients are used exclusively for collecting server information.
  /// Terminal shells keep their own clients so reconnecting statistics never
  /// interrupts an interactive session.
  final _sessions = <int, SSHClient>{};
  final _terminals = <String, _TerminalConnection>{};
  final _controller = StreamController<List<SshSessionInfo>>.broadcast();
  final _states = <int, SshSessionInfo>{};
  var _nextTerminalId = 0;

  Stream<List<SshSessionInfo>> get sessions => _controller.stream;
  List<SshSessionInfo> get current => _states.values.toList();

  /// Returns the retained authenticated client for [serverId], if available.
  ///
  /// Feature code should reuse this client for remote operations instead of
  /// opening a second transport connection.
  SSHClient? clientFor(int serverId) {
    final client = _sessions[serverId];
    return client == null || client.isClosed ? null : client;
  }

  Future<T> withClient<T>(
    int serverId,
    Future<T> Function(SSHClient client) run,
  ) {
    final client = clientFor(serverId);
    if (client == null) {
      throw StateError('Connect to this server before running an operation.');
    }
    return run(client);
  }

  Future<TerminalSessionHandle> openTerminal(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    String? initialDirectory,
  }) async {
    final client = await _createClient(
      server,
      credential,
      approve,
      knownHostKeyFingerprint: knownHostKeyFingerprint,
    );
    late SSHSession shell;
    try {
      shell = await client.shell(
        pty: const SSHPtyConfig(type: 'xterm-256color', width: 120, height: 36),
      );
    } catch (_) {
      client.close();
      rethrow;
    }
    final terminal = _terminalAdapterFactory().create();
    final terminalId = 'terminal-${_nextTerminalId++}';
    final binding = TerminalSessionBinding(
      adapter: terminal,
      stdout: shell.stdout,
      stderr: shell.stderr,
      send: shell.write,
      resize: (event) => shell.resizeTerminal(
        event.columns,
        event.rows,
        event.pixelWidth,
        event.pixelHeight,
      ),
    );
    _terminals[terminalId] = _TerminalConnection(
      serverId: server.id,
      client: client,
      shell: shell,
      binding: binding,
    );
    unawaited(
      shell.done.whenComplete(() {
        if (identical(_terminals[terminalId]?.shell, shell)) {
          unawaited(closeTerminal(terminalId));
        }
      }),
    );
    final directory = initialDirectory?.trim();
    if (directory != null && directory.isNotEmpty) {
      // Move into the requested remote folder after the shell starts. Quote the
      // path so spaces and special characters remain literal.
      shell.write(utf8.encode('cd ${_shellSingleQuote(directory)}\n'));
    }
    return TerminalSessionHandle(
      id: terminalId,
      adapter: terminal,
      done: shell.done,
    );
  }

  /// POSIX-safe single-quoted string for remote shell commands.
  String _shellSingleQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  Future<void> closeTerminal(String terminalId) async {
    final terminal = _terminals.remove(terminalId);
    if (terminal == null) return;
    await terminal.shell.stdin.close();
    await terminal.binding.close();
    terminal.client.close();
  }

  Future<void> refreshServerInfo(Server server) async {
    final client = clientFor(server.id);
    final state = _states[server.id];
    if (client == null || client.isClosed || state == null) return;
    if (server.collectStats) await _refreshStats(client, state);
    if (server.collectSystemInfo) {
      await _refreshSystemInfo(client, _states[server.id] ?? state);
    }
  }

  /// Refreshes only the dynamic, low-cost metrics used by server lists and
  /// background connections. Detail pages call [refreshServerInfo] instead.
  Future<void> refreshBasicServerInfo(Server server) async {
    final client = clientFor(server.id);
    final state = _states[server.id];
    if (client == null || client.isClosed || state == null) return;
    if (server.collectStats) await _refreshStats(client, state);
  }

  Future<List<ServerProcess>> listProcesses(int serverId) async {
    return withClient(serverId, (client) async {
      final session = await client.execute(
        'LC_ALL=C ps -eo pid=,user=,%cpu=,%mem=,rss=,comm= --sort=-%cpu | head -n 20',
      );
      final output = await utf8.decoder.bind(session.stdout).join();
      await session.done;
      return output
          .split('\n')
          .map(_parseProcess)
          .whereType<ServerProcess>()
          .toList();
    });
  }

  /// Collects raw host counters for the Activity tab in a single SSH round-trip.
  Future<ActivityCounters> collectActivityCounters(int serverId) async {
    return withClient(serverId, (client) async {
      final result = await _execute(client, r'''
sh -c '
echo --STAT--
head -n 1 /proc/stat 2>/dev/null || true
echo --LOAD--
cat /proc/loadavg 2>/dev/null || true
echo --CPU--
getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1
echo --MEM--
cat /proc/meminfo 2>/dev/null || true
echo --DISK--
df -Pk / 2>/dev/null | tail -n 1 || true
echo --NET--
cat /proc/net/dev 2>/dev/null || true
echo --UPTIME--
cut -d. -f1 /proc/uptime 2>/dev/null || true
'
''');
      if (result.exitCode != 0 && result.stdout.trim().isEmpty) {
        throw StateError(_commandError(result));
      }
      return _parseActivityCounters(result.stdout);
    });
  }

  ActivityCounters _parseActivityCounters(String output) {
    String section(String name) {
      final start = output.indexOf('--$name--');
      if (start < 0) return '';
      final after = start + name.length + 4;
      final next = output.indexOf('--', after);
      return (next < 0
              ? output.substring(after)
              : output.substring(after, next))
          .trim();
    }

    final statLine = section('STAT');
    int? cpuIdle;
    int? cpuTotal;
    if (statLine.startsWith('cpu')) {
      final fields = statLine
          .split(RegExp(r'\s+'))
          .skip(1)
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      if (fields.length >= 4) {
        // user nice system idle iowait irq softirq steal …
        final idle = fields[3] + (fields.length > 4 ? fields[4] : 0);
        final total = fields.fold<int>(0, (sum, value) => sum + value);
        cpuIdle = idle;
        cpuTotal = total;
      }
    }

    final loads = section('LOAD').split(RegExp(r'\s+'));
    int? memValue(String label) {
      final match = RegExp('$label:\\s+(\\d+)').firstMatch(section('MEM'));
      return match == null ? null : int.tryParse(match.group(1)!);
    }

    final diskFields = section('DISK').split(RegExp(r'\s+'));
    var netRx = 0;
    var netTx = 0;
    var hasNet = false;
    for (final line in section('NET').split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.contains(':')) continue;
      final parts = trimmed.split(':');
      if (parts.length < 2) continue;
      final iface = parts[0].trim();
      if (iface == 'lo') continue;
      final cols = parts[1].trim().split(RegExp(r'\s+'));
      if (cols.length < 9) continue;
      final rx = int.tryParse(cols[0]);
      final tx = int.tryParse(cols[8]);
      if (rx == null || tx == null) continue;
      netRx += rx;
      netTx += tx;
      hasNet = true;
    }

    return ActivityCounters(
      at: DateTime.now(),
      cpuIdle: cpuIdle,
      cpuTotal: cpuTotal,
      load1: loads.isNotEmpty ? double.tryParse(loads[0]) : null,
      load5: loads.length > 1 ? double.tryParse(loads[1]) : null,
      load15: loads.length > 2 ? double.tryParse(loads[2]) : null,
      cpuCount: int.tryParse(section('CPU')),
      memoryTotalKb: memValue('MemTotal'),
      memoryAvailableKb: memValue('MemAvailable'),
      swapTotalKb: memValue('SwapTotal'),
      swapFreeKb: memValue('SwapFree'),
      diskTotalKb: diskFields.length > 1 ? int.tryParse(diskFields[1]) : null,
      diskAvailableKb: diskFields.length > 3
          ? int.tryParse(diskFields[3])
          : null,
      netRxBytes: hasNet ? netRx : null,
      netTxBytes: hasNet ? netTx : null,
      uptime: Duration(seconds: int.tryParse(section('UPTIME')) ?? 0),
    );
  }

  /// Reads the current user's crontab (`crontab -l`).
  Future<CrontabDocument> listCrontab(int serverId) async {
    return withClient(serverId, (client) async {
      final result = await _execute(client, 'crontab -l');
      final combined = '${result.stderr}\n${result.stdout}'.toLowerCase();
      if (result.exitCode != 0) {
        if (combined.contains('no crontab')) {
          return const CrontabDocument(entries: [], exists: false);
        }
        throw StateError(_commandError(result));
      }
      return parseCrontab(result.stdout);
    });
  }

  /// Replaces the current user's crontab with [document].
  Future<void> installCrontab(int serverId, CrontabDocument document) async {
    await withClient(serverId, (client) async {
      final text = document.toCrontabText();
      // Empty crontab: remove it rather than installing a blank file.
      if (text.trim().isEmpty) {
        final result = await _execute(client, 'crontab -r');
        // "no crontab" is fine when removing.
        if (result.exitCode != 0) {
          final message = _commandError(result).toLowerCase();
          if (!message.contains('no crontab')) {
            throw StateError(_commandError(result));
          }
        }
        return;
      }
      final encoded = base64.encode(
        utf8.encode(text.endsWith('\n') ? text : '$text\n'),
      );
      final result = await _execute(
        client,
        "echo $encoded | base64 -d | crontab -",
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  /// Detects and reads the host firewall status (UFW, firewalld, nft, iptables).
  Future<FirewallStatus> getFirewallStatus(
    int serverId, {
    bool sshUserIsRoot = false,
    String? sudoPassword,
  }) async {
    return withClient(serverId, (client) async {
      final prefix = _rootPrefix(sshUserIsRoot, sudoPassword);
      final stdin = _rootStdin(sshUserIsRoot, sudoPassword);

      Future<_CommandResult> run(String command) =>
          _execute(client, '$prefix$command', stdin: stdin);

      // Prefer the friendliest management CLIs first.
      final ufwPath = await _execute(client, 'command -v ufw');
      if (ufwPath.exitCode == 0 && ufwPath.stdout.trim().isNotEmpty) {
        final numbered = await run('ufw status numbered');
        final verbose = await run('ufw status verbose');
        return _parseUfwStatus(numbered, verbose: verbose);
      }

      final firewallCmd = await _execute(client, 'command -v firewall-cmd');
      if (firewallCmd.exitCode == 0 && firewallCmd.stdout.trim().isNotEmpty) {
        return _parseFirewalldStatus(
          await run('firewall-cmd --state'),
          await run('firewall-cmd --list-all'),
        );
      }

      final nft = await _execute(client, 'command -v nft');
      if (nft.exitCode == 0 && nft.stdout.trim().isNotEmpty) {
        final ruleset = await run('nft list ruleset');
        return _parseNftStatus(ruleset);
      }

      final iptables = await _execute(client, 'command -v iptables');
      if (iptables.exitCode == 0 && iptables.stdout.trim().isNotEmpty) {
        final rules = await run('iptables -L -n -v --line-numbers');
        return _parseIptablesStatus(rules);
      }

      return const FirewallStatus(
        backend: FirewallBackend.none,
        active: false,
        error:
            'No supported firewall tool was found (ufw, firewalld, nft, iptables).',
      );
    });
  }

  Future<void> setFirewallEnabled(
    int serverId, {
    required bool enabled,
    bool sshUserIsRoot = false,
    String? sudoPassword,
  }) async {
    await withClient(serverId, (client) async {
      final status = await getFirewallStatus(
        serverId,
        sshUserIsRoot: sshUserIsRoot,
        sudoPassword: sudoPassword,
      );
      final prefix = _rootPrefix(sshUserIsRoot, sudoPassword);
      final stdin = _rootStdin(sshUserIsRoot, sudoPassword);
      final command = switch (status.backend) {
        FirewallBackend.ufw => enabled ? 'ufw --force enable' : 'ufw disable',
        FirewallBackend.firewalld =>
          enabled ? 'systemctl start firewalld' : 'systemctl stop firewalld',
        FirewallBackend.nftables ||
        FirewallBackend.iptables ||
        FirewallBackend.none => throw StateError(
          'Enabling/disabling is only supported for UFW and firewalld.',
        ),
      };
      final result = await _execute(client, '$prefix$command', stdin: stdin);
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  Future<void> addFirewallRule(
    int serverId, {
    required FirewallRuleDraft draft,
    bool sshUserIsRoot = false,
    String? sudoPassword,
  }) async {
    final port = draft.port.trim();
    if (!RegExp(r'^[0-9]{1,5}(:[0-9]{1,5})?$').hasMatch(port) &&
        !RegExp(r'^[a-zA-Z0-9/_-]+$').hasMatch(port)) {
      throw ArgumentError.value(port, 'port', 'Invalid port or service name.');
    }
    final protocol = draft.protocol.trim().toLowerCase();
    if (protocol.isNotEmpty &&
        !const {'tcp', 'udp', 'any', ''}.contains(protocol)) {
      throw ArgumentError.value(protocol, 'protocol', 'Use tcp, udp, or any.');
    }
    await withClient(serverId, (client) async {
      final status = await getFirewallStatus(
        serverId,
        sshUserIsRoot: sshUserIsRoot,
        sudoPassword: sudoPassword,
      );
      final prefix = _rootPrefix(sshUserIsRoot, sudoPassword);
      final stdin = _rootStdin(sshUserIsRoot, sudoPassword);
      final result = switch (status.backend) {
        FirewallBackend.ufw => await _execute(
          client,
          '$prefix${_ufwAddCommand(draft)}',
          stdin: stdin,
        ),
        FirewallBackend.firewalld => await _execute(
          client,
          '$prefix${_firewalldAddCommand(draft)}',
          stdin: stdin,
        ),
        _ => throw StateError(
          'Adding rules is only supported for UFW and firewalld.',
        ),
      };
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  Future<void> deleteFirewallRule(
    int serverId, {
    required FirewallRule rule,
    bool sshUserIsRoot = false,
    String? sudoPassword,
  }) async {
    await withClient(serverId, (client) async {
      final status = await getFirewallStatus(
        serverId,
        sshUserIsRoot: sshUserIsRoot,
        sudoPassword: sudoPassword,
      );
      final prefix = _rootPrefix(sshUserIsRoot, sudoPassword);
      final stdin = _rootStdin(sshUserIsRoot, sudoPassword);
      final result = switch (status.backend) {
        FirewallBackend.ufw => await _execute(
          client,
          // Prefer numbered delete when the id is a UFW rule number.
          RegExp(r'^\d+$').hasMatch(rule.id)
              ? '${prefix}ufw --force delete ${rule.id}'
              : '${prefix}ufw delete ${_shellSingleQuote(rule.display)}',
          stdin: stdin,
        ),
        FirewallBackend.firewalld => await _execute(
          client,
          rule.id.startsWith('service:')
              ? '${prefix}sh -c "firewall-cmd --permanent --remove-service=${rule.id.substring('service:'.length)} && firewall-cmd --reload"'
              : '${prefix}sh -c "firewall-cmd --permanent --remove-port=${rule.id} && firewall-cmd --reload"',
          stdin: stdin,
        ),
        _ => throw StateError(
          'Deleting rules is only supported for UFW and firewalld.',
        ),
      };
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  String _rootPrefix(bool sshUserIsRoot, String? sudoPassword) {
    if (sshUserIsRoot) return '';
    return sudoPassword == null ? 'sudo -n ' : 'sudo -S -p "" ';
  }

  String? _rootStdin(bool sshUserIsRoot, String? sudoPassword) {
    if (sshUserIsRoot) return null;
    return sudoPassword;
  }

  String _ufwAddCommand(FirewallRuleDraft draft) {
    final action = switch (draft.action) {
      FirewallAction.allow => 'allow',
      FirewallAction.deny => 'deny',
      FirewallAction.reject => 'reject',
      FirewallAction.drop => 'deny',
    };
    final port = draft.port.trim();
    final protocol = draft.protocol.trim().toLowerCase();
    final target = protocol.isEmpty || protocol == 'any'
        ? port
        : '$port/$protocol';
    final from = draft.source?.trim();
    if (from != null && from.isNotEmpty) {
      return 'ufw $action from ${_shellSingleQuote(from)} to any port '
          '${protocol.isEmpty || protocol == 'any' ? port : '$port proto $protocol'}';
    }
    return 'ufw $action $target';
  }

  String _firewalldAddCommand(FirewallRuleDraft draft) {
    final port = draft.port.trim();
    final protocol = draft.protocol.trim().toLowerCase();
    final proto = protocol.isEmpty || protocol == 'any' ? 'tcp' : protocol;
    final portSpec = port.contains('/') ? port : '$port/$proto';
    // Single sudo session so both permanent write and reload succeed.
    return 'sh -c "firewall-cmd --permanent --add-port=$portSpec && firewall-cmd --reload"';
  }

  FirewallStatus _parseUfwStatus(
    _CommandResult result, {
    _CommandResult? verbose,
  }) {
    final text = result.stdout.isNotEmpty ? result.stdout : result.stderr;
    final verboseText = verbose == null
        ? text
        : (verbose.stdout.isNotEmpty ? verbose.stdout : verbose.stderr);
    if (result.exitCode != 0 && text.trim().isEmpty) {
      return FirewallStatus(
        backend: FirewallBackend.ufw,
        active: false,
        error: _commandError(result),
      );
    }
    final statusSource = verboseText.isNotEmpty ? verboseText : text;
    final lower = statusSource.toLowerCase();
    final active = lower.contains('status: active');
    String? defaultIncoming;
    String? defaultOutgoing;
    final defaultMatch = RegExp(
      r'Default:\s*(\w+)\s*\(incoming\),\s*(\w+)\s*\(outgoing\)',
      caseSensitive: false,
    ).firstMatch(statusSource);
    if (defaultMatch != null) {
      defaultIncoming = defaultMatch.group(1);
      defaultOutgoing = defaultMatch.group(2);
    }

    final rules = <FirewallRule>[];
    // Prefer numbered status if present; otherwise parse verbose rows.
    final numbered = RegExp(r'^\s*\[\s*(\d+)\s*\]\s+(.+)$', multiLine: true);
    final numberedMatches = numbered.allMatches(text).toList();
    if (numberedMatches.isNotEmpty) {
      for (final match in numberedMatches) {
        final id = match.group(1)!;
        // Strip trailing ANSI/color leftovers and "(v6)" annotations stay.
        final body = match
            .group(2)!
            .replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '')
            .trim();
        rules.add(
          FirewallRule(
            id: id,
            display: body,
            action: _guessFirewallAction(body),
          ),
        );
      }
    } else {
      var inRules = false;
      var index = 1;
      for (final line in statusSource.split('\n')) {
        final trimmed = line.trimRight();
        if (trimmed.toLowerCase().startsWith('to ') &&
            trimmed.toLowerCase().contains('action')) {
          inRules = true;
          continue;
        }
        if (!inRules) continue;
        if (trimmed.isEmpty || trimmed.startsWith('--')) continue;
        final fields = trimmed.split(RegExp(r'\s{2,}'));
        if (fields.isEmpty) continue;
        final display = trimmed.trim();
        rules.add(
          FirewallRule(
            id: '$index',
            display: display,
            action: _guessFirewallAction(display),
            port: fields.firstOrNull?.trim(),
          ),
        );
        index++;
      }
    }

    return FirewallStatus(
      backend: FirewallBackend.ufw,
      active: active,
      rules: rules,
      defaultIncoming: defaultIncoming,
      defaultOutgoing: defaultOutgoing,
      rawStatus: statusSource,
      error: result.exitCode != 0 && !active ? _commandError(result) : null,
    );
  }

  FirewallStatus _parseFirewalldStatus(
    _CommandResult stateResult,
    _CommandResult listResult,
  ) {
    final active =
        stateResult.stdout.trim().toLowerCase() == 'running' ||
        stateResult.stderr.trim().toLowerCase() == 'running';
    final text = listResult.stdout.isNotEmpty
        ? listResult.stdout
        : listResult.stderr;
    final rules = <FirewallRule>[];
    final zones = <String>[];
    final zoneMatch = RegExp(
      r'^(\S+)\s*\(active\)',
      multiLine: true,
    ).firstMatch(text);
    if (zoneMatch != null) zones.add(zoneMatch.group(1)!);

    final portsMatch = RegExp(
      r'ports:\s*(.*)$',
      multiLine: true,
    ).firstMatch(text);
    if (portsMatch != null) {
      for (final port in portsMatch.group(1)!.split(RegExp(r'\s+'))) {
        final value = port.trim();
        if (value.isEmpty) continue;
        rules.add(
          FirewallRule(
            id: value,
            display: 'ALLOW $value',
            action: FirewallAction.allow,
            port: value,
          ),
        );
      }
    }
    final servicesMatch = RegExp(
      r'services:\s*(.*)$',
      multiLine: true,
    ).firstMatch(text);
    if (servicesMatch != null) {
      for (final service in servicesMatch.group(1)!.split(RegExp(r'\s+'))) {
        final value = service.trim();
        if (value.isEmpty) continue;
        rules.add(
          FirewallRule(
            id: 'service:$value',
            display: 'ALLOW service $value',
            action: FirewallAction.allow,
            port: value,
          ),
        );
      }
    }

    return FirewallStatus(
      backend: FirewallBackend.firewalld,
      active: active,
      rules: rules,
      zones: zones,
      rawStatus: text,
      error: !active && stateResult.exitCode != 0
          ? _commandError(stateResult)
          : null,
    );
  }

  FirewallStatus _parseNftStatus(_CommandResult result) {
    final text = result.stdout.isNotEmpty ? result.stdout : result.stderr;
    if (result.exitCode != 0 && text.trim().isEmpty) {
      return FirewallStatus(
        backend: FirewallBackend.nftables,
        active: false,
        error: _commandError(result),
      );
    }
    final rules = <FirewallRule>[];
    var index = 1;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('table ') ||
          trimmed.startsWith('chain ') ||
          trimmed == '{' ||
          trimmed == '}') {
        continue;
      }
      rules.add(
        FirewallRule(
          id: '$index',
          display: trimmed,
          action: _guessFirewallAction(trimmed),
        ),
      );
      index++;
      if (rules.length >= 200) break;
    }
    return FirewallStatus(
      backend: FirewallBackend.nftables,
      active: text.trim().isNotEmpty,
      rules: rules,
      rawStatus: text,
    );
  }

  FirewallStatus _parseIptablesStatus(_CommandResult result) {
    final text = result.stdout.isNotEmpty ? result.stdout : result.stderr;
    if (result.exitCode != 0 && text.trim().isEmpty) {
      return FirewallStatus(
        backend: FirewallBackend.iptables,
        active: false,
        error: _commandError(result),
      );
    }
    final rules = <FirewallRule>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('Chain ') ||
          trimmed.startsWith('num ') ||
          trimmed.startsWith('target ')) {
        continue;
      }
      final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(trimmed);
      if (match == null) continue;
      rules.add(
        FirewallRule(
          id: match.group(1)!,
          display: match.group(2)!.trim(),
          action: _guessFirewallAction(match.group(2)!),
        ),
      );
      if (rules.length >= 200) break;
    }
    return FirewallStatus(
      backend: FirewallBackend.iptables,
      active: rules.isNotEmpty || text.contains('Chain'),
      rules: rules,
      rawStatus: text,
    );
  }

  FirewallAction? _guessFirewallAction(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('allow') || lower.contains('accept')) {
      return FirewallAction.allow;
    }
    if (lower.contains('deny') || lower.contains('drop')) {
      return FirewallAction.deny;
    }
    if (lower.contains('reject')) return FirewallAction.reject;
    return null;
  }

  /// Lists every installed Docker and Podman environment for both the SSH user
  /// and root. Root is intentionally non-interactive: MaidKit never requests
  /// or transports a sudo password.
  Future<List<ContainerEnvironment>> listContainers(
    int serverId, {
    bool sshUserIsRoot = false,
    String? sudoPassword,
  }) async {
    return withClient(serverId, (client) async {
      final environments = <ContainerEnvironment>[];
      for (final runtime in ContainerRuntime.values) {
        final available = await _runtimeAvailable(client, runtime);
        if (!available) continue;
        final scopes = sshUserIsRoot
            ? const [ContainerScope.root]
            : ContainerScope.values;
        for (final scope in scopes) {
          environments.add(
            await _listContainerEnvironment(
              client,
              runtime,
              scope,
              sudoPassword: sudoPassword,
            ),
          );
        }
      }
      return _deduplicateContainerEnvironments(environments);
    });
  }

  /// A Docker compatibility shim backed by Podman reports the exact same
  /// containers through both CLIs. Keep one result per ID and scope, with the
  /// native Podman runtime taking precedence so future project actions use it.
  List<ContainerEnvironment> _deduplicateContainerEnvironments(
    List<ContainerEnvironment> environments,
  ) {
    final seenByScope = <ContainerScope, Set<String>>{
      for (final scope in ContainerScope.values) scope: <String>{},
    };
    final keptByEnvironment = <ContainerEnvironment, List<ServerContainer>>{};
    for (final environment in [
      ...environments,
    ]..sort((a, b) => b.runtime.index.compareTo(a.runtime.index))) {
      if (!environment.isAvailable) continue;
      final seen = seenByScope[environment.scope]!;
      keptByEnvironment[environment] = [
        for (final container in environment.containers)
          if (seen.add(container.id)) container,
      ];
    }
    return [
      for (final environment in environments)
        if (!keptByEnvironment.containsKey(environment) ||
            keptByEnvironment[environment]!.isNotEmpty)
          ContainerEnvironment(
            runtime: environment.runtime,
            scope: environment.scope,
            containers:
                keptByEnvironment[environment] ?? environment.containers,
            error: environment.error,
          ),
    ];
  }

  Future<void> runContainerAction(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String containerId,
    required ContainerAction action,
    String? sudoPassword,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]*$').hasMatch(containerId)) {
      throw ArgumentError.value(
        containerId,
        'containerId',
        'Invalid container ID.',
      );
    }
    await withClient(serverId, (client) async {
      final result = await _execute(
        client,
        '${_scopePrefix(scope, sudoPassword)}${runtime.name} ${action.name} $containerId',
        stdin: scope == ContainerScope.root ? sudoPassword : null,
      );
      if (result.exitCode != 0) {
        throw StateError(_commandError(result));
      }
    });
  }

  Future<bool> _runtimeAvailable(
    SSHClient client,
    ContainerRuntime runtime,
  ) async {
    final result = await _execute(client, 'command -v ${runtime.name}');
    return result.exitCode == 0;
  }

  Future<ContainerEnvironment> _listContainerEnvironment(
    SSHClient client,
    ContainerRuntime runtime,
    ContainerScope scope, {
    String? sudoPassword,
  }) async {
    // Podman's `ps` reporter does not implement Docker's `.Label` template
    // field. Read the portable basic fields first, then inspect labels per
    // container; both Docker and Podman expose `.Config.Labels` there.
    final script =
        '''
${runtime.name} ps -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}' |
while IFS="\$(printf '\t')" read -r id name image state status; do
  labels=\$(${runtime.name} inspect --format '{{with index .Config.Labels "com.docker.compose.project"}}{{.}}{{end}}\t{{with index .Config.Labels "io.podman.compose.project"}}{{.}}{{end}}' "\$id")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "\$id" "\$name" "\$image" "\$state" "\$status" "\$labels"
done
''';
    final result = await _execute(
      client,
      _scopedShell(scope, sudoPassword, script),
      stdin: scope == ContainerScope.root ? sudoPassword : null,
    );
    if (result.exitCode != 0) {
      return ContainerEnvironment(
        runtime: runtime,
        scope: scope,
        error: _commandError(result),
      );
    }
    return ContainerEnvironment(
      runtime: runtime,
      scope: scope,
      containers: result.stdout
          .split('\n')
          .map(_parseContainer)
          .whereType<ServerContainer>()
          .toList(),
    );
  }

  Future<_CommandResult> _execute(
    SSHClient client,
    String command, {
    String? stdin,
  }) async {
    final session = await client.execute(command);
    final stdout = utf8.decoder.bind(session.stdout).join();
    final stderr = utf8.decoder.bind(session.stderr).join();
    if (stdin != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode('$stdin\n')));
      await session.stdin.close();
    }
    await session.done;
    return _CommandResult(
      stdout: await stdout,
      stderr: await stderr,
      exitCode: session.exitCode ?? 1,
    );
  }

  /// Streams stdout and stderr chunks while a remote command runs.
  ///
  /// When [usePty] is true (default for live task UIs), the remote process sees
  /// a terminal so tools like docker/podman emit ANSI colors and `\r` progress
  /// rewrites instead of non-interactive plain dumps.
  Future<_CommandResult> _executeStreaming(
    SSHClient client,
    String command, {
    String? stdin,
    void Function(String chunk)? onOutput,
    bool usePty = true,
  }) async {
    final session = await client.execute(
      command,
      pty: usePty
          ? const SSHPtyConfig(type: 'xterm-256color', width: 120, height: 40)
          : null,
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = utf8.decoder.bind(session.stdout).listen((chunk) {
      stdoutBuffer.write(chunk);
      onOutput?.call(chunk);
    }).asFuture<void>();
    final stderrDone = utf8.decoder.bind(session.stderr).listen((chunk) {
      stderrBuffer.write(chunk);
      onOutput?.call(chunk);
    }).asFuture<void>();
    if (stdin != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode('$stdin\n')));
      await session.stdin.close();
    }
    await session.done;
    await Future.wait([stdoutDone, stderrDone]);
    return _CommandResult(
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      exitCode: session.exitCode ?? 1,
    );
  }

  /// Local image tags available to [runtime] under [scope], newest first.
  ///
  /// Used by autocomplete UIs; dangling / untagged images are omitted.
  Future<List<String>> listContainerImages(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    String? sudoPassword,
  }) async {
    return withClient(serverId, (client) async {
      final result = await _execute(
        client,
        '${_scopePrefix(scope, sudoPassword)}'
        "${runtime.name} images --format '{{.Repository}}:{{.Tag}}'",
        stdin: scope == ContainerScope.root ? sudoPassword : null,
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
      final images = <String>{};
      for (final line in result.stdout.split('\n')) {
        final image = line.trim();
        if (image.isEmpty ||
            image == '<none>:<none>' ||
            image.endsWith(':<none>')) {
          continue;
        }
        images.add(image);
      }
      return images.toList()..sort();
    });
  }

  /// Lists Docker and Podman images for the SSH user and root environments.
  Future<List<ImageEnvironment>> listImages(
    int serverId, {
    bool sshUserIsRoot = false,
    String? sudoPassword,
  }) async {
    return withClient(serverId, (client) async {
      final environments = <ImageEnvironment>[];
      for (final runtime in ContainerRuntime.values) {
        final available = await _runtimeAvailable(client, runtime);
        if (!available) continue;
        final scopes = sshUserIsRoot
            ? const [ContainerScope.root]
            : ContainerScope.values;
        for (final scope in scopes) {
          environments.add(
            await _listImageEnvironment(
              client,
              runtime,
              scope,
              sudoPassword: sudoPassword,
            ),
          );
        }
      }
      return _deduplicateImageEnvironments(environments);
    });
  }

  /// Same Docker-via-Podman shim handling as containers: prefer Podman when
  /// both CLIs report an identical image id under the same scope.
  List<ImageEnvironment> _deduplicateImageEnvironments(
    List<ImageEnvironment> environments,
  ) {
    final seenByScope = <ContainerScope, Set<String>>{
      for (final scope in ContainerScope.values) scope: <String>{},
    };
    final keptByEnvironment = <ImageEnvironment, List<ServerContainerImage>>{};
    for (final environment in [
      ...environments,
    ]..sort((a, b) => b.runtime.index.compareTo(a.runtime.index))) {
      if (!environment.isAvailable) continue;
      final seen = seenByScope[environment.scope]!;
      keptByEnvironment[environment] = [
        for (final image in environment.images)
          if (seen.add(image.id)) image,
      ];
    }
    return [
      for (final environment in environments)
        if (!keptByEnvironment.containsKey(environment) ||
            keptByEnvironment[environment]!.isNotEmpty)
          ImageEnvironment(
            runtime: environment.runtime,
            scope: environment.scope,
            images: keptByEnvironment[environment] ?? environment.images,
            error: environment.error,
          ),
    ];
  }

  Future<ImageEnvironment> _listImageEnvironment(
    SSHClient client,
    ContainerRuntime runtime,
    ContainerScope scope, {
    String? sudoPassword,
  }) async {
    final prefix = _scopePrefix(scope, sudoPassword);
    final stdin = scope == ContainerScope.root ? sudoPassword : null;
    final result = await _execute(
      client,
      '$prefix'
      "${runtime.name} images --format "
      "'{{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'",
      stdin: stdin,
    );
    if (result.exitCode != 0) {
      return ImageEnvironment(
        runtime: runtime,
        scope: scope,
        error: _commandError(result),
      );
    }
    final parsed = result.stdout
        .split('\n')
        .map(_parseImage)
        .whereType<ServerContainerImage>()
        .toList();
    final used = await _listUsedImageMarkers(
      client,
      runtime,
      scope,
      sudoPassword: sudoPassword,
    );
    return ImageEnvironment(
      runtime: runtime,
      scope: scope,
      images: [
        for (final image in parsed)
          image.copyWith(unused: !_imageIsInUse(image, used)),
      ],
    );
  }

  /// Collects image IDs and name refs attached to any container so unused
  /// labels match what `image prune -a` would reclaim.
  Future<({Set<String> ids, Set<String> refs})> _listUsedImageMarkers(
    SSHClient client,
    ContainerRuntime runtime,
    ContainerScope scope, {
    String? sudoPassword,
  }) async {
    final stdin = scope == ContainerScope.root ? sudoPassword : null;
    // Image config name from `ps` (may be short) plus canonical Image ID from
    // inspect (sha256:…) so tag rewrites and digests still match.
    final script =
        '''
ids=\$(${runtime.name} ps -aq 2>/dev/null)
if [ -n "\$ids" ]; then
  ${runtime.name} ps -a --no-trunc --format '{{.Image}}'
  ${runtime.name} inspect --format '{{.Image}}' \$ids 2>/dev/null
fi
''';
    final result = await _execute(
      client,
      _scopedShell(scope, sudoPassword, script),
      stdin: stdin,
    );
    if (result.exitCode != 0 && result.stdout.trim().isEmpty) {
      return (ids: <String>{}, refs: <String>{});
    }
    final ids = <String>{};
    final refs = <String>{};
    for (final line in result.stdout.split('\n')) {
      final raw = line.trim();
      if (raw.isEmpty) continue;
      final withoutDigest = raw.split('@').first.trim();
      if (withoutDigest.startsWith('sha256:')) {
        final full = withoutDigest.substring(7);
        ids.add(full);
        if (full.length >= 12) ids.add(full.substring(0, 12));
      } else if (RegExp(r'^[a-f0-9]{12,64}$').hasMatch(withoutDigest)) {
        ids.add(withoutDigest);
        if (withoutDigest.length >= 12) {
          ids.add(withoutDigest.substring(0, 12));
        }
      } else {
        refs.add(withoutDigest);
        final slash = withoutDigest.lastIndexOf('/');
        final name = slash >= 0
            ? withoutDigest.substring(slash + 1)
            : withoutDigest;
        refs.add(name);
        if (!name.contains(':')) {
          refs.add('$name:latest');
        }
      }
    }
    return (ids: ids, refs: refs);
  }

  bool _imageIsInUse(
    ServerContainerImage image,
    ({Set<String> ids, Set<String> refs}) used,
  ) {
    final id = image.id.trim();
    final idBare = id.startsWith('sha256:') ? id.substring(7) : id;
    if (used.ids.contains(id) ||
        used.ids.contains(idBare) ||
        (idBare.length >= 12 && used.ids.contains(idBare.substring(0, 12)))) {
      return true;
    }
    for (final usedId in used.ids) {
      if (usedId.length >= 12 &&
          idBare.length >= 12 &&
          (usedId.startsWith(idBare) || idBare.startsWith(usedId))) {
        return true;
      }
    }

    final repository = image.repository.trim();
    final tag = image.tag.trim();
    if (repository.isEmpty || repository == '<none>') return false;

    final candidates = <String>{
      image.reference,
      repository,
      if (tag.isNotEmpty && tag != '<none>') '$repository:$tag',
      if (tag.isEmpty || tag == '<none>') '$repository:latest',
    };
    // Short names: docker.io/library/nginx:latest ↔ nginx:latest ↔ nginx
    final shortRepo = repository.contains('/')
        ? repository.split('/').last
        : repository;
    candidates.add(shortRepo);
    if (tag.isNotEmpty && tag != '<none>') {
      candidates.add('$shortRepo:$tag');
    } else {
      candidates.add('$shortRepo:latest');
    }

    for (final candidate in candidates) {
      if (used.refs.contains(candidate)) return true;
      for (final ref in used.refs) {
        if (ref == candidate ||
            ref.endsWith('/$candidate') ||
            candidate.endsWith('/$ref') ||
            ref.endsWith(':$candidate') ||
            candidate.endsWith(':$ref')) {
          return true;
        }
      }
    }
    return false;
  }

  ServerContainerImage? _parseImage(String line) {
    final fields = line.split('\t');
    if (fields.length < 5 || fields[0].trim().isEmpty) return null;
    return ServerContainerImage(
      id: fields[0].trim(),
      repository: fields[1].trim(),
      tag: fields[2].trim(),
      size: fields[3].trim(),
      created: fields[4].trim(),
    );
  }

  Future<void> runImageAction(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String imageId,
    required ImageAction action,
    String? sudoPassword,
    void Function(String chunk)? onOutput,
  }) async {
    if (!_safeContainerRef(imageId)) {
      throw ArgumentError.value(imageId, 'imageId', 'Invalid image ID.');
    }
    final command = switch (action) {
      ImageAction.remove => '${runtime.name} rmi $imageId',
    };
    await withClient(serverId, (client) async {
      onOutput?.call('\$ $command\n');
      final result = await _executeStreaming(
        client,
        '${_scopePrefix(scope, sudoPassword)}$command',
        stdin: scope == ContainerScope.root ? sudoPassword : null,
        onOutput: onOutput,
      );
      if (result.exitCode != 0) {
        throw StateError(_commandError(result));
      }
    });
  }

  /// Runs `docker|podman image prune` with optional live [onOutput] streaming.
  ///
  /// Without [allUnused], only dangling (untagged) images are removed. With
  /// [allUnused] (`-a`), every image not used by a container is removed —
  /// matching the UI "Unused" label for tagged images.
  Future<void> pruneImages(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    bool force = true,
    bool allUnused = false,
    String? sudoPassword,
    void Function(String chunk)? onOutput,
  }) async {
    final flags = StringBuffer();
    if (allUnused) flags.write(' -a');
    if (force) flags.write(' -f');
    final displayCmd = '${runtime.name} image prune$flags';
    await withClient(serverId, (client) async {
      onOutput?.call('\$ $displayCmd\n');
      final result = await _executeStreaming(
        client,
        '${_scopePrefix(scope, sudoPassword)}$displayCmd',
        stdin: scope == ContainerScope.root ? sudoPassword : null,
        onOutput: onOutput,
      );
      if (result.exitCode != 0) {
        throw StateError(_commandError(result));
      }
    });
  }

  ServerContainer? _parseContainer(String line) {
    final fields = line.split('\t');
    if (fields.length != 7 || fields.take(5).any((field) => field.isEmpty)) {
      return null;
    }
    return ServerContainer(
      id: fields[0],
      name: fields[1],
      image: fields[2],
      state: fields[3],
      status: fields[4],
      composeProject: fields[5].isEmpty
          ? (fields[6].isEmpty ? null : fields[6])
          : fields[5],
    );
  }

  Future<void> deployComposeProject(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String projectName,
    required String directory,
    required String composeSource,
    String? sudoPassword,
    void Function(String chunk)? onOutput,
  }) async {
    if (!_safeProjectName(projectName) || !_safeRemoteDirectory(directory)) {
      throw ArgumentError('Project name or remote directory is invalid.');
    }
    final encoded = base64.encode(utf8.encode(composeSource));
    await withClient(serverId, (client) async {
      // Keep every part of the deployment in the same privileged shell. A
      // prefix on only `mkdir` leaves the redirected file write running as the
      // SSH user, which fails for folders such as /srv.
      final script =
          'mkdir -p $directory && '
          'printf %s $encoded | base64 -d > $directory/compose.yaml && '
          'cd $directory && COMPOSE_ANSI=always ${runtime.name} compose '
          '--ansi always -p $projectName up -d';
      final command = _scopedShell(scope, sudoPassword, script);
      onOutput?.call(
        '\$ ${runtime.name} compose -p $projectName up -d  ($directory)\n',
      );
      final result = await _executeStreaming(
        client,
        command,
        stdin: scope == ContainerScope.root ? sudoPassword : null,
        onOutput: onOutput,
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  /// Reads the first conventional compose file from a directory using the
  /// selected container scope. This is intentionally command based rather
  /// than SFTP so root-owned project folders can be imported as well.
  Future<(String source, String fileName)?> readComposeFile(
    int serverId, {
    required ContainerScope scope,
    required String directory,
    String? sudoPassword,
  }) async {
    if (!_safeRemoteDirectory(directory)) {
      throw ArgumentError.value(directory, 'directory', 'Invalid directory.');
    }
    const names = [
      'compose.yaml',
      'compose.yml',
      'docker-compose.yaml',
      'docker-compose.yml',
    ];
    final checks = names
        .map(
          (name) =>
              'if [ -f $directory/$name ]; then '
              'printf "%s\\n" $name; cat $directory/$name; exit 0; fi',
        )
        .join('; ');
    return withClient(serverId, (client) async {
      final result = await _execute(
        client,
        _scopedShell(scope, sudoPassword, '$checks; exit 2'),
        stdin: scope == ContainerScope.root ? sudoPassword : null,
      );
      if (result.exitCode == 2) return null;
      if (result.exitCode != 0) throw StateError(_commandError(result));
      final split = result.stdout.indexOf('\n');
      if (split <= 0) return null;
      return (
        result.stdout.substring(split + 1).trimRight(),
        result.stdout.substring(0, split),
      );
    });
  }

  Future<void> startRawContainer(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String image,
    required String name,
    String arguments = '',
    String? sudoPassword,
    void Function(String chunk)? onOutput,
  }) async {
    if (!_safeProjectName(name) || image.trim().isEmpty) {
      throw ArgumentError('Container name and image are required.');
    }
    // Arguments are deliberately a terminal-like escape hatch. The image and
    // name remain validated, while advanced runtime flags stay available.
    final command =
        '${_scopePrefix(scope, sudoPassword)}${runtime.name} run -d '
        '--name $name ${arguments.isEmpty ? '' : '$arguments '}$image';
    await withClient(serverId, (client) async {
      onOutput?.call(
        '\$ ${runtime.name} run -d --name $name '
        '${arguments.isEmpty ? '' : '$arguments '}$image\n',
      );
      final result = await _executeStreaming(
        client,
        command,
        stdin: scope == ContainerScope.root ? sudoPassword : null,
        onOutput: onOutput,
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  bool _safeContainerRef(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]*$').hasMatch(value);

  /// Full inspect payload for one container, including fields used to rebuild
  /// a `run` command.
  Future<ContainerInspectDetail> inspectContainer(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String containerId,
    String? sudoPassword,
  }) async {
    if (!_safeContainerRef(containerId)) {
      throw ArgumentError.value(containerId, 'containerId', 'Invalid id.');
    }
    return withClient(serverId, (client) async {
      final result = await _execute(
        client,
        '${_scopePrefix(scope, sudoPassword)}'
        "${runtime.name} inspect --format '{{json .}}' $containerId",
        stdin: scope == ContainerScope.root ? sudoPassword : null,
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
      final raw = result.stdout.trim();
      if (raw.isEmpty) {
        throw StateError('Inspect returned no data for $containerId.');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Inspect payload was not a JSON object.');
      }
      return _parseContainerInspect(decoded, rawJson: raw);
    });
  }

  /// Recent container logs (`stdout`/`stderr` merged by the runtime).
  Future<String> readContainerLogs(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String containerId,
    int tail = 300,
    bool timestamps = false,
    String? sudoPassword,
  }) async {
    if (!_safeContainerRef(containerId)) {
      throw ArgumentError.value(containerId, 'containerId', 'Invalid id.');
    }
    final safeTail = tail.clamp(1, 5000);
    return withClient(serverId, (client) async {
      final flags = StringBuffer('--tail $safeTail');
      if (timestamps) flags.write(' --timestamps');
      final result = await _execute(
        client,
        '${_scopePrefix(scope, sudoPassword)}'
        '${runtime.name} logs $flags $containerId',
        stdin: scope == ContainerScope.root ? sudoPassword : null,
      );
      // Docker returns non-zero for missing containers; still surface stderr.
      if (result.exitCode != 0 && result.stdout.trim().isEmpty) {
        throw StateError(_commandError(result));
      }
      final output = result.stdout.isEmpty ? result.stderr : result.stdout;
      if (result.stderr.trim().isNotEmpty && result.stdout.isNotEmpty) {
        return '${result.stdout}\n${result.stderr}';
      }
      return output;
    });
  }

  Future<void> removeContainer(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String containerId,
    bool force = false,
    String? sudoPassword,
    void Function(String chunk)? onOutput,
  }) async {
    if (!_safeContainerRef(containerId)) {
      throw ArgumentError.value(containerId, 'containerId', 'Invalid id.');
    }
    final command =
        '${_scopePrefix(scope, sudoPassword)}'
        '${runtime.name} rm ${force ? '-f ' : ''}$containerId';
    await withClient(serverId, (client) async {
      onOutput?.call(
        '\$ ${runtime.name} rm ${force ? '-f ' : ''}$containerId\n',
      );
      final result = await _executeStreaming(
        client,
        command,
        stdin: scope == ContainerScope.root ? sudoPassword : null,
        onOutput: onOutput,
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  ContainerInspectDetail _parseContainerInspect(
    Map<String, dynamic> json, {
    required String rawJson,
  }) {
    final state = _asMap(json['State']);
    final config = _asMap(json['Config']);
    final hostConfig = _asMap(json['HostConfig']);
    final networkSettings = _asMap(json['NetworkSettings']);
    final restart = _asMap(hostConfig['RestartPolicy']);
    final nameRaw = json['Name']?.toString() ?? '';
    final name = nameRaw.startsWith('/') ? nameRaw.substring(1) : nameRaw;

    final env = <String>[
      for (final item in _asList(config['Env']))
        if (item.toString().isNotEmpty) item.toString(),
    ];
    final entrypoint = <String>[
      for (final item in _asList(config['Entrypoint'])) item.toString(),
    ];
    final command = <String>[
      for (final item in _asList(config['Cmd'])) item.toString(),
    ];
    final binds = <String>[
      for (final item in _asList(hostConfig['Binds'])) item.toString(),
    ];
    final mounts = <String>[];
    for (final item in _asList(json['Mounts'])) {
      final mount = _asMap(item);
      final source = mount['Source']?.toString() ?? '';
      final destination = mount['Destination']?.toString() ?? '';
      if (source.isEmpty || destination.isEmpty) continue;
      final mode = mount['Mode']?.toString() ?? '';
      mounts.add(
        mode.isEmpty ? '$source:$destination' : '$source:$destination:$mode',
      );
    }
    final ports = <String>[];
    final portBindings = _asMap(hostConfig['PortBindings']);
    for (final entry in portBindings.entries) {
      final containerPort = entry.key.toString(); // e.g. 80/tcp
      final bindings = _asList(entry.value);
      if (bindings.isEmpty) {
        ports.add(containerPort.replaceAll('/tcp', '').replaceAll('/udp', ''));
        continue;
      }
      for (final binding in bindings) {
        final map = _asMap(binding);
        final hostIp = map['HostIp']?.toString() ?? '';
        final hostPort = map['HostPort']?.toString() ?? '';
        final containerOnly = containerPort.split('/').first;
        if (hostPort.isEmpty) {
          ports.add(containerOnly);
        } else if (hostIp.isEmpty || hostIp == '0.0.0.0' || hostIp == '::') {
          ports.add('$hostPort:$containerOnly');
        } else {
          ports.add('$hostIp:$hostPort:$containerOnly');
        }
      }
    }
    final labels = <String, String>{};
    final labelMap = _asMap(config['Labels']);
    for (final entry in labelMap.entries) {
      labels[entry.key.toString()] = entry.value?.toString() ?? '';
    }
    final networks = <String>[];
    final networksMap = _asMap(networkSettings['Networks']);
    networks.addAll(networksMap.keys.map((key) => key.toString()));

    final stateName =
        state['Status']?.toString() ?? state['status']?.toString() ?? '';
    final status = [
      if (stateName.isNotEmpty) stateName,
      if (state['Error']?.toString().isNotEmpty == true) state['Error'],
      if (state['ExitCode'] != null && stateName != 'running')
        'exit ${state['ExitCode']}',
    ].join(' · ');

    return ContainerInspectDetail(
      id: json['Id']?.toString() ?? '',
      name: name,
      image: config['Image']?.toString() ?? json['Image']?.toString() ?? '',
      state: stateName,
      status: status.isEmpty ? stateName : status,
      created: json['Created']?.toString(),
      startedAt: state['StartedAt']?.toString(),
      finishedAt: state['FinishedAt']?.toString(),
      exitCode: int.tryParse(state['ExitCode']?.toString() ?? ''),
      platform: json['Platform']?.toString() ?? config['Platform']?.toString(),
      restartPolicy: restart['Name']?.toString() ?? 'no',
      networkMode: hostConfig['NetworkMode']?.toString() ?? 'default',
      workingDir: config['WorkingDir']?.toString(),
      user: config['User']?.toString(),
      entrypoint: entrypoint,
      command: command,
      env: env,
      ports: ports,
      binds: binds.isNotEmpty ? binds : mounts,
      mounts: mounts,
      labels: labels,
      networks: networks,
      rawJson: rawJson,
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    return const [];
  }

  /// Runs a compose project action with optional live [onOutput] streaming
  /// (same pattern as [startRawContainer] / [deployComposeProject]).
  Future<void> runComposeProjectAction(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    required String projectName,
    required String directory,
    required ComposeProjectAction action,
    String? sudoPassword,
    void Function(String chunk)? onOutput,
  }) async {
    if (!_safeProjectName(projectName) || !_safeRemoteDirectory(directory)) {
      throw ArgumentError('Project name or remote directory is invalid.');
    }
    // Force ANSI + a real TTY so pull/up progress bars and colors stream live.
    final composeCmd =
        'COMPOSE_ANSI=always ${runtime.name} compose --ansi always '
        '-p $projectName ${action.composeArgs}';
    final displayCmd =
        '${runtime.name} compose -p $projectName ${action.composeArgs}';
    await withClient(serverId, (client) async {
      onOutput?.call('\$ $displayCmd  ($directory)\n');
      final result = await _executeStreaming(
        client,
        _scopedShell(scope, sudoPassword, 'cd $directory && $composeCmd'),
        stdin: scope == ContainerScope.root ? sudoPassword : null,
        onOutput: onOutput,
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  /// One-shot resource sample from `docker stats` / `podman stats`.
  ///
  /// When [containerIds] is non-empty, only those containers are sampled.
  /// Stopped IDs are ignored by the runtime and simply omit a row.
  Future<List<ContainerStats>> listContainerStats(
    int serverId, {
    required ContainerRuntime runtime,
    required ContainerScope scope,
    List<String> containerIds = const [],
    String? sudoPassword,
  }) async {
    for (final id in containerIds) {
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$').hasMatch(id)) {
        throw ArgumentError.value(id, 'containerIds', 'Invalid container ID.');
      }
    }
    return withClient(serverId, (client) async {
      final targets = containerIds.isEmpty ? '' : ' ${containerIds.join(' ')}';
      // Go templates are portable across Docker and Podman for these fields.
      final script =
          '${runtime.name} stats --no-stream --format '
          "'{{.ID}}\\t{{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\\t{{.MemPerc}}"
          "\\t{{.NetIO}}\\t{{.BlockIO}}\\t{{.PIDs}}'$targets";
      final result = await _execute(
        client,
        _scopedShell(scope, sudoPassword, script),
        stdin: scope == ContainerScope.root ? sudoPassword : null,
      );
      if (result.exitCode != 0) {
        // Empty set (no running containers) is not an error for the UI.
        final message = _commandError(result).toLowerCase();
        if (message.contains('no such container') ||
            message.contains('you must provide at least one') ||
            message.contains('no containers') ||
            result.stdout.trim().isEmpty) {
          return const [];
        }
        throw StateError(_commandError(result));
      }
      return result.stdout
          .split('\n')
          .map(_parseContainerStats)
          .whereType<ContainerStats>()
          .toList();
    });
  }

  ContainerStats? _parseContainerStats(String line) {
    final fields = line.split('\t');
    if (fields.length < 8) return null;
    final id = fields[0].trim();
    final name = fields[1].trim();
    if (id.isEmpty || name.isEmpty) return null;
    final memParts = _splitIoPair(fields[3]);
    final netParts = _splitIoPair(fields[5]);
    final blockParts = _splitIoPair(fields[6]);
    return ContainerStats(
      id: id,
      name: name,
      cpuPercent: _parsePercent(fields[2]),
      memUsage: fields[3].trim(),
      memPercent: _parsePercent(fields[4]),
      memUsedBytes: memParts.$1,
      memLimitBytes: memParts.$2,
      netIO: fields[5].trim(),
      netRxBytes: netParts.$1,
      netTxBytes: netParts.$2,
      blockIO: fields[6].trim(),
      blockReadBytes: blockParts.$1,
      blockWriteBytes: blockParts.$2,
      pids: int.tryParse(fields[7].trim()),
    );
  }

  double? _parsePercent(String raw) {
    final cleaned = raw.trim().replaceAll('%', '');
    if (cleaned.isEmpty || cleaned == '--') return null;
    return double.tryParse(cleaned);
  }

  /// Parses Docker/Podman pairs such as `1.2MiB / 2GiB` or `1.1kB / 2.2kB`.
  (int?, int?) _splitIoPair(String raw) {
    final parts = raw.split('/');
    if (parts.length != 2) return (null, null);
    return (_parseHumanSize(parts[0]), _parseHumanSize(parts[1]));
  }

  int? _parseHumanSize(String raw) {
    final match = RegExp(
      r'^\s*([\d.]+)\s*([A-Za-z]+)?\s*$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    final unit = (match.group(2) ?? 'B').toLowerCase();
    final multiplier = switch (unit) {
      'b' => 1,
      'kb' || 'k' => 1000,
      'kib' => 1024,
      'mb' || 'm' => 1000 * 1000,
      'mib' => 1024 * 1024,
      'gb' || 'g' => 1000 * 1000 * 1000,
      'gib' => 1024 * 1024 * 1024,
      'tb' || 't' => 1000 * 1000 * 1000 * 1000,
      'tib' => 1024 * 1024 * 1024 * 1024,
      _ => 1,
    };
    return (value * multiplier).round();
  }

  bool _safeProjectName(String value) =>
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]*$').hasMatch(value);

  bool _safeRemoteDirectory(String value) =>
      RegExp(r'^/[a-zA-Z0-9_./-]+$').hasMatch(value) && !value.contains('..');

  String _scopedShell(
    ContainerScope scope,
    String? sudoPassword,
    String script,
  ) {
    final encoded = base64.encode(utf8.encode(script));
    final shell = 'echo $encoded | base64 -d | sh';
    return switch (scope) {
      ContainerScope.user => shell,
      ContainerScope.root =>
        '${_scopePrefix(scope, sudoPassword)}sh -c "$shell"',
    };
  }

  String _scopePrefix(ContainerScope scope, String? sudoPassword) =>
      switch (scope) {
        ContainerScope.user => '',
        ContainerScope.root =>
          sudoPassword == null ? 'sudo -n ' : 'sudo -S -p "" ',
      };

  String _commandError(_CommandResult result) {
    final message = result.stderr.trim().isNotEmpty
        ? result.stderr.trim()
        : result.stdout.trim();
    return message.isEmpty
        ? 'The command exited with code ${result.exitCode}.'
        : message;
  }

  Future<void> _refreshStats(SSHClient client, SshSessionInfo state) async {
    try {
      final stats = await _metricsCollector.collect(client);
      if (stats != null && identical(_sessions[state.serverId], client)) {
        _set((_states[state.serverId] ?? state).copyWith(stats: stats));
      }
    } catch (_) {
      // Statistics are optional and can be unavailable on non-Linux hosts.
    }
  }

  Future<void> _refreshSystemInfo(
    SSHClient client,
    SshSessionInfo state,
  ) async {
    try {
      final session = await client.execute(
        "sh -c 'if [ -r /etc/os-release ]; then . /etc/os-release; printf \"%s\\n\" \"\$PRETTY_NAME\"; else uname -s; fi; uname -r'",
      );
      final output = await utf8.decoder.bind(session.stdout).join();
      await session.done;
      final values = output.trim().split('\n');
      if (values.isNotEmpty && identical(_sessions[state.serverId], client)) {
        _set(
          (_states[state.serverId] ?? state).copyWith(
            systemInfo: ServerSystemInfo(
              distribution: values.firstOrNull,
              kernel: values.length > 1 ? values[1] : null,
            ),
          ),
        );
      }
    } catch (_) {
      // System information is optional on restricted or non-POSIX hosts.
    }
  }

  Future<void> connect(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
  }) async {
    await disconnect(server.id);
    _set(
      SshSessionInfo(
        serverId: server.id,
        serverName: server.name,
        connectedAt: DateTime.now(),
        status: SessionStatus.connecting,
      ),
    );
    String? serverAuthMethods;
    try {
      final client = await _createClient(
        server,
        credential,
        approve,
        knownHostKeyFingerprint: knownHostKeyFingerprint,
        onAuthMethods: (methods) => serverAuthMethods = methods,
      );
      _sessions[server.id] = client;
      _set(_states[server.id]!.copyWith(status: SessionStatus.connected));
      unawaited(refreshServerInfo(server));
      unawaited(
        client.done.whenComplete(() {
          if (!identical(_sessions[server.id], client)) return;
          _sessions.remove(server.id);
          unawaited(_closeTerminalsFor(server.id));
          final state = _states[server.id];
          if (state != null && state.status == SessionStatus.connected) {
            _set(state.copyWith(status: SessionStatus.closed));
          }
        }),
      );
    } catch (error) {
      final message = error is SSHAuthFailError
          ? serverAuthMethods == null || serverAuthMethods!.isEmpty
                ? 'The server rejected the supplied password.'
                : 'The server rejected the supplied password. It advertises: $serverAuthMethods.'
          : error.toString();
      _set(
        _states[server.id]!.copyWith(
          status: SessionStatus.failed,
          error: message,
        ),
      );
      rethrow;
    }
  }

  Future<void> disconnect(int serverId) async {
    final client = _sessions.remove(serverId);
    client?.close();
    final state = _states[serverId];
    if (state != null) _set(state.copyWith(status: SessionStatus.closed));
  }

  void _set(SshSessionInfo value) {
    _states[value.serverId] = value;
    _controller.add(current);
  }

  Future<void> dispose() async {
    for (final terminalId in _terminals.keys.toList()) {
      await closeTerminal(terminalId);
    }
    for (final client in _sessions.values) {
      client.close();
    }
    await _controller.close();
  }

  Future<void> _closeTerminalsFor(int serverId) async {
    final terminalIds = _terminals.entries
        .where((entry) => entry.value.serverId == serverId)
        .map((entry) => entry.key)
        .toList();
    for (final terminalId in terminalIds) {
      await closeTerminal(terminalId);
    }
  }

  ServerProcess? _parseProcess(String line) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < 6) return null;
    final pid = int.tryParse(fields[0]);
    final cpuPercent = double.tryParse(fields[2]);
    final memoryPercent = double.tryParse(fields[3]);
    final rssKb = int.tryParse(fields[4]);
    if (pid == null ||
        cpuPercent == null ||
        memoryPercent == null ||
        rssKb == null) {
      return null;
    }
    return ServerProcess(
      pid: pid,
      user: fields[1],
      cpuPercent: cpuPercent,
      memoryPercent: memoryPercent,
      rssKb: rssKb,
      command: fields.sublist(5).join(' '),
    );
  }

  Future<SSHClient> _createClient(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    void Function(String? methods)? onAuthMethods,
  }) async {
    final identities = credential.type == CredentialType.privateKey
        ? SSHKeyPair.fromPem(credential.privateKey!, credential.keyPassphrase)
        : null;
    final client = SSHClient(
      await SSHSocket.connect(server.host, server.port),
      username: server.username,
      identities: identities,
      onPasswordRequest: credential.type == CredentialType.password
          ? () => credential.password
          : null,
      onUserInfoRequest: credential.type == CredentialType.password
          ? (request) => List<String>.filled(
              request.prompts.length,
              credential.password!,
            )
          : null,
      onVerifyHostKey: (algorithm, fingerprint) {
        final presented =
            'SHA256:${base64Encode(fingerprint).replaceAll('=', '')}';
        if (knownHostKeyFingerprint == presented) return true;
        return approve(
          HostKeyPrompt(
            algorithm: algorithm,
            fingerprint: presented,
            replacesExisting: knownHostKeyFingerprint != null,
          ),
        );
      },
      printTrace: (message) {
        final match = RegExp(
          r'SSH_Message_Userauth_Failure\(methodsLeft: \[(.*?)\]',
        ).firstMatch(message ?? '');
        if (match != null) onAuthMethods?.call(match.group(1));
      },
      handshakeTimeout: const Duration(seconds: 15),
      authTimeout: const Duration(seconds: 15),
    );
    await client.authenticated;
    return client;
  }
}

class TerminalSessionHandle {
  const TerminalSessionHandle({
    required this.id,
    required this.adapter,
    required this.done,
  });

  final String id;
  final TerminalSessionAdapter adapter;
  final Future<void> done;
}

class _TerminalConnection {
  const _TerminalConnection({
    required this.serverId,
    required this.client,
    required this.shell,
    required this.binding,
  });

  final int serverId;
  final SSHClient client;
  final SSHSession shell;
  final TerminalSessionBinding binding;
}

class _CommandResult {
  const _CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}
