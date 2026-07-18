import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/theme.dart';

enum DeploySessionStatus { running, succeeded, failed }

class DeploySession {
  const DeploySession({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.command,
    required this.log,
    required this.status,
    required this.modalVisible,
    this.error,
  });

  final String id;
  final String title;
  final String subtitle;
  final String command;
  final String log;
  final DeploySessionStatus status;
  final bool modalVisible;
  final String? error;

  bool get isRunning => status == DeploySessionStatus.running;

  DeploySession copyWith({
    String? log,
    DeploySessionStatus? status,
    bool? modalVisible,
    String? error,
  }) => DeploySession(
    id: id,
    title: title,
    subtitle: subtitle,
    command: command,
    log: log ?? this.log,
    status: status ?? this.status,
    modalVisible: modalVisible ?? this.modalVisible,
    error: error ?? this.error,
  );
}

final deploySessionsProvider =
    NotifierProvider<DeploySessionsNotifier, List<DeploySession>>(
      DeploySessionsNotifier.new,
    );

class DeploySessionsNotifier extends Notifier<List<DeploySession>> {
  @override
  List<DeploySession> build() => const [];

  String start({
    required String title,
    required String subtitle,
    required String command,
  }) {
    final id = 'deploy-${DateTime.now().microsecondsSinceEpoch}';
    state = [
      ...state,
      DeploySession(
        id: id,
        title: title,
        subtitle: subtitle,
        command: command,
        log: '',
        status: DeploySessionStatus.running,
        modalVisible: true,
      ),
    ];
    return id;
  }

  void append(String id, String chunk) {
    if (chunk.isEmpty) return;
    state = [
      for (final session in state)
        if (session.id == id)
          session.copyWith(log: '${session.log}$chunk')
        else
          session,
    ];
  }

  void complete(String id, {required bool success, String? error}) {
    state = [
      for (final session in state)
        if (session.id == id)
          session.copyWith(
            status: success
                ? DeploySessionStatus.succeeded
                : DeploySessionStatus.failed,
            error: error,
          )
        else
          session,
    ];
  }

  void setModalVisible(String id, bool visible) {
    state = [
      for (final session in state)
        if (session.id == id)
          session.copyWith(modalVisible: visible)
        else
          session,
    ];
  }

  void remove(String id) {
    state = state.where((session) => session.id != id).toList();
  }
}

/// Opens (or re-opens) the deploy progress terminal for [sessionId].
void showDeployTerminal(WidgetRef ref, String sessionId) {
  ref.read(deploySessionsProvider.notifier).setModalVisible(sessionId, true);
  unawaited(
    showAttentionModal(
      id: 'deploy-terminal-$sessionId',
      replaceIfExists: true,
      barrierDismissible: false,
      builder: (context, dismiss) =>
          _DeployTerminalModal(sessionId: sessionId, dismiss: dismiss),
    ),
  );
}

/// Starts a deploy session, opens the terminal, and streams [run] output into it.
Future<void> runWithDeployTerminal({
  required WidgetRef ref,
  required String title,
  required String subtitle,
  required String command,
  required Future<void> Function(void Function(String chunk) onOutput) run,
}) async {
  final sessions = ref.read(deploySessionsProvider.notifier);
  final id = sessions.start(title: title, subtitle: subtitle, command: command);
  showDeployTerminal(ref, id);
  try {
    await run((chunk) => sessions.append(id, chunk));
    sessions.complete(id, success: true);
    sessions.append(id, '\nCompleted successfully.\n');
  } catch (error) {
    sessions.append(id, '\n$error\n');
    sessions.complete(id, success: false, error: error.toString());
    rethrow;
  }
}

class _DeployTerminalModal extends ConsumerStatefulWidget {
  const _DeployTerminalModal({required this.sessionId, required this.dismiss});

  final String sessionId;
  final VoidCallback dismiss;

