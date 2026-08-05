import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:maid_kit/data/local/app_database.dart';

import 'github_models.dart';
import 'github_providers.dart';

/// Shows the deployment workflow linked to a project: the latest run of the
/// chosen GitHub workflow, with a picker to (re)link and an unlink action.
/// Sits on the project detail page.
class GitHubProjectLinkSection extends ConsumerWidget {
  const GitHubProjectLinkSection({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connection = ref.watch(githubActiveConnectionProvider);
    final links =
        ref.watch(githubProjectLinksProvider(projectId)).asData?.value ??
        const [];

    if (connection == null) {
      return Row(
        children: [
          Icon(Symbols.link_off, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'githubNoConnection'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    if (links.isEmpty) {
      return OutlinedButton.icon(
        onPressed: () => _linkWorkflow(context, ref),
        icon: const Icon(Symbols.link, size: 18),
        label: Text('githubLinkWorkflow'.tr()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('githubLinkedWorkflow'.tr(), style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final link in links) ...[
          _LinkedWorkflowCard(link: link),
          const SizedBox(height: 6),
        ],
        TextButton.icon(
          onPressed: () => _linkWorkflow(context, ref),
          icon: const Icon(Symbols.link, size: 16),
          label: Text('githubLinkWorkflow'.tr()),
        ),
      ],
    );
  }

  Future<void> _linkWorkflow(BuildContext context, WidgetRef ref) async {
    final connection = ref.read(githubActiveConnectionProvider);
    if (connection == null) return;
    final draft =
        await showModalBottomSheet<
          ({String owner, String name, String workflowName})
        >(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          useRootNavigator: true,
          builder: (context) => const _LinkWorkflowSheet(),
        );
    if (draft == null) return;
    await ref
        .read(githubRepositoryProvider)
        .linkProjectWorkflow(
          projectId: projectId,
          owner: draft.owner,
          name: draft.name,
          workflowName: draft.workflowName,
        );
    ref.read(githubRefreshTickProvider.notifier).refresh();
  }
}

class _LinkedWorkflowCard extends ConsumerWidget {
  const _LinkedWorkflowCard({required this.link});

  final GitHubProjectWorkflowLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final run = ref.watch(githubLinkedRunProvider(link)).asData?.value;
    final loading = ref.watch(githubLinkedRunProvider(link)).isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${link.owner}/${link.name} · ${link.workflowName}',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (loading)
                  Text(
                    'githubLoadingRun'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else if (run == null)
                  Text(
                    'githubNoRuns'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    [
                      run.displayTitle.isEmpty ? run.name : run.displayTitle,
                      if (run.runNumber > 0) '#${run.runNumber}',
                      run.headBranch,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (run != null && run.htmlUrl.isNotEmpty)
            IconButton(
              tooltip: 'githubRunOpen'.tr(),
              onPressed: () => launchUrl(Uri.parse(run.htmlUrl)),
              icon: const Icon(Symbols.open_in_new, size: 18),
            ),
          IconButton(
            tooltip: 'githubUnlink'.tr(),
            onPressed: () =>
                ref.read(githubRepositoryProvider).unlinkProjectWorkflow(link),
            icon: const Icon(Symbols.link_off, size: 18),
          ),
        ],
      ),
    );
  }
}

class _LinkWorkflowSheet extends ConsumerStatefulWidget {
  const _LinkWorkflowSheet();

  @override
  ConsumerState<_LinkWorkflowSheet> createState() => _LinkWorkflowSheetState();
}

class _LinkWorkflowSheetState extends ConsumerState<_LinkWorkflowSheet> {
  GitHubRepo? _repo;
  String? _workflowName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repos =
        ref.watch(githubAvailableReposProvider).asData?.value ??
        const <GitHubRepo>[];
    final workflows = _repo == null
        ? const <GitHubWorkflow>[]
        : ref
                  .watch(
                    githubWorkflowsProvider(
                      GitHubRepoRef(owner: _repo!.owner, name: _repo!.name),
                    ),
                  )
                  .asData
                  ?.value ??
              const <GitHubWorkflow>[];

    return SizedBox(
      width: 560,
      child: SheetScaffold(
        titleText: 'githubLinkWorkflow'.tr(),
        heightFactor: 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'githubLinkWorkflowHint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text('githubSelectRepo'.tr(), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<GitHubRepo>(
                initialValue: _repo,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final repo in repos)
                    DropdownMenuItem(value: repo, child: Text(repo.slug)),
                ],
                onChanged: (repo) => setState(() {
                  _repo = repo;
                  _workflowName = null;
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'githubSelectWorkflow'.tr(),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _workflowName,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final workflow in workflows)
                    DropdownMenuItem(
                      value: workflow.name,
                      child: Text(
                        workflow.name.isEmpty
                            ? workflow.path
                            : '${workflow.name} (${workflow.path})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (name) => setState(() => _workflowName = name),
              ),
              if (_repo != null && workflows.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'githubNoWorkflows'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('commonCancel'.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _repo == null || _workflowName == null
                        ? null
                        : () => Navigator.pop(context, (
                            owner: _repo!.owner,
                            name: _repo!.name,
                            workflowName: _workflowName!,
                          )),
                    child: Text('commonSave'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
