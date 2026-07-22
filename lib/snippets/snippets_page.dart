import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/server_models.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/deploy_terminal.dart';
import 'snippet_repository.dart';

@RoutePage()
class SnippetsPage extends ConsumerWidget {
  const SnippetsPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ScriptSnippet? item,
  ]) async {
    final nameController = TextEditingController(text: item?.name);
    final scriptController = TextEditingController(text: item?.script);
    final formKey = GlobalKey<FormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _SnippetEditor(
          title: item == null ? 'snippetsNew'.tr() : 'snippetsEdit'.tr(),
          formKey: formKey,
          nameController: nameController,
          scriptController: scriptController,
          onSave: () async {
            if (!formKey.currentState!.validate()) return;
            await ref
                .read(snippetRepositoryProvider)
                .save(
                  id: item?.id,
                  name: nameController.text,
                  script: scriptController.text,
                );
            if (context.mounted) Navigator.pop(context, true);
          },
        ),
      ),
    );
    nameController.dispose();
    scriptController.dispose();
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('snippetsSaved'.tr())));
    }
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    ScriptSnippet snippet,
  ) async {
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    final connected = ref.read(sessionsProvider).asData?.value ?? const [];
    final connectedIds = connected
        .where((session) => session.status == SessionStatus.connected)
        .map((session) => session.serverId)
        .toSet();
    final selected = await showModalBottomSheet<List<Server>>(
      context: context,
      useSafeArea: true,
      builder: (context) =>
          _ServerPicker(servers: servers, connectedIds: connectedIds),
    );
    if (selected == null || selected.isEmpty) return;

    try {
      await Future.wait([
        for (final server in selected)
          (() {
            void Function()? terminate;
            var cancelledBeforeStart = false;
            return runWithDeployTerminal(
              ref: ref,
              title: 'snippetsRunning'.tr(args: [snippet.name]),
              subtitle: server.name,
              command: 'sh -s',
              onCancel: () {
                cancelledBeforeStart = true;
                terminate?.call();
              },
              run: (onOutput) => ref
                  .read(connectionManagerProvider)
                  .runScriptSnippet(
                    server.id,
                    script: snippet.script,
                    onOutput: onOutput,
                    onCancelReady: (callback) {
                      terminate = callback;
                      if (cancelledBeforeStart) callback();
                    },
                  ),
            );
          })(),
      ]);
    } catch (_) {
      // The task terminal shows the per-server error and keeps its log.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snippets = ref.watch(scriptSnippetsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: snippets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? _EmptySnippets(onCreate: () => _edit(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      item.script.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: const Icon(Symbols.code),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'snippetsRun'.tr(),
                          onPressed: () => _run(context, ref, item),
                          icon: const Icon(Symbols.play_arrow),
                        ),
                        IconButton(
                          tooltip: 'snippetsEdit'.tr(),
                          onPressed: () => _edit(context, ref, item),
                          icon: const Icon(Symbols.edit),
                        ),
                        IconButton(
                          tooltip: 'commonDelete'.tr(),
                          onPressed: () => ref
                              .read(snippetRepositoryProvider)
                              .delete(item.id),
                          icon: const Icon(Symbols.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'snippets-create-fab',
        onPressed: () => _edit(context, ref),
        icon: const Icon(Symbols.add),
        label: Text('snippetsNew'.tr()),
      ),
    );
  }
}

class _EmptySnippets extends StatelessWidget {
  const _EmptySnippets({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.code, size: 40),
          const SizedBox(height: 16),
          Text(
            'snippetsEmpty'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('snippetsEmptyHint'.tr(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Symbols.add),
            label: Text('snippetsNew'.tr()),
          ),
        ],
      ),
    ),
  );
}

class _SnippetEditor extends StatelessWidget {
  const _SnippetEditor({
    required this.title,
    required this.formKey,
    required this.nameController,
    required this.scriptController,
    required this.onSave,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController scriptController;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(labelText: 'snippetsName'.tr()),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'commonRequired'.tr()
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: scriptController,
            minLines: 10,
            maxLines: 18,
            style: const TextStyle(fontFamily: 'IBM Plex Mono'),
            decoration: InputDecoration(
              labelText: 'snippetsScript'.tr(),
              alignLabelWithHint: true,
              hintText: '#!/bin/sh\necho "Hello from MaidKit"',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'commonRequired'.tr()
                : null,
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => unawaited(onSave()),
              child: Text('commonSave'.tr()),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ServerPicker extends StatefulWidget {
  const _ServerPicker({required this.servers, required this.connectedIds});

  final List<Server> servers;
  final Set<int> connectedIds;

  @override
  State<_ServerPicker> createState() => _ServerPickerState();
}

class _ServerPickerState extends State<_ServerPicker> {
  late final Set<int> _selected = widget.connectedIds.toSet();

  @override
  Widget build(BuildContext context) {
    final connectedServers = widget.servers
        .where((server) => widget.connectedIds.contains(server.id))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'snippetsSelectServers'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('snippetsSelectServersHint'.tr()),
          const SizedBox(height: 12),
          if (connectedServers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('snippetsNoConnectedServers'.tr()),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final server in connectedServers)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(server.id),
                      title: Text(server.name),
                      subtitle: Text(server.host),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(server.id);
                        } else {
                          _selected.remove(server.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      connectedServers
                          .where((server) => _selected.contains(server.id))
                          .toList(),
                    ),
              icon: const Icon(Symbols.play_arrow),
              label: Text('snippetsRun'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
