import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/shared/presentation/cloud_file_picker.dart';
import 'package:maid_kit/shared/presentation/maidkit_alert.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

/// Ensures the server is connected, then opens the reusable cloud file picker.
///
/// Returns `null` if the user cancels or the connection cannot be established.
Future<List<CloudPickedPath>?> pickRemotePaths(
  BuildContext context,
  WidgetRef ref,
  Server server, {
  String? title,
  String initialPath = '.',
  CloudFilePickerSelection selection = CloudFilePickerSelection.file,
  bool allowMultiple = false,
}) async {
  final manager = ref.read(connectionManagerProvider);
  if (manager.clientFor(server.id) == null) {
    final connected = await connectForStatistics(context, ref, server);
    if (!connected || !context.mounted) return null;
  }
  return showCloudFilePicker(
    context,
    sftp: () => manager.withClient(server.id, (client) => client.sftp()),
    title: title,
    subtitle: server.name,
    initialPath: initialPath,
    selection: selection,
    allowMultiple: allowMultiple,
  );
}

Future<bool> connectForStatistics(
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
        icon: Symbols.link_off,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
    return false;
  }

  return true;
}

Future<bool> openTerminalSession(
  BuildContext context,
  WidgetRef ref,
  Server server, {
  String? initialDirectory,
  String? paneId,
}) async {
  HostKeyPrompt? approvedHostKey;
  final loading = showMaidKitLoadingModal(
    context,
    message: 'Opening terminal on ${server.name}…',
  );
  try {
    final credential = await ref
        .read(serverRepositoryProvider)
        .credentialFor(server);
    await ref
        .read(terminalTabsProvider.notifier)
        .open(
          server,
          credential,
          (prompt) async {
            // A host-key prompt must remain interactive, so release the blocking
            // loading overlay before presenting it.
            loading.dismiss();
            final approved = await _approveHostKey(context, prompt);
            if (approved) approvedHostKey = prompt;
            return approved;
          },
          knownHostKeyFingerprint: server.hostKeyFingerprint,
          initialDirectory: initialDirectory,
          paneId: paneId,
        );
    if (approvedHostKey != null) {
      await ref
          .read(serverRepositoryProvider)
          .rememberHostKey(server.id, approvedHostKey!);
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showStyledSnackBar(
        message: error.toString(),
        title: 'Could not open terminal',
        icon: Symbols.terminal,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
    return false;
  } finally {
    loading.dismiss();
  }
}

Future<bool> _approveHostKey(BuildContext context, HostKeyPrompt prompt) async {
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
                    Symbols.verified_user,
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
                  SelectableText('${prompt.algorithm}\n${prompt.fingerprint}'),
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
