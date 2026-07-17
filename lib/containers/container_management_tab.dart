import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'container_models.dart';
import '../data/local/app_database.dart';
import '../servers/server_models.dart';
import '../servers/server_providers.dart';

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
      return _ContainerConnectionPrompt(
        message: widget.connectionError ?? 'Connect to manage containers.',
        onConnect: widget.onConnect,
      );
    }
    return _environments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ContainerEmptyState(
        message: 'Could not retrieve containers: $error',
        actionLabel: 'Try again',
        onAction: _load,
      ),
      data: (environments) => _ContainerEnvironments(
        environments: environments,
        onRefresh: _load,
        onAction: _runAction,
      ),
    );
  }
}

class _ContainerEnvironments extends StatelessWidget {
  const _ContainerEnvironments({
    required this.environments,
    required this.onRefresh,
    required this.onAction,
  });

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
    if (environments.isEmpty) {
      return _ContainerEmptyState(
        message: 'Docker and Podman are not installed for this server user.',
        actionLabel: 'Refresh',
        onAction: onRefresh,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Refresh containers',
            onPressed: onRefresh,
            icon: const Icon(Symbols.refresh),
          ),
        ),
        for (final environment in environments) ...[
          _ContainerEnvironmentSection(
            environment: environment,
            onAction: onAction,
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ContainerEnvironmentSection extends StatelessWidget {
  const _ContainerEnvironmentSection({
    required this.environment,
    required this.onAction,
  });

  final ContainerEnvironment environment;
  final Future<void> Function(
    ContainerEnvironment,
    ServerContainer,
    ContainerAction,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    final title =
        '${environment.runtime.name[0].toUpperCase()}${environment.runtime.name.substring(1)} · ${environment.scope == ContainerScope.root ? 'Root' : 'User'}';
    if (!environment.isAvailable) {
      return _ContainerUnavailable(title: title, message: environment.error!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (environment.containers.isEmpty)
          Text(
            'No containers found.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Image')),
                DataColumn(label: Text('State')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final container in environment.containers)
                  DataRow(
                    cells: [
                      DataCell(Text(container.name)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            container.image,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(container.state)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Text(
                            container.status,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        _ContainerActions(
                          container: container,
                          onAction: (action) =>
                              onAction(environment, container, action),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ContainerActions extends StatelessWidget {
  const _ContainerActions({required this.container, required this.onAction});

  final ServerContainer container;
  final Future<void> Function(ContainerAction action) onAction;

  @override
  Widget build(BuildContext context) => PopupMenuButton<ContainerAction>(
    tooltip: 'Container actions',
    onSelected: onAction,
    itemBuilder: (context) => const [
      PopupMenuItem(value: ContainerAction.start, child: Text('Start')),
      PopupMenuItem(value: ContainerAction.stop, child: Text('Stop')),
      PopupMenuItem(value: ContainerAction.restart, child: Text('Restart')),
    ],
    icon: const Icon(Symbols.more_vert),
  );
}

class _ContainerUnavailable extends StatelessWidget {
  const _ContainerUnavailable({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Text(
        'Unavailable: $message',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

class _ContainerConnectionPrompt extends StatelessWidget {
  const _ContainerConnectionPrompt({
    required this.message,
    required this.onConnect,
  });

  final String message;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) => _ContainerEmptyState(
    message: message,
    actionLabel: 'Connect',
    onAction: onConnect,
  );
}

class _ContainerEmptyState extends StatelessWidget {
  const _ContainerEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
