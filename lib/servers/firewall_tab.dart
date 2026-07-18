import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'firewall_models.dart';
import 'server_models.dart';
import 'server_providers.dart';

/// Host firewall management (UFW preferred; also firewalld, nftables, iptables).
class FirewallTab extends ConsumerStatefulWidget {
  const FirewallTab({
    super.key,
    required this.server,
    required this.connected,
    required this.connectionError,
    required this.onConnect,
  });

  final Server server;
  final bool connected;
  final String? connectionError;
  final Future<void> Function() onConnect;

  @override
  ConsumerState<FirewallTab> createState() => _FirewallTabState();
}

class _FirewallTabState extends ConsumerState<FirewallTab> {
  AsyncValue<FirewallStatus> _status = const AsyncValue.loading();
  var _busy = false;

  bool get _isRoot => widget.server.username == 'root';

  @override
  void initState() {
    super.initState();
    if (widget.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void didUpdateWidget(FirewallTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected &&
        (!oldWidget.connected || oldWidget.server.id != widget.server.id)) {
      _load();
    }
  }

  Future<String?> _sudoPassword() async {
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(widget.server);
    return credential.type == CredentialType.password
        ? credential.password
        : null;
  }

  Future<void> _load() async {
    if (!mounted || !widget.connected) return;
    setState(() => _status = const AsyncValue.loading());
    try {
      final status = await ref
          .read(connectionManagerProvider)
          .getFirewallStatus(
            widget.server.id,
            sshUserIsRoot: _isRoot,
            sudoPassword: await _sudoPassword(),
          );
      if (mounted) setState(() => _status = AsyncValue.data(status));
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _status = AsyncValue.error(error, stackTrace));
      }
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showStyledSnackBar(message: success, title: 'Firewall');
      await _load();
    } catch (error) {
      if (!mounted) return;
      showStyledSnackBar(
        message: error.toString(),
        title: 'Firewall action failed',
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    final status = _status.asData?.value;
    if (status == null) return;
    if (!status.backend.supportsRuleEditing) {
      showStyledSnackBar(
        message:
            'Enable/disable is only available for UFW and firewalld on this host.',
        title: status.backend.label,
      );
      return;
    }
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: enabled ? 'Enable firewall?' : 'Disable firewall?',
        heightFactor: 0.36,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              enabled
                  ? 'This will turn on ${status.backend.label}. Ensure SSH access is allowed before enabling.'
                  : 'This will turn off ${status.backend.label}. The host will no longer filter traffic with this firewall.',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(enabled ? 'Enable' : 'Disable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    await _run(() async {
      await ref
          .read(connectionManagerProvider)
          .setFirewallEnabled(
            widget.server.id,
            enabled: enabled,
            sshUserIsRoot: _isRoot,
            sudoPassword: await _sudoPassword(),
          );
    }, success: enabled ? 'Firewall enabled.' : 'Firewall disabled.');
  }

  Future<void> _addRule() async {
    final status = _status.asData?.value;
    if (status == null || !status.backend.supportsRuleEditing) return;
    final draft = await _showAddRuleSheet(context);
    if (draft == null || !mounted) return;
    await _run(() async {
      await ref
          .read(connectionManagerProvider)
          .addFirewallRule(
            widget.server.id,
            draft: draft,
            sshUserIsRoot: _isRoot,
            sudoPassword: await _sudoPassword(),
          );
    }, success: 'Rule added.');
  }

  Future<void> _deleteRule(FirewallRule rule) async {
    final status = _status.asData?.value;
    if (status == null || !status.backend.supportsRuleEditing) return;
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'Delete rule?',
        heightFactor: 0.36,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              rule.display,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                fontFamily: 'IBM Plex Mono',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    await _run(() async {
      await ref
          .read(connectionManagerProvider)
          .deleteFirewallRule(
            widget.server.id,
            rule: rule,
            sshUserIsRoot: _isRoot,
            sudoPassword: await _sudoPassword(),
          );
    }, success: 'Rule deleted.');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.connected) {
      return _FirewallEmpty(
        icon: Symbols.link_off,
        message: widget.connectionError ?? 'Connect to manage the firewall.',
        actionLabel: 'Connect',
        onAction: widget.onConnect,
        filled: true,
      );
    }

