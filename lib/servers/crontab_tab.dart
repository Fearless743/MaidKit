import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'crontab_models.dart';
import 'server_providers.dart';

/// Manage the SSH user's personal crontab on a connected server.
class CrontabTab extends ConsumerStatefulWidget {
  const CrontabTab({
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
  ConsumerState<CrontabTab> createState() => _CrontabTabState();
}

class _CrontabTabState extends ConsumerState<CrontabTab> {
  AsyncValue<CrontabDocument> _document = const AsyncValue.loading();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void didUpdateWidget(CrontabTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected &&
        (!oldWidget.connected || oldWidget.server.id != widget.server.id)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted || !widget.connected) return;
    setState(() => _document = const AsyncValue.loading());
    try {
      final document = await ref
          .read(connectionManagerProvider)
          .listCrontab(widget.server.id);
      if (mounted) setState(() => _document = AsyncValue.data(document));
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _document = AsyncValue.error(error, stackTrace));
      }
    }
  }

  Future<void> _persist(
    CrontabDocument document, {
    required String success,
  }) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(connectionManagerProvider)
          .installCrontab(widget.server.id, document);
      if (!mounted) return;
      setState(() {
        _document = AsyncValue.data(document);
        _busy = false;
      });
      showStyledSnackBar(message: success, title: 'Crontab');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStyledSnackBar(
        message: error.toString(),
        title: 'Crontab update failed',
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
  }

  Future<void> _addJob() async {
    final current = _document.asData?.value;
    if (current == null) return;
    final draft = await _showJobDialog(context);
    if (draft == null || !mounted) return;
    final line = CronEntry.formatJob(
      minute: draft.minute,
      hour: draft.hour,
      dayOfMonth: draft.dayOfMonth,
      month: draft.month,
      dayOfWeek: draft.dayOfWeek,
      command: draft.command,
    );
    final job = CronEntry(
      raw: line,
      kind: CronEntryKind.job,
      minute: draft.minute.trim(),
      hour: draft.hour.trim(),
      dayOfMonth: draft.dayOfMonth.trim(),
      month: draft.month.trim(),
      dayOfWeek: draft.dayOfWeek.trim(),
      command: draft.command.trim(),
    );
    await _persist(current.addingJob(job), success: 'Job added.');
  }

  Future<void> _editJob(int jobIndex, CronEntry entry) async {
    final current = _document.asData?.value;
    if (current == null) return;
    final draft = await _showJobDialog(
      context,
      initial: _JobDraft(
        minute: entry.minute ?? '*',
        hour: entry.hour ?? '*',
        dayOfMonth: entry.dayOfMonth ?? '*',
        month: entry.month ?? '*',
        dayOfWeek: entry.dayOfWeek ?? '*',
        command: entry.command ?? '',
      ),
    );
    if (draft == null || !mounted) return;
    final line = CronEntry.formatJob(
      minute: draft.minute,
      hour: draft.hour,
      dayOfMonth: draft.dayOfMonth,
      month: draft.month,
      dayOfWeek: draft.dayOfWeek,
      command: draft.command,
    );
    final job = CronEntry(
      raw: line,
      kind: CronEntryKind.job,
      minute: draft.minute.trim(),
      hour: draft.hour.trim(),
      dayOfMonth: draft.dayOfMonth.trim(),
      month: draft.month.trim(),
      dayOfWeek: draft.dayOfWeek.trim(),
      command: draft.command.trim(),
    );
    await _persist(
      current.replacingJob(jobIndex, job),
      success: 'Job updated.',
    );
  }

  Future<void> _deleteJob(int jobIndex, CronEntry entry) async {
    final current = _document.asData?.value;
    if (current == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove cron job?'),
        content: Text(
          entry.command ?? entry.raw,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await _persist(current.removingJob(jobIndex), success: 'Job removed.');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.connected) {
      return _CrontabEmpty(
        icon: Symbols.link_off,
        message: widget.connectionError ?? 'Connect to manage crontab.',
        actionLabel: 'Connect',
        onAction: widget.onConnect,
        filled: true,
      );
    }

    return _document.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _CrontabEmpty(
        icon: Symbols.error_outline,
        message: 'Could not load crontab: $error',
        actionLabel: 'Try again',
        onAction: _load,
      ),
      data: (document) {
        final jobs = document.jobs;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      jobs.isEmpty
                          ? 'No jobs for ${widget.server.username}'
                          : '${jobs.length} job${jobs.length == 1 ? '' : 's'} · ${widget.server.username}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Symbols.refresh),
                  ),
                  IconButton(
                    tooltip: 'Add job',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : _addJob,
                    icon: const Icon(Symbols.add),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: jobs.isEmpty
                  ? _CrontabEmpty(
                      icon: Symbols.schedule,
                      message: document.exists
                          ? 'This user has a crontab with no scheduled jobs.'
                          : 'No crontab is installed for this user yet.',
                      actionLabel: 'Add job',
                      onAction: _addJob,
                    )
                  : ListView.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Icon(
                            Symbols.schedule,
                            color: scheme.onSurfaceVariant,
                          ),
                          title: Text(
                            job.command ?? job.raw,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            job.scheduleSummary.isEmpty
                                ? job.scheduleLabel
                                : job.scheduleSummary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'IBM Plex Mono',
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: _busy
                                    ? null
                                    : () => _editJob(index, job),
                                icon: const Icon(Symbols.edit, size: 20),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: _busy
                                    ? null
                                    : () => _deleteJob(index, job),
                                icon: const Icon(Symbols.delete, size: 20),
                              ),
                            ],
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
}

class _JobDraft {
  const _JobDraft({
    required this.minute,
    required this.hour,
    required this.dayOfMonth,
    required this.month,
    required this.dayOfWeek,
    required this.command,
  });

  final String minute;
  final String hour;
  final String dayOfMonth;
  final String month;
  final String dayOfWeek;
  final String command;
}

Future<_JobDraft?> _showJobDialog(
  BuildContext context, {
  _JobDraft? initial,
}) async {
  final minute = TextEditingController(text: initial?.minute ?? '0');
  final hour = TextEditingController(text: initial?.hour ?? '*');
  final dayOfMonth = TextEditingController(text: initial?.dayOfMonth ?? '*');
  final month = TextEditingController(text: initial?.month ?? '*');
  final dayOfWeek = TextEditingController(text: initial?.dayOfWeek ?? '*');
  final command = TextEditingController(text: initial?.command ?? '');
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<_JobDraft>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initial == null ? 'Add cron job' : 'Edit cron job'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Schedule (standard five-field cron)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CronField(
                        controller: minute,
                        label: 'Minute',
                        hint: '0-59',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CronField(
                        controller: hour,
                        label: 'Hour',
                        hint: '0-23',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CronField(
                        controller: dayOfMonth,
                        label: 'Day',
                        hint: '1-31',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CronField(
                        controller: month,
                        label: 'Month',
                        hint: '1-12',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CronField(
                        controller: dayOfWeek,
                        label: 'Weekday',
                        hint: '0-7',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: command,
                  decoration: const InputDecoration(
                    labelText: 'Command',
                    hintText: '/usr/bin/example --flag',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Command is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Examples: 0 2 * * * nightly · */15 * * * * every 15 minutes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _JobDraft(
                minute: minute.text,
                hour: hour.text,
                dayOfMonth: dayOfMonth.text,
                month: month.text,
                dayOfWeek: dayOfWeek.text,
                command: command.text,
              ),
            );
          },
          child: Text(initial == null ? 'Add' : 'Save'),
        ),
      ],
    ),
  );

  minute.dispose();
  hour.dispose();
  dayOfMonth.dispose();
  month.dispose();
  dayOfWeek.dispose();
  command.dispose();
  return result;
}

class _CronField extends StatelessWidget {
  const _CronField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      style: const TextStyle(fontFamily: 'IBM Plex Mono'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Required';
        return null;
      },
    );
  }
}

class _CrontabEmpty extends StatelessWidget {
  const _CrontabEmpty({
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
