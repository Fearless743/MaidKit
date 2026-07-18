import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'server_connection_actions.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

@RoutePage()
class ServersPage extends ConsumerWidget {
  const ServersPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<ServerDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddServerDialog(),
    );
    if (draft == null || !context.mounted) return;
    try {
      final server = await ref.read(serverRepositoryProvider).create(draft);
      if (!context.mounted) return;
      await _connect(context, ref, server);
    } catch (_) {
      if (context.mounted) {
        showStyledSnackBar(
          message: 'Could not save the server.',
          title: 'Server not saved',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    Server server,
  ) async {
    await connectForStatistics(context, ref, server);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Server server) async {
    try {
      final credential = await ref
          .read(serverRepositoryProvider)
          .credentialFor(server);
      if (!context.mounted) return;
      final draft = await showModalBottomSheet<ServerDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _AddServerDialog(
          initial: ServerDraft(
            name: server.name,
            host: server.host,
            port: server.port,
            username: server.username,
            credential: credential,
            collectStats: server.collectStats,
            collectSystemInfo: server.collectSystemInfo,
          ),
        ),
      );
      if (draft != null) {
        await ref.read(serverRepositoryProvider).update(server, draft);
      }
    } catch (error) {
      if (context.mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'Could not edit server',
          icon: Symbols.error_outline,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _delete(WidgetRef ref, Server server) async {
    await ref.read(terminalTabsProvider.notifier).closeForServer(server.id);
    await ref.read(connectionManagerProvider).disconnect(server.id);
    await ref.read(serverRepositoryProvider).delete(server);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: servers.when(
        data: (items) => items.isEmpty
            ? _EmptyServers(onAdd: () => _add(context, ref))
            : _ServerGrid(
                servers: items,
                sessions: sessions,
                onConnect: (server) => _connect(context, ref, server),
                onEdit: (server) => _edit(context, ref, server),
                onDelete: (server) => _delete(ref, server),
                onOpenDetail: (server) =>
                    context.router.root.push(ServerDetailRoute(server: server)),
                onRefresh: (server) => ref
                    .read(connectionManagerProvider)
                    .refreshServerInfo(server),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load servers: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Symbols.add),
        label: const Text('Add server'),
      ),
    );
  }
}

class _ServerGrid extends StatelessWidget {
  const _ServerGrid({
    required this.servers,
    required this.sessions,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenDetail,
    required this.onRefresh,
  });

  final List<Server> servers;
  final List<SshSessionInfo> sessions;
  final ValueChanged<Server> onConnect;
  final ValueChanged<Server> onEdit;
  final ValueChanged<Server> onDelete;
  final ValueChanged<Server> onOpenDetail;
  final ValueChanged<Server> onRefresh;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(24),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 380,
      mainAxisExtent: 268,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
    ),
    itemCount: servers.length,
    itemBuilder: (context, index) {
      final server = servers[index];
      final session = sessions
          .where((item) => item.serverId == server.id)
          .firstOrNull;
      return ContextMenuWidget(
        menuProvider: (_) => Menu(
          children: [
            MenuAction(title: 'Edit server', callback: () => onEdit(server)),
            MenuSeparator(),
            MenuAction(
              title: 'Delete server',
              attributes: const MenuActionAttributes(destructive: true),
              callback: () => onDelete(server),
            ),
          ],
        ),
        child: _ServerCard(
          server: server,
          session: session,
          onConnect: () => onConnect(server),
          onOpenDetail: () => onOpenDetail(server),
          onRefresh: () => onRefresh(server),
        ),
      );
    },
  );
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.session,
    required this.onConnect,
    required this.onOpenDetail,
    required this.onRefresh,
  });

  final Server server;
  final SshSessionInfo? session;
  final VoidCallback onConnect;
  final VoidCallback onOpenDetail;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final connected = session?.status == SessionStatus.connected;
    final connecting = session?.status == SessionStatus.connecting;
    final failed = session?.status == SessionStatus.failed;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  Icon(
                    Symbols.dns,
                    fill: connected ? 1 : 0,
                    size: 22,
                    color: connected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${server.username}@${server.host}:${server.port}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'View server details',
                    visualDensity: VisualDensity.compact,
                    onPressed: onOpenDetail,
                    icon: const Icon(Symbols.open_in_new),
                  ),
                  IconButton(
                    tooltip: 'Refresh statistics',
                    visualDensity: VisualDensity.compact,
                    onPressed: connected ? onRefresh : null,
                    icon: const Icon(Symbols.refresh),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: connected
                    ? _ServerStats(
                        stats: session?.stats,
                        systemInfo: session?.systemInfo,
                        collectStats: server.collectStats,
                        collectSystemInfo: server.collectSystemInfo,
                      )
                    : _DisconnectedStats(
                        connecting: connecting,
                        error: session?.error,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _ConnectionStatus(
                  connected: connected,
                  connecting: connecting,
                  failed: failed,
                ),
                const Spacer(),
                if (!connected && !connecting)
                  FilledButton.tonal(
                    onPressed: onConnect,
                    child: const Text('Connect'),
                  ),
                if (connecting)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ).padding(horizontal: 16),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    required this.connected,
    required this.connecting,
    required this.failed,
  });

  final bool connected;
  final bool connecting;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (label, color) = switch ((connected, connecting, failed)) {
      (true, _, _) => ('Connected', colorScheme.primary),
      (_, true, _) => ('Connecting', colorScheme.tertiary),
      (_, _, true) => ('Failed', colorScheme.error),
      _ => ('Not connected', colorScheme.onSurfaceVariant),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
        ),
      ],
    );
  }
}

