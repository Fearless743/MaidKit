import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_connection_actions.dart';
import 'package:maid_kit/servers/server_models.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/ansi_log_view.dart';
import 'package:maid_kit/shared/presentation/app_context_menu.dart';
import 'package:maid_kit/shared/presentation/deploy_terminal.dart';
import 'package:maid_kit/theme.dart';
import 'container_models.dart';

@RoutePage()
class ContainerDetailPage extends ConsumerStatefulWidget {
  const ContainerDetailPage({
    super.key,
    required this.server,
    required this.runtime,
    required this.scope,
    required this.containerId,
    required this.containerName,
  });

  final Server server;
  final ContainerRuntime runtime;
  final ContainerScope scope;
  final String containerId;
  final String containerName;

  @override
  ConsumerState<ContainerDetailPage> createState() =>
      _ContainerDetailPageState();
}

class _ContainerDetailPageState extends ConsumerState<ContainerDetailPage> {
  ContainerInspectDetail? _inspect;
  Object? _inspectError;
  var _loadingInspect = false;

  String? _logs;
  Object? _logsError;
  var _loadingLogs = false;
  var _logTail = 300;
  var _logTimestamps = false;

  ContainerStats? _stats;
  Object? _statsError;

  Timer? _refreshTimer;
  late final FocusedServerNotifier _focusedServerNotifier;
  var _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _focusedServerNotifier = ref.read(focusedServerIdProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusedServerNotifier.focus(widget.server.id);
      unawaited(_bootstrap());
    });
    _startRefreshTimer(ref.read(focusedServerRefreshIntervalProvider));
    ref.listenManual<Duration>(focusedServerRefreshIntervalProvider, (
      _,
      interval,
    ) {
      _startRefreshTimer(interval);
    });
    ref.listenManual(sessionsProvider, (previous, next) {
      final was = _connected(previous?.asData?.value);
      final now = _connected(next.asData?.value);
      if (now && !was) unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Riverpod forbids mutating providers during dispose / tree finalization.
    final serverId = widget.server.id;
    final focused = _focusedServerNotifier;
    Future.microtask(() => focused.clear(serverId));
    super.dispose();
  }

  bool _connected(List<SshSessionInfo>? sessions) {
    if (sessions == null) return false;
    return sessions.any(
      (session) =>
          session.serverId == widget.server.id &&
          session.status == SessionStatus.connected,
    );
  }

  void _startRefreshTimer(Duration interval) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      if (!_connected(ref.read(sessionsProvider).asData?.value)) return;
      unawaited(_loadStats());
      // Keep inspect state reasonably fresh without spamming logs.
      unawaited(_loadInspect(silent: true));
    });
  }

  Future<String?> _sudoPassword() async {
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(widget.server);
    return credential.type == CredentialType.password
        ? credential.password
        : null;
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadInspect(), _loadLogs(), _loadStats()]);
  }

  Future<void> _loadInspect({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingInspect = true;
        _inspectError = null;
      });
    }
    try {
      final detail = await ref
          .read(connectionManagerProvider)
          .inspectContainer(
            widget.server.id,
            runtime: widget.runtime,
            scope: widget.scope,
            containerId: widget.containerId,
            sudoPassword: await _sudoPassword(),
          );
      if (!mounted) return;
      setState(() {
        _inspect = detail;
        _inspectError = null;
        _loadingInspect = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (!silent || _inspect == null) _inspectError = error;
        _loadingInspect = false;
      });
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loadingLogs = true;
      _logsError = null;
    });
    try {
      final logs = await ref
          .read(connectionManagerProvider)
          .readContainerLogs(
            widget.server.id,
            runtime: widget.runtime,
            scope: widget.scope,
            containerId: widget.containerId,
            tail: _logTail,
            timestamps: _logTimestamps,
            sudoPassword: await _sudoPassword(),
          );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _logsError = null;
        _loadingLogs = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _logsError = error;
        _loadingLogs = false;
      });
    }
  }

  Future<void> _loadStats() async {
    final running = _inspect?.isRunning ?? true;
    if (!running) {
      if (mounted) setState(() => _stats = null);
      return;
    }
    try {
      final samples = await ref
          .read(connectionManagerProvider)
          .listContainerStats(
            widget.server.id,
            runtime: widget.runtime,
            scope: widget.scope,
            containerIds: [widget.containerId],
            sudoPassword: await _sudoPassword(),
          );
      if (!mounted) return;
      setState(() {
        _stats = samples.isEmpty ? null : samples.first;
        _statsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _statsError = error);
    }
  }

  Future<void> _connect() async {
    final connected = await connectForStatistics(context, ref, widget.server);
    if (connected && mounted) await _bootstrap();
  }

  Future<void> _runAction(ContainerAction action) async {
    if (_actionBusy) return;
    if (action == ContainerAction.stop) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Stop ${widget.containerName}?'),
          content: const Text(
            'The container will remain available to start again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Stop'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(connectionManagerProvider)
          .runContainerAction(
            widget.server.id,
            runtime: widget.runtime,
            scope: widget.scope,
            containerId: widget.containerId,
            action: action,
            sudoPassword: await _sudoPassword(),
          );
      if (!mounted) return;
      showStyledSnackBar(
        title: 'Container ${action.name}ed',
        message: widget.containerName,
        icon: Symbols.check_circle,
        accentColor: Theme.of(context).colorScheme.primary,
      );
      await _bootstrap();
    } catch (error) {
      if (!mounted) return;
      showStyledSnackBar(
        title: 'Could not ${action.name} container',
        message: error.toString(),
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _copy(String value, {required String title}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showStyledSnackBar(
      title: title,
      message: 'Copied to the clipboard.',
      icon: Symbols.content_copy,
      accentColor: Theme.of(context).colorScheme.primary,
    );
  }

  Future<void> _recreateFromInspect() async {
    final inspect = _inspect;
    if (inspect == null || _actionBusy) return;
    final command = inspect.rerunCommand(widget.runtime);
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-create container?'),
        content: Text(
          'This stops and removes ${inspect.name}, then runs:\n\n$command',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-create'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() => _actionBusy = true);
    final sudo = await _sudoPassword();
    final manager = ref.read(connectionManagerProvider);
    final cleanName = inspect.name.startsWith('/')
        ? inspect.name.substring(1)
        : inspect.name;
    try {
      await runWithDeployTerminal(
        ref: ref,
        title: 'Re-create ${inspect.name}',
        subtitle: widget.server.name,
        command: command,
        run: (onOutput) async {
          if (inspect.isRunning) {
            onOutput('Stopping ${inspect.name}…\n');
            await manager.runContainerAction(
              widget.server.id,
              runtime: widget.runtime,
              scope: widget.scope,
              containerId: widget.containerId,
              action: ContainerAction.stop,
              sudoPassword: sudo,
            );
          }
          await manager.removeContainer(
            widget.server.id,
            runtime: widget.runtime,
            scope: widget.scope,
            containerId: widget.containerId,
            force: true,
            sudoPassword: sudo,
            onOutput: onOutput,
          );
          final args = _argumentsFromInspect(inspect);
          await manager.startRawContainer(
            widget.server.id,
            runtime: widget.runtime,
            scope: widget.scope,
            name: cleanName,
            image: inspect.image,
            arguments: args,
            sudoPassword: sudo,
            onOutput: onOutput,
          );
        },
      );
      if (!mounted) return;
      showStyledSnackBar(
        title: 'Container re-created',
        message: cleanName,
        icon: Symbols.check_circle,
        accentColor: Theme.of(context).colorScheme.primary,
      );
      // The old id is gone; pop so the caller can refresh its list.
      if (mounted) context.router.maybePop();
    } catch (error) {
      if (!mounted) return;
      showStyledSnackBar(
        title: 'Could not re-create container',
        message: error.toString(),
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  String _argumentsFromInspect(ContainerInspectDetail inspect) {
    final parts = <String>[];
    if (inspect.restartPolicy.isNotEmpty && inspect.restartPolicy != 'no') {
      parts.add('--restart ${inspect.restartPolicy}');
    }
    if (inspect.networkMode.isNotEmpty &&
        inspect.networkMode != 'default' &&
        inspect.networkMode != 'bridge') {
      parts.add('--network ${_quote(inspect.networkMode)}');
    }
    if (inspect.user != null && inspect.user!.isNotEmpty) {
      parts.add('--user ${_quote(inspect.user!)}');
    }
    if (inspect.workingDir != null && inspect.workingDir!.isNotEmpty) {
      parts.add('-w ${_quote(inspect.workingDir!)}');
    }
    for (final port in inspect.ports) {
      parts.add('-p ${_quote(port)}');
    }
    for (final bind in inspect.binds) {
      parts.add('-v ${_quote(bind)}');
    }
    for (final variable in inspect.env) {
      if (variable.startsWith('PATH=')) continue;
      parts.add('-e ${_quote(variable)}');
    }
    for (final entry in inspect.labels.entries) {
      if (entry.key.startsWith('com.docker.compose.') ||
          entry.key.startsWith('io.podman.compose.')) {
        continue;
      }
      parts.add('--label ${_quote('${entry.key}=${entry.value}')}');
    }
    if (inspect.command.isNotEmpty) {
      // Command must follow the image in `run`; startRawContainer places image
      // last, so append via a trailing arg after image is not supported.
      // Keep command only in the displayed re-run string.
    }
    return parts.join(' ');
  }

  String _quote(String value) {
    if (RegExp(r'^[a-zA-Z0-9_./:@%+=,-]+$').hasMatch(value)) return value;
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    final session = sessions
        .where((item) => item.serverId == widget.server.id)
        .firstOrNull;
    final connected = session?.status == SessionStatus.connected;
    final inspect = _inspect;
    final running = inspect?.isRunning ?? false;
    final title = inspect?.name.isNotEmpty == true
        ? inspect!.name
        : widget.containerName;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: connected && !_actionBusy
                ? () => unawaited(_bootstrap())
                : null,
            icon: const Icon(Symbols.refresh),
          ),
          AppContextMenuButton(
            enabled: connected && !_actionBusy,
            menuBuilder: () => Menu(
              children: [
                MenuAction(
                  title: 'Start',
                  image: MenuImage.icon(Symbols.play_arrow),
                  attributes: MenuActionAttributes(disabled: running),
                  callback: () => unawaited(_runAction(ContainerAction.start)),
                ),
                MenuAction(
                  title: 'Stop',
                  image: MenuImage.icon(Symbols.stop),
                  attributes: MenuActionAttributes(disabled: !running),
                  callback: () => unawaited(_runAction(ContainerAction.stop)),
                ),
                MenuAction(
                  title: 'Restart',
                  image: MenuImage.icon(Symbols.restart_alt),
                  callback: () =>
                      unawaited(_runAction(ContainerAction.restart)),
                ),
                MenuSeparator(),
                MenuAction(
                  title: 'Re-create from inspect',
                  image: MenuImage.icon(Symbols.replay),
                  callback: () => unawaited(_recreateFromInspect()),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !connected && inspect == null
          ? _EmptyBody(
              icon: Symbols.link_off,
              message: session?.error ?? 'Connect to inspect this container.',
              actionLabel: 'Connect',
              onAction: _connect,
            )
          : _DetailWorkspace(
              overview: _OverviewPanel(
                server: widget.server,
                runtime: widget.runtime,
                scope: widget.scope,
                containerId: widget.containerId,
                connected: connected,
                session: session,
                inspect: inspect,
                loading: _loadingInspect && inspect == null,
                error: _inspectError,
                stats: _stats,
                statsError: _statsError,
                onConnect: _connect,
                onRefresh: () => unawaited(_bootstrap()),
              ),
              inspector: _InspectorTabs(
                inspect: inspect,
                inspectError: _inspectError,
                loadingInspect: _loadingInspect,
                logs: _logs,
                logsError: _logsError,
                loadingLogs: _loadingLogs,
                logTail: _logTail,
                logTimestamps: _logTimestamps,
                runtime: widget.runtime,
                onRefreshInspect: () => unawaited(_loadInspect()),
                onRefreshLogs: () => unawaited(_loadLogs()),
                onLogTailChanged: (value) {
                  setState(() => _logTail = value);
                  unawaited(_loadLogs());
                },
                onLogTimestampsChanged: (value) {
                  setState(() => _logTimestamps = value);
                  unawaited(_loadLogs());
                },
                onCopy: _copy,
                onRecreate: inspect == null
                    ? null
                    : () => unawaited(_recreateFromInspect()),
              ),
            ),
    );
  }
}

class _DetailWorkspace extends StatelessWidget {
  const _DetailWorkspace({required this.overview, required this.inspector});

  final Widget overview;
  final Widget inspector;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PanelSurface(padding: const EdgeInsets.all(16), child: overview),
              const SizedBox(height: 16),
              SizedBox(height: 560, child: _PanelSurface(child: inspector)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 360,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _PanelSurface(
                    padding: const EdgeInsets.all(16),
                    child: overview,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _PanelSurface(child: inspector),
              ),
            ),
          ],
        ).padding(horizontal: 24);
      },
    );
  }
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Clip children (e.g. the log terminal) so they respect the rounded panel.
    return ClipRRect(
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: _radius,
        ),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.server,
    required this.runtime,
    required this.scope,
    required this.containerId,
    required this.connected,
    required this.session,
    required this.inspect,
    required this.loading,
    required this.error,
    required this.stats,
    required this.statsError,
    required this.onConnect,
    required this.onRefresh,
  });

  final Server server;
  final ContainerRuntime runtime;
  final ContainerScope scope;
  final String containerId;
  final bool connected;
  final SshSessionInfo? session;
  final ContainerInspectDetail? inspect;
  final bool loading;
  final Object? error;
  final ContainerStats? stats;
  final Object? statsError;
  final Future<void> Function() onConnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Container'),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (inspect == null && error != null)
          Text(
            'Could not inspect: $error',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          )
        else if (inspect == null)
          Text(
            connected
                ? 'No inspect data yet.'
                : (session?.error ?? 'Not connected.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else ...[
          _IdentityBlock(
            name: inspect!.name,
            image: inspect!.image,
            state: inspect!.state,
            status: inspect!.status,
            running: inspect!.isRunning,
          ),
          const SizedBox(height: 16),
          _KeyValue(
            label: 'ID',
            value: inspect!.id.isEmpty ? containerId : inspect!.id,
            mono: true,
          ),
          _KeyValue(label: 'Server', value: server.name),
          _KeyValue(label: 'Runtime', value: runtime.name),
          _KeyValue(
            label: 'Scope',
            value: scope == ContainerScope.root ? 'System (root)' : 'User',
          ),
          if (inspect!.restartPolicy.isNotEmpty)
            _KeyValue(label: 'Restart', value: inspect!.restartPolicy),
          if (inspect!.networkMode.isNotEmpty)
            _KeyValue(label: 'Network', value: inspect!.networkMode),
          if (inspect!.created != null)
            _KeyValue(
              label: 'Created',
              value: _formatTimestamp(inspect!.created!),
            ),
          if (inspect!.startedAt != null)
            _KeyValue(
              label: 'Started',
              value: _formatTimestamp(inspect!.startedAt!),
            ),
          if (inspect!.exitCode != null && !inspect!.isRunning)
            _KeyValue(label: 'Exit code', value: '${inspect!.exitCode}'),
        ],
        if (!connected) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Symbols.link, size: 18),
            label: const Text('Connect'),
          ),
        ] else ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Symbols.refresh, size: 18),
            label: const Text('Refresh'),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionLabel('Resources'),
        const SizedBox(height: 12),
        if (statsError != null)
          Text(
            'Stats unavailable: $statsError',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else if (stats == null)
          Text(
            inspect?.isRunning == true
                ? 'Waiting for a stats sample…'
                : 'Stats are only available while the container is running.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          _StatsGrid(stats: stats!),
      ],
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.running,
  });

  final String name;
  final String image;
  final String state;
  final String status;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          running ? Symbols.play_circle : Symbols.stop_circle,
          color: running ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                image,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: MaidKitFonts.mono,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: running
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.isEmpty ? state : status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: running
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: mono ? MaidKitFonts.mono : null,
                fontSize: mono ? 12 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ContainerStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          label: 'CPU',
          value: stats.cpuPercent == null
              ? '—'
              : '${stats.cpuPercent!.toStringAsFixed(1)}%',
        ),
        _StatChip(
          label: 'Memory',
          value: stats.memUsage.isEmpty ? '—' : stats.memUsage,
        ),
        _StatChip(
          label: 'Network',
          value: stats.netIO.isEmpty ? '—' : stats.netIO,
        ),
        _StatChip(
          label: 'Block I/O',
          value: stats.blockIO.isEmpty ? '—' : stats.blockIO,
        ),
        if (stats.pids != null)
          _StatChip(label: 'PIDs', value: '${stats.pids}'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: MaidKitFonts.mono,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorTabs extends StatelessWidget {
  const _InspectorTabs({
    required this.inspect,
    required this.inspectError,
    required this.loadingInspect,
    required this.logs,
    required this.logsError,
    required this.loadingLogs,
    required this.logTail,
    required this.logTimestamps,
    required this.runtime,
    required this.onRefreshInspect,
    required this.onRefreshLogs,
    required this.onLogTailChanged,
    required this.onLogTimestampsChanged,
    required this.onCopy,
    required this.onRecreate,
  });

  final ContainerInspectDetail? inspect;
  final Object? inspectError;
  final bool loadingInspect;
  final String? logs;
  final Object? logsError;
  final bool loadingLogs;
  final int logTail;
  final bool logTimestamps;
  final ContainerRuntime runtime;
  final VoidCallback onRefreshInspect;
  final VoidCallback onRefreshLogs;
  final ValueChanged<int> onLogTailChanged;
  final ValueChanged<bool> onLogTimestampsChanged;
  final Future<void> Function(String value, {required String title}) onCopy;
  final VoidCallback? onRecreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: scheme.outlineVariant,
            tabs: const [
              Tab(icon: Icon(Symbols.terminal, size: 18), text: 'Logs'),
              Tab(icon: Icon(Symbols.replay, size: 18), text: 'Re-run'),
              Tab(icon: Icon(Symbols.info, size: 18), text: 'Details'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LogsPane(
                  logs: logs,
                  error: logsError,
                  loading: loadingLogs,
                  tail: logTail,
                  timestamps: logTimestamps,
                  onRefresh: onRefreshLogs,
                  onTailChanged: onLogTailChanged,
                  onTimestampsChanged: onLogTimestampsChanged,
                  onCopy: onCopy,
                ),
                _RerunPane(
                  inspect: inspect,
                  runtime: runtime,
                  onCopy: onCopy,
                  onRecreate: onRecreate,
                ),
                _DetailsPane(
                  inspect: inspect,
                  error: inspectError,
                  loading: loadingInspect,
                  onRefresh: onRefreshInspect,
                  onCopy: onCopy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsPane extends StatelessWidget {
  const _LogsPane({
    required this.logs,
    required this.error,
    required this.loading,
    required this.tail,
    required this.timestamps,
    required this.onRefresh,
    required this.onTailChanged,
    required this.onTimestampsChanged,
    required this.onCopy,
  });

  final String? logs;
  final Object? error;
  final bool loading;
  final int tail;
  final bool timestamps;
  final VoidCallback onRefresh;
  final ValueChanged<int> onTailChanged;
  final ValueChanged<bool> onTimestampsChanged;
  final Future<void> Function(String value, {required String title}) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text('Last', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: tail,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 100, child: Text('100 lines')),
                  DropdownMenuItem(value: 300, child: Text('300 lines')),
                  DropdownMenuItem(value: 1000, child: Text('1000 lines')),
                ],
                onChanged: (value) {
                  if (value != null) onTailChanged(value);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Timestamps'),
                selected: timestamps,
                onSelected: onTimestampsChanged,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy logs',
                onPressed: logs == null || logs!.isEmpty
                    ? null
                    : () => onCopy(logs!, title: 'Logs copied'),
                icon: const Icon(Symbols.content_copy),
              ),
              IconButton(
                tooltip: 'Refresh logs',
                onPressed: onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.refresh),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: loading && logs == null
              ? const Center(child: CircularProgressIndicator())
              : error != null && logs == null
              ? _EmptyBody(
                  icon: Symbols.error_outline,
                  message: 'Could not load logs: $error',
                  actionLabel: 'Try again',
                  onAction: () async => onRefresh(),
                )
              : logs == null || logs!.trim().isEmpty
              ? _EmptyBody(
                  icon: Symbols.terminal,
                  message: 'No log output for this container yet.',
                  actionLabel: 'Refresh',
                  onAction: () async => onRefresh(),
                )
              : AnsiLogView(text: logs!),
        ),
      ],
    );
  }
}