    return _status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _FirewallEmpty(
        icon: Symbols.error_outline,
        message: 'Could not load firewall status: $error',
        actionLabel: 'Try again',
        onAction: _load,
      ),
      data: (status) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final editable = status.backend.supportsRuleEditing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.shield,
                        size: 20,
                        color: status.active
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.backend.label,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      _ActiveChip(active: status.active),
                      const Spacer(),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (editable)
                        Switch(
                          value: status.active,
                          onChanged: _busy
                              ? null
                              : (value) => _toggleEnabled(value),
                        ),
                      IconButton(
                        tooltip: 'Refresh',
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy ? null : _load,
                        icon: const Icon(Symbols.refresh),
                      ),
                      if (editable)
                        IconButton(
                          tooltip: 'Add rule',
                          visualDensity: VisualDensity.compact,
                          onPressed: _busy || !status.active ? null : _addRule,
                          icon: const Icon(Symbols.add),
                        ),
                    ],
                  ),
                  if (status.defaultIncoming != null ||
                      status.defaultOutgoing != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (status.defaultIncoming != null)
                          'Incoming ${status.defaultIncoming}',
                        if (status.defaultOutgoing != null)
                          'Outgoing ${status.defaultOutgoing}',
                        if (status.zones.isNotEmpty)
                          'Zone ${status.zones.join(', ')}',
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (!editable && status.backend != FirewallBackend.none) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Read-only view. Rule edits are supported for UFW and firewalld.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (status.error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      status.error!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: status.backend == FirewallBackend.none
                  ? _FirewallEmpty(
                      icon: Symbols.shield,
                      message:
                          status.error ??
                          'No supported firewall tool was found on this host.',
                      actionLabel: 'Refresh',
                      onAction: _load,
                    )
                  : status.rules.isEmpty
                  ? _FirewallEmpty(
                      icon: Symbols.shield,
                      message: status.active
                          ? 'No rules reported by ${status.backend.label}.'
                          : '${status.backend.label} is inactive.',
                      actionLabel: editable && status.active
                          ? 'Add rule'
                          : 'Refresh',
                      onAction: editable && status.active ? _addRule : _load,
                    )
                  : ListView.separated(
                      itemCount: status.rules.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) {
                        final rule = status.rules[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Icon(
                            _actionIcon(rule.action),
                            color: _actionColor(scheme, rule.action),
                          ),
                          title: Text(
                            rule.display,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 13,
                            ),
                          ),
                          subtitle: rule.action == null
                              ? null
                              : Text(rule.action!.label),
                          trailing: editable
                              ? IconButton(
                                  tooltip: 'Delete rule',
                                  onPressed: _busy
                                      ? null
                                      : () => _deleteRule(rule),
                                  icon: const Icon(Symbols.delete, size: 20),
                                )
                              : Text(
                                  '#${rule.id}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  IconData _actionIcon(FirewallAction? action) => switch (action) {
    FirewallAction.allow => Symbols.check_circle,
    FirewallAction.deny || FirewallAction.drop => Symbols.block,
    FirewallAction.reject => Symbols.cancel,
    null => Symbols.rule,
  };

  Color _actionColor(ColorScheme scheme, FirewallAction? action) =>
      switch (action) {
        FirewallAction.allow => scheme.primary,
        FirewallAction.deny ||
        FirewallAction.drop ||
        FirewallAction.reject => scheme.error,
        null => scheme.onSurfaceVariant,
      };
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: active ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

Future<FirewallRuleDraft?> _showAddRuleSheet(BuildContext context) {
  return showModalBottomSheet<FirewallRuleDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => const _AddFirewallRuleSheet(),
  );
}

class _AddFirewallRuleSheet extends StatefulWidget {
  const _AddFirewallRuleSheet();

  @override
  State<_AddFirewallRuleSheet> createState() => _AddFirewallRuleSheetState();
}

class _AddFirewallRuleSheetState extends State<_AddFirewallRuleSheet> {
  final _port = TextEditingController();
  final _source = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _action = FirewallAction.allow;
  var _protocol = 'tcp';

  @override
  void dispose() {
    _port.dispose();
    _source.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      FirewallRuleDraft(
        action: _action,
        port: _port.text.trim(),
        protocol: _protocol,
        source: _source.text.trim().isEmpty ? null : _source.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      titleText: 'Add firewall rule',
      heightFactor: 0.68,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            DropdownButtonFormField<FirewallAction>(
              // ignore: deprecated_member_use
              value: _action,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: FirewallAction.allow,
                  child: Text('Allow'),
                ),
                DropdownMenuItem(
                  value: FirewallAction.deny,
                  child: Text('Deny'),
                ),
                DropdownMenuItem(
                  value: FirewallAction.reject,
                  child: Text('Reject'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _action = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _port,
              decoration: const InputDecoration(
                labelText: 'Port or service',
                hintText: '22 or 80:443 or ssh',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Port is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _protocol,
              decoration: const InputDecoration(
                labelText: 'Protocol',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                DropdownMenuItem(value: 'udp', child: Text('UDP')),
                DropdownMenuItem(value: 'any', child: Text('Any')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _protocol = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _source,
              decoration: const InputDecoration(
                labelText: 'Source (optional)',
                hintText: '192.168.1.0/24',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('Add')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FirewallEmpty extends StatelessWidget {
  const _FirewallEmpty({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.filled = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final bool filled;

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
              if (filled)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Symbols.link),
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