class _DisconnectedStats extends StatelessWidget {
  const _DisconnectedStats({required this.connecting, this.error});

  final bool connecting;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message = connecting
        ? 'Establishing SSH session…'
        : (error ?? 'Connect to view load, memory, and uptime.');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Icon(
              connecting ? Symbols.hourglass_top : Symbols.insights,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerStats extends StatelessWidget {
  const _ServerStats({
    required this.stats,
    required this.systemInfo,
    required this.collectStats,
    required this.collectSystemInfo,
  });

  final ServerStats? stats;
  final ServerSystemInfo? systemInfo;
  final bool collectStats;
  final bool collectSystemInfo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!collectStats && !collectSystemInfo) {
      return _StatsMessage(
        icon: Symbols.visibility_off,
        message: 'Information collection is disabled for this server.',
      );
    }
    if (stats == null && systemInfo == null) {
      return _StatsMessage(
        icon: Symbols.sync,
        message: 'Fetching server information…',
      );
    }

    final usedMemoryKb =
        stats?.memoryTotalKb == null || stats?.memoryAvailableKb == null
        ? null
        : stats!.memoryTotalKb! - stats!.memoryAvailableKb!;
    final memoryRatio =
        usedMemoryKb == null ||
            stats?.memoryTotalKb == null ||
            stats!.memoryTotalKb == 0
        ? null
        : (usedMemoryKb / stats!.memoryTotalKb!).clamp(0.0, 1.0);
    final memoryPercent = memoryRatio == null
        ? null
        : (memoryRatio * 100).round();
    final systemLabel = [
      systemInfo?.distribution,
      systemInfo?.kernel,
    ].whereType<String>().join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Load',
                  value: stats!.loadAverage?.toStringAsFixed(2) ?? '—',
                  detail: _loadDetail(stats!.loadAverage),
                  valueColor: _loadColor(stats!.loadAverage, colorScheme),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Memory',
                  value: memoryPercent == null ? '—' : '$memoryPercent%',
                  detail: usedMemoryKb == null || stats!.memoryTotalKb == null
                      ? null
                      : '${_formatBytes(usedMemoryKb * 1024)} / ${_formatBytes(stats!.memoryTotalKb! * 1024)}',
                  progress: memoryRatio,
                  progressColor: _memoryColor(memoryRatio, colorScheme),
                  valueColor: _memoryColor(memoryRatio, colorScheme),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Uptime',
                  value: _formatUptime(stats!.uptime),
                  detail: _uptimeDetail(stats!.uptime),
                ),
              ),
            ],
          )
        else if (collectStats)
          _StatsMessage(
            icon: Symbols.query_stats,
            message: 'Performance statistics are unavailable on this host.',
          ),
        if (systemLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            systemLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ).padding(horizontal: 4),
        ],
        if (stats?.updatedAt != null) ...[
          Text(
            'Updated ${_formatRelative(stats!.updatedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
          ).padding(horizontal: 4),
        ],
      ],
    );
  }

  static String? _loadDetail(double? load) {
    if (load == null) return null;
    if (load < 1) return 'Idle';
    if (load < 2) return 'Normal';
    if (load < 4) return 'Busy';
    return 'High';
  }

  static String? _uptimeDetail(Duration? uptime) {
    if (uptime == null || uptime.inSeconds == 0) return null;
    if (uptime.inDays >= 30) return 'Stable';
    if (uptime.inHours < 1) return 'Recent';
    return null;
  }

  static Color? _loadColor(double? load, ColorScheme scheme) {
    if (load == null) return null;
    if (load >= 4) return scheme.error;
    if (load >= 2) return scheme.tertiary;
    return null;
  }

  static Color? _memoryColor(double? ratio, ColorScheme scheme) {
    if (ratio == null) return null;
    if (ratio >= 0.9) return scheme.error;
    if (ratio >= 0.75) return scheme.tertiary;
    return null;
  }
}