class _RerunPane extends StatelessWidget {
  const _RerunPane({
    required this.inspect,
    required this.runtime,
    required this.onCopy,
    required this.onRecreate,
  });

  final ContainerInspectDetail? inspect;
  final ContainerRuntime runtime;
  final Future<void> Function(String value, {required String title}) onCopy;
  final VoidCallback? onRecreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (inspect == null) {
      return const _EmptyBody(
        icon: Symbols.replay,
        message: 'Inspect the container to generate a re-run command.',
      );
    }
    final command = inspect!.rerunCommand(runtime);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Reconstructed from inspect. Ports, env, volumes, restart policy, '
          'network, and labels are included when available. Some advanced '
          'HostConfig flags are omitted.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              command,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: MaidKitFonts.mono,
                height: 1.45,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => onCopy(command, title: 'Command copied'),
              icon: const Icon(Symbols.content_copy, size: 18),
              label: const Text('Copy command'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onRecreate,
              icon: const Icon(Symbols.replay, size: 18),
              label: const Text('Re-create'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Included configuration'),
        const SizedBox(height: 8),
        _SummaryLine(label: 'Image', value: inspect!.image),
        _SummaryLine(
          label: 'Ports',
          value: inspect!.ports.isEmpty ? '—' : inspect!.ports.join(', '),
        ),
        _SummaryLine(
          label: 'Volumes',
          value: inspect!.binds.isEmpty ? '—' : inspect!.binds.join(', '),
        ),
        _SummaryLine(
          label: 'Env vars',
          value: '${inspect!.env.where((e) => !e.startsWith('PATH=')).length}',
        ),
        _SummaryLine(label: 'Restart', value: inspect!.restartPolicy),
        _SummaryLine(label: 'Network', value: inspect!.networkMode),
        if (inspect!.command.isNotEmpty)
          _SummaryLine(label: 'Command', value: inspect!.command.join(' ')),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: MaidKitFonts.mono,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({
    required this.inspect,
    required this.error,
    required this.loading,
    required this.onRefresh,
    required this.onCopy,
  });

  final ContainerInspectDetail? inspect;
  final Object? error;
  final bool loading;
  final VoidCallback onRefresh;
  final Future<void> Function(String value, {required String title}) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (loading && inspect == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (inspect == null) {
      return _EmptyBody(
        icon: Symbols.error_outline,
        message: error == null
            ? 'No inspect details available.'
            : 'Could not inspect: $error',
        actionLabel: 'Try again',
        onAction: () async => onRefresh(),
      );
    }

    String prettyJson;
    try {
      prettyJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(jsonDecode(inspect!.rawJson));
    } catch (_) {
      prettyJson = inspect!.rawJson;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Environment', style: theme.textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: 'Copy JSON',
              onPressed: () => onCopy(prettyJson, title: 'Inspect JSON copied'),
              icon: const Icon(Symbols.content_copy, size: 18),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Symbols.refresh, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (inspect!.env.isEmpty)
          Text(
            'No environment variables.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final item in inspect!.env)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                item,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: MaidKitFonts.mono,
                ),
              ),
            ),
        const SizedBox(height: 20),
        Text('Ports', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (inspect!.ports.isEmpty)
          Text(
            'No published ports.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final port in inspect!.ports)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                port,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: MaidKitFonts.mono,
                ),
              ),
            ),
        const SizedBox(height: 20),
        Text('Mounts', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (inspect!.mounts.isEmpty && inspect!.binds.isEmpty)
          Text(
            'No mounts.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final mount
              in (inspect!.mounts.isNotEmpty
                  ? inspect!.mounts
                  : inspect!.binds))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                mount,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: MaidKitFonts.mono,
                ),
              ),
            ),
        if (inspect!.networks.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Networks', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            inspect!.networks.join(', '),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: MaidKitFonts.mono,
            ),
          ),
        ],
        if (inspect!.labels.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Labels', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final entry in inspect!.labels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                '${entry.key}=${entry.value}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: MaidKitFonts.mono,
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        Text('Raw inspect JSON', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              prettyJson,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: MaidKitFonts.mono,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || parsed.year <= 1) return raw;
  return parsed.toLocal().toString();
}
