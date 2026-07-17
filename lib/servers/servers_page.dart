import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:super_context_menu/super_context_menu.dart';

import '../data/local/app_database.dart';
import '../shared/presentation/maidkit_alert.dart';
import 'server_models.dart';
import 'server_providers.dart';

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
          icon: Icons.error_outline,
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
    HostKeyPrompt? approvedHostKey;
    try {
      final credential = await ref
          .read(serverRepositoryProvider)
          .credentialFor(server);
      await ref.read(connectionManagerProvider).connect(server, credential, (
        prompt,
      ) async {
        final approved = await _approveHostKey(context, prompt);
        if (approved) approvedHostKey = prompt;
        return approved;
      }, knownHostKeyFingerprint: server.hostKeyFingerprint);
      await ref.read(serverRepositoryProvider).markConnected(server.id);
      if (approvedHostKey != null) {
        await ref
            .read(serverRepositoryProvider)
            .rememberHostKey(server.id, approvedHostKey!);
      }
    } catch (error) {
      if (context.mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'Could not connect',
          icon: Icons.link_off,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
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
          icon: Icons.error_outline,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _delete(WidgetRef ref, Server server) async {
    await ref.read(connectionManagerProvider).disconnect(server.id);
    await ref.read(serverRepositoryProvider).delete(server);
  }

  Future<bool> _approveHostKey(
    BuildContext context,
    HostKeyPrompt prompt,
  ) async {
    return await showMaidKitOverlayDialog<bool>(
          barrierDismissible: false,
          builder: (context, close) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verify SSH host key',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prompt.replacesExisting
                          ? 'This host key changed. Confirm it only if you expected the server to be rebuilt or reconfigured.'
                          : 'Confirm this fingerprint before sending credentials. MaidKit will remember it for future connections.',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '${prompt.algorithm}\n${prompt.fingerprint}',
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => close(false),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => close(true),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: servers.when(
        data: (items) => items.isEmpty
            ? _EmptyServers(onAdd: () => _add(context, ref))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final server = items[index];
                  return ContextMenuWidget(
                    menuProvider: (_) => Menu(
                      children: [
                        MenuAction(
                          title: 'Edit server',
                          callback: () => _edit(context, ref, server),
                        ),
                        MenuSeparator(),
                        MenuAction(
                          title: 'Delete server',
                          attributes: const MenuActionAttributes(
                            destructive: true,
                          ),
                          callback: () => _delete(ref, server),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: const Icon(Icons.dns_outlined),
                      title: Text(server.name),
                      subtitle: Text(
                        '${server.username}@${server.host}:${server.port}',
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => _connect(context, ref, server),
                        icon: const Icon(Icons.link),
                        label: const Text('Connect'),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load servers: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
      ),
    );
  }
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
            Icons.dns_outlined,
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
            icon: const Icon(Icons.add),
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
    final result = await FilePicker.platform.pickFiles(withData: true);
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
                    icon: const Icon(Icons.upload_file),
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
