import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

enum TaskProgressStatus { inProgress, completed, failed }

class AppTaskProgress {
  const AppTaskProgress({
    required this.id,
    required this.title,
    required this.totalBytes,
    required this.status,
    required this.progress,
  });

  final String id;
  final String title;
  final int? totalBytes;
  final TaskProgressStatus status;
  final double? progress;

  bool get isActive => status == TaskProgressStatus.inProgress;

  AppTaskProgress copyWith({TaskProgressStatus? status, double? progress}) =>
      AppTaskProgress(
        id: id,
        title: title,
        totalBytes: totalBytes,
        status: status ?? this.status,
        progress: progress ?? this.progress,
      );
}

final taskProgressProvider =
    NotifierProvider<TaskProgressNotifier, List<AppTaskProgress>>(
      TaskProgressNotifier.new,
    );

class TaskProgressNotifier extends Notifier<List<AppTaskProgress>> {
  @override
  List<AppTaskProgress> build() => const [];

  String start({required String title, int? totalBytes}) {
    final id = 'task-${DateTime.now().microsecondsSinceEpoch}';
    state = [
      ...state,
      AppTaskProgress(
        id: id,
        title: title,
        totalBytes: totalBytes,
        status: TaskProgressStatus.inProgress,
        progress: totalBytes == null ? null : 0,
      ),
    ];
    return id;
  }

  void update(String id, int transferredBytes) {
    state = state.map((task) {
      if (task.id != id || task.totalBytes == null) return task;
      return task.copyWith(
        progress: (transferredBytes / task.totalBytes!).clamp(0, 1),
      );
    }).toList();
  }

  void complete(String id) => _finish(id, TaskProgressStatus.completed);

  void fail(String id) => _finish(id, TaskProgressStatus.failed);

  void _finish(String id, TaskProgressStatus status) {
    state = state.map((task) {
      if (task.id != id) return task;
      return task.copyWith(
        status: status,
        progress: status == TaskProgressStatus.completed ? 1 : task.progress,
      );
    }).toList();
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3), () {
        state = state.where((task) => task.id != id).toList();
      }),
    );
  }
}

class TaskProgressBar extends ConsumerWidget {
  const TaskProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProgressProvider);
    final activeTasks = tasks.where((task) => task.isActive).toList();
    final visibleTasks = activeTasks.isEmpty ? tasks : activeTasks;
    final primaryTask = visibleTasks.isEmpty ? null : visibleTasks.last;
    final progress = _progressFor(visibleTasks);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: primaryTask == null ? 0 : 32,
      child: ClipRect(
        child: primaryTask == null
            ? const SizedBox.shrink()
            : _TaskProgressBarContent(task: primaryTask, progress: progress),
      ),
    );
  }
}

class _TaskProgressBarContent extends StatelessWidget {
  const _TaskProgressBarContent({required this.task, required this.progress});

  final AppTaskProgress task;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (task.status) {
      TaskProgressStatus.inProgress => task.title,
      TaskProgressStatus.completed => 'taskProgressComplete'.tr(args: [task.title]),
      TaskProgressStatus.failed => 'taskProgressFailed'.tr(args: [task.title]),
    };
    final color = switch (task.status) {
      TaskProgressStatus.inProgress => colorScheme.primary,
      TaskProgressStatus.completed => colorScheme.primary,
      TaskProgressStatus.failed => colorScheme.error,
    };
    final icon = switch (task.status) {
      TaskProgressStatus.inProgress => Symbols.sync,
      TaskProgressStatus.completed => Symbols.check_circle,
      TaskProgressStatus.failed => Symbols.error,
    };

    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 32,
            color: color,
            backgroundColor: colorScheme.surfaceContainerHigh,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (progress != null)
                  Text(
                    '${(progress! * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double? _progressFor(List<AppTaskProgress> tasks) {
  if (tasks.isEmpty || tasks.any((task) => task.progress == null)) return null;
  return tasks.fold<double>(0, (sum, task) => sum + task.progress!) /
      tasks.length;
}
