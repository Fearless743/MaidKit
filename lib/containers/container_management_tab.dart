import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'container_models.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/servers/server_models.dart';
import 'package:maid_kit/servers/server_providers.dart';

/// A reusable container-management surface for a single server. Its data is
/// scoped by runtime (Docker/Podman) and by user/root environment so it can be
/// reused by a future multi-server overview without depending on a route page.
class ContainerManagementTab extends ConsumerStatefulWidget {
  const ContainerManagementTab({
    super.key,
    required this.server,
    required this.connected,
    required this.connectionError,
    required this.onConnect,
    required this.refreshInterval,
  });

  final Server server;
  final bool connected;
  final String? connectionError;
  final Future<void> Function() onConnect;
  final Duration refreshInterval;

  @override
  ConsumerState<ContainerManagementTab> createState() =>
      _ContainerManagementTabState();
}

class _ContainerManagementTabState
    extends ConsumerState<ContainerManagementTab> {
  AsyncValue<List<ContainerEnvironment>> _environments = const AsyncValue.data(
    [],
  );
  Timer? _refreshTimer;
  var _loading = false;
  var _hasLoadedEnvironments = false;

  @override
  void initState() {
    super.initState();
    if (widget.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ContainerManagementTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected &&
        (!oldWidget.connected || oldWidget.server.id != widget.server.id)) {
      _load();
    }
    if (oldWidget.refreshInterval != widget.refreshInterval) {
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || !widget.connected || _loading) return;
    _loading = true;
    if (!_hasLoadedEnvironments) {
      setState(() => _environments = const AsyncValue.loading());
    }
    try {
      final environments = await ref
          .read(connectionManagerProvider)
          .listContainers(
            widget.server.id,
            sshUserIsRoot: widget.server.username == 'root',
            sudoPassword: await _storedSudoPassword(),
          );
      if (mounted) {
        setState(() {
          _hasLoadedEnvironments = true;
          _environments = AsyncValue.data(environments);
        });
      }
    } catch (error, stackTrace) {
      if (mounted && !_hasLoadedEnvironments) {
        setState(() => _environments = AsyncValue.error(error, stackTrace));
      }
    } finally {
      _loading = false;
    }
  }

  /// The SSH password is supplied to sudo only through SSH stdin. Private-key
  /// connections intentionally keep using non-interactive passwordless sudo.
  Future<String?> _storedSudoPassword() async {
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(widget.server);
    return credential.type == CredentialType.password
        ? credential.password
        : null;
  }

  Future<void> _runAction(
    ContainerEnvironment environment,
    ServerContainer container,
    ContainerAction action,
  ) async {
    if (action == ContainerAction.stop) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Stop ${container.name}?'),
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
    try {
      await ref
          .read(connectionManagerProvider)
          .runContainerAction(
            widget.server.id,
            runtime: environment.runtime,
            scope: environment.scope,
            containerId: container.id,
            action: action,
            sudoPassword: await _storedSudoPassword(),
          );
      if (!mounted) return;
      showStyledSnackBar(
        title: 'Container ${action.name}ed',
        message: container.name,
        icon: Symbols.check_circle,
        accentColor: Theme.of(context).colorScheme.primary,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showStyledSnackBar(
        title: 'Could not ${action.name} container',
        message: error.toString(),
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.connected) {
      return _ContainerEmptyPanel(
        icon: Symbols.link_off,
        message: widget.connectionError ?? 'Connect to manage containers.',
        actionLabel: 'Connect',
        onAction: widget.onConnect,
        filledAction: true,
        actionIcon: Symbols.link,
      );
    }
    return _environments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ContainerEmptyPanel(
        icon: Symbols.error_outline,
        message: 'Could not retrieve containers: $error',
        actionLabel: 'Try again',
        onAction: _load,
      ),
      data: (environments) => _ContainerEnvironments(
        server: widget.server,
        environments: environments,
        onRefresh: _load,
        onAction: _runAction,
      ),
    );
  }
}

class _ContainerEnvironments extends StatelessWidget {
  const _ContainerEnvironments({
    required this.server,
    required this.environments,
    required this.onRefresh,
    required this.onAction,
  });

  final Server server;
  final List<ContainerEnvironment> environments;
  final Future<void> Function() onRefresh;
  final Future<void> Function(
    ContainerEnvironment,
    ServerContainer,
    ContainerAction,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (environments.isEmpty) {
      return _ContainerEmptyPanel(
        icon: Symbols.deployed_code,
        message: 'Docker and Podman are not installed for this server user.',
        actionLabel: 'Refresh',
        onAction: onRefresh,
      );
    }

    final totalContainers = environments
        .where((env) => env.isAvailable)
        .fold<int>(0, (sum, env) => sum + env.containers.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text(
                totalContainers == 1
                    ? '1 container'
                    : '$totalContainers containers',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh containers',
                visualDensity: VisualDensity.compact,
                onPressed: onRefresh,
                icon: const Icon(Symbols.refresh),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: environments.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == environments.length - 1 ? 0 : 16,
              ),
              child: _ContainerEnvironmentSection(
                server: server,
                environment: environments[index],
                onAction: onAction,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContainerEnvironmentSection extends StatelessWidget {
  const _ContainerEnvironmentSection({
    required this.server,
    required this.environment,
    required this.onAction,
  });

  final Server server;
  final ContainerEnvironment environment;
  final Future<void> Function(
    ContainerEnvironment,
    ServerContainer,
    ContainerAction,
  )
  onAction;

  String get _runtimeLabel {
    final name = environment.runtime.name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  String get _scopeLabel =>
      environment.scope == ContainerScope.root ? 'Root' : 'User';

  IconData get _runtimeIcon => switch (environment.runtime) {
    ContainerRuntime.docker => Symbols.deployed_code,
    ContainerRuntime.podman => Symbols.package_2,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(_runtimeIcon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_runtimeLabel, style: theme.textTheme.titleSmall),
                ),
                _MetaChip(label: _scopeLabel),
                if (environment.isAvailable) ...[
                  const SizedBox(width: 8),
                  _MetaChip(
                    label: environment.containers.isEmpty
                        ? 'Empty'
                        : '${environment.containers.length}',
                  ),
                ],
              ],
            ),
          ),
          if (!environment.isAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.info, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      environment.error ?? 'Unavailable',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (environment.containers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'No containers in this environment.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Divider(height: 1, color: scheme.outlineVariant),
            for (var i = 0; i < environment.containers.length; i++) ...[
              _ContainerRow(
                container: environment.containers[i],
                onOpen: () => context.router.push(
                  ContainerDetailRoute(
                    server: server,
                    runtime: environment.runtime,
                    scope: environment.scope,
                    containerId: environment.containers[i].id,
                    containerName: environment.containers[i].name,
                  ),
                ),
                onAction: (action) =>
                    onAction(environment, environment.containers[i], action),
              ),
              if (i != environment.containers.length - 1)
                Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ContainerRow extends StatelessWidget {
  const _ContainerRow({
    required this.container,
    required this.onOpen,
    required this.onAction,
  });

  final ServerContainer container;
  final VoidCallback onOpen;
  final Future<void> Function(ContainerAction action) onAction;

  bool get _isRunning {
    final state = container.state.toLowerCase();
    return state.contains('running') || state == 'up';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isRunning ? scheme.primary : scheme.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    container.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    container.image,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    container.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StateChip(state: container.state, running: _isRunning),
            PopupMenuButton<ContainerAction>(
              tooltip: 'Container actions',
              onSelected: onAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: ContainerAction.start,
                  enabled: !_isRunning,
                  child: const Row(
                    children: [
                      Icon(Symbols.play_arrow, size: 20),
                      SizedBox(width: 12),
                      Text('Start'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: ContainerAction.stop,
                  enabled: _isRunning,
                  child: const Row(
                    children: [
                      Icon(Symbols.stop, size: 20),
                      SizedBox(width: 12),
                      Text('Stop'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: ContainerAction.restart,
                  child: Row(
                    children: [
                      Icon(Symbols.restart_alt, size: 20),
                      SizedBox(width: 12),
                      Text('Restart'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Symbols.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state, required this.running});

  final String state;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = state.isEmpty ? 'unknown' : state;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: running
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: running
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ContainerEmptyPanel extends StatelessWidget {
  const _ContainerEmptyPanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.filledAction = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final IconData? actionIcon;
  final bool filledAction;

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
              if (filledAction)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Symbols.refresh),
                  label: Text(actionLabel!),
                )
              else
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