  @override
  ConsumerState<_DeployTerminalModal> createState() =>
      _DeployTerminalModalState();
}

class _DeployTerminalModalState extends ConsumerState<_DeployTerminalModal> {
  final _scroll = ScrollController();
  var _stickToBottom = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _hide() {
    ref
        .read(deploySessionsProvider.notifier)
        .setModalVisible(widget.sessionId, false);
    widget.dismiss();
  }

  void _close() {
    ref.read(deploySessionsProvider.notifier).remove(widget.sessionId);
    widget.dismiss();
  }

  void _scrollToEndIfNeeded() {
    if (!_stickToBottom || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(
      deploySessionsProvider.select((sessions) {
        for (final item in sessions) {
          if (item.id == widget.sessionId) return item;
        }
        return null;
      }),
    );

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.dismiss());
      return const SizedBox.shrink();
    }

    _scrollToEndIfNeeded();

    final statusColor = switch (session.status) {
      DeploySessionStatus.running => scheme.primary,
      DeploySessionStatus.succeeded => scheme.primary,
      DeploySessionStatus.failed => scheme.error,
    };
    final statusLabel = switch (session.status) {
      DeploySessionStatus.running => 'Running',
      DeploySessionStatus.succeeded => 'Succeeded',
      DeploySessionStatus.failed => 'Failed',
    };

    return AttentionModalScaffold(
      titleText: session.title,
      onDismiss: session.isRunning ? _hide : _close,
      maxWidth: 760,
      maxHeightFactor: 0.82,
      actions: [
        if (session.isRunning)
          IconButton(
            tooltip: 'Hide (keeps running)',
            onPressed: _hide,
            icon: const Icon(Symbols.keyboard_arrow_down),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                if (session.isRunning)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: statusColor,
                    ),
                  )
                else
                  Icon(
                    session.status == DeploySessionStatus.succeeded
                        ? Symbols.check_circle
                        : Symbols.error,
                    size: 16,
                    color: statusColor,
                  ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    session.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SelectableText(
              session.command,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: MaidKitFonts.mono,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification &&
                        _scroll.hasClients) {
                      final position = _scroll.position;
                      _stickToBottom =
                          position.pixels >= position.maxScrollExtent - 48;
                    }
                    return false;
                  },
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    children: [
                      SelectableText(
                        session.log.isEmpty
                            ? 'Waiting for remote output…'
                            : session.log,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: MaidKitFonts.mono,
                          height: 1.45,
                          color: session.log.isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    session.isRunning
                        ? 'Hide to keep working; progress stays in the sidebar.'
                        : 'Deployment finished.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (session.isRunning)
                  OutlinedButton.icon(
                    onPressed: _hide,
                    icon: const Icon(Symbols.keyboard_arrow_down, size: 18),
                    label: const Text('Hide'),
                  )
                else
                  FilledButton(onPressed: _close, child: const Text('Done')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact rail control for deploy sessions that are hidden from the modal.
class DeploySessionsRailButton extends ConsumerWidget {
  const DeploySessionsRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(deploySessionsProvider);
    final hidden = sessions.where((session) => !session.modalVisible).toList();
    if (hidden.isEmpty) return const SizedBox.shrink();

    final primary = hidden.last;
    final running = hidden.any((session) => session.isRunning);
    final failed = hidden.any(
      (session) => session.status == DeploySessionStatus.failed,
    );
    final scheme = Theme.of(context).colorScheme;
    final color = failed
        ? scheme.error
        : running
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: running
            ? '${primary.title} (running — click to show)'
            : '${primary.title} (click to show)',
        child: Badge(
          isLabelVisible: hidden.length > 1,
          label: Text('${hidden.length}'),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showDeployTerminal(ref, primary.id),
            child: SizedBox(
              width: 56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Symbols.terminal, color: color),
                      if (running)
                        Positioned(
                          right: 10,
                          bottom: 2,
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    running ? 'Deploy' : 'Log',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