class _StatsMessage extends StatelessWidget {
  const _StatsMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.detail,
    this.progress,
    this.progressColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? detail;
  final double? progress;
  final Color? progressColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final resolvedValueColor = valueColor ?? colorScheme.onSurface;
    final resolvedProgressColor = progressColor ?? colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: resolvedValueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            if (progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  color: resolvedProgressColor,
                ),
              )
            else
              const SizedBox(height: 4),
            const SizedBox(height: 6),
            Text(
              detail ?? ' ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const megabyte = 1024 * 1024;
  const gigabyte = 1024 * megabyte;
  return bytes >= gigabyte
      ? '${(bytes / gigabyte).toStringAsFixed(1)} GB'
      : '${(bytes / megabyte).toStringAsFixed(0)} MB';
}

String _formatUptime(Duration? uptime) {
  if (uptime == null || uptime.inSeconds == 0) return '—';
  final days = uptime.inDays;
  final hours = uptime.inHours.remainder(24);
  final minutes = uptime.inMinutes.remainder(60);
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String _formatRelative(DateTime time) {
  final delta = DateTime.now().difference(time);
  if (delta.inSeconds < 15) return 'just now';
  if (delta.inMinutes < 1) return '${delta.inSeconds}s ago';
  if (delta.inHours < 1) return '${delta.inMinutes}m ago';
  if (delta.inDays < 1) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

class _EmptyServers extends StatelessWidget {
  const _EmptyServers({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.dns,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No servers yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Add an SSH host to start managing it from MaidKit.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Symbols.add),
            label: const Text('Add server'),
          ),
        ],
      ),
    ),
  );
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog({this.initial});

  final ServerDraft? initial;
  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController();
  final _secret = TextEditingController();
  final _passphrase = TextEditingController();
  CredentialType _type = CredentialType.password;
  bool _collectStats = true;
  bool _collectSystemInfo = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _name.text = initial.name;
    _host.text = initial.host;
    _port.text = initial.port.toString();
    _user.text = initial.username;
    _type = initial.credential.type;
    _secret.text =
        initial.credential.password ?? initial.credential.privateKey ?? '';
    _passphrase.text = initial.credential.keyPassphrase ?? '';
    _collectStats = initial.collectStats;
    _collectSystemInfo = initial.collectSystemInfo;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _host,
      _port,
      _user,
      _secret,
      _passphrase,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickKey() async {
    final result = await FilePicker.pickFiles(withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes != null) {
      setState(() => _secret.text = String.fromCharCodes(bytes));
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _validPort(String? value) {
    final port = int.tryParse(value ?? '');
    return port != null && port > 0 && port < 65536 ? null : 'Invalid port';
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final credential = _type == CredentialType.password
        ? ServerCredential.password(_secret.text)
        : ServerCredential.privateKey(
            privateKey: _secret.text,
            keyPassphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          );
    Navigator.pop(
      context,
      ServerDraft(
        name: _name.text,
        host: _host.text,
        port: int.parse(_port.text),
        username: _user.text,
        credential: credential,
        collectStats: _collectStats,
        collectSystemInfo: _collectSystemInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 560,
    child: SheetScaffold(
      titleText: 'Add SSH server',
      heightFactor: 0.78,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _host,
                    decoration: const InputDecoration(
                      labelText: 'Host or IP address',
                    ),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port'),
                    validator: _validPort,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            SegmentedButton<CredentialType>(
              segments: const [
                ButtonSegment(
                  value: CredentialType.password,
                  label: Text('Password'),
                ),
                ButtonSegment(
                  value: CredentialType.privateKey,
                  label: Text('Private key'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
            const SizedBox(height: 12),
            if (_type == CredentialType.password)
              TextFormField(
                controller: _secret,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: _required,
              )
            else ...[
              TextFormField(
                controller: _secret,
                minLines: 4,
                maxLines: 8,
                validator: _required,
                decoration: InputDecoration(
                  labelText: 'Private key',
                  suffixIcon: IconButton(
                    onPressed: _pickKey,
                    icon: const Icon(Symbols.upload_file),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passphrase,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Key passphrase (optional)',
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Collect performance statistics'),
              subtitle: const Text('Load average, memory use, and uptime.'),
              value: _collectStats,
              onChanged: (value) => setState(() => _collectStats = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Discover system information'),
              subtitle: const Text(
                'Distribution, operating system, and kernel.',
              ),
              value: _collectSystemInfo,
              onChanged: (value) => setState(() => _collectSystemInfo = value),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save and connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
