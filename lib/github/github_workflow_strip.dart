import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/routing/app_router.gr.dart';

import 'github_models.dart';
import 'github_providers.dart';
import 'github_ui.dart';

/// Pinned-repo workflow status card for the Servers dashboard: one row per
/// workflow (its latest run) with status, trigger message, timestamp, and
/// outcome. Tapping a row opens the run detail. Hidden until a GitHub account
/// is connected and repos are pinned.
class GithubWorkflowStatusStrip extends ConsumerWidget {
  const GithubWorkflowStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = ref.watch(githubRunsProvider).asData?.value;
    if (snapshot == null || snapshot.repos.isEmpty) {
      return const SizedBox.shrink();
    }
    // One row per pinned repo: its newest run. Older runs of other workflows
    // still count toward the failure badge below.
    final latestByRepo =
        <String, ({String owner, String name, WorkflowRun run})>{};
    for (final repo in snapshot.repos) {
      for (final run in repo.runs) {
        final key = '${repo.owner}/${repo.name}';
        final existing = latestByRepo[key];
        if (existing == null || run.id > existing.run.id) {
          latestByRepo[key] = (owner: repo.owner, name: repo.name, run: run);
        }
      }
    }
    final entries = latestByRepo.values.toList()
      ..sort((a, b) => b.run.id.compareTo(a.run.id));
    if (entries.isEmpty) return const SizedBox.shrink();
    final failing = snapshot.failingRuns.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Row(
                children: [
                  Icon(Symbols.rocket_launch, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'githubRuns'.tr(),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (failing > 0)
                    Text(
                      'githubStatusFailing'.tr(args: ['$failing']),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final entry in entries)
              _WorkflowStatusRow(
                owner: entry.owner,
                name: entry.name,
                run: entry.run,
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowStatusRow extends StatelessWidget {
  const _WorkflowStatusRow({
    required this.owner,
    required this.name,
    required this.run,
  });

  final String owner;
  final String name;
  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (:icon, :color) = githubRunStatusVisual(
      context,
      run.status,
      run.conclusion,
    );
    return InkWell(
      onTap: () => context.router.push(
        GitHubRunDetailRoute(owner: owner, name: name, runId: run.id, run: run),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          run.name.isEmpty ? '$owner/$name' : run.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        [
                          '$owner/$name',
                          if (run.headBranch.isNotEmpty) run.headBranch,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    run.displayTitle.isEmpty
                        ? 'githubNoRuns'.tr()
                        : run.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (run.runNumber > 0)
                  Text('#${run.runNumber}', style: theme.textTheme.labelSmall),
                Text(
                  githubRunDateTime(context, run.updatedAt ?? run.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  githubTimeAgo(context, run.updatedAt ?? run.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Symbols.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
