import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/shared/presentation/app_scaffold.dart';

import 'github_models.dart';
import 'github_providers.dart';

/// Top-level GitHub tab: account, pinned repositories, workflow runs, pull
/// requests, and releases.
@RoutePage()
class GitHubPage extends ConsumerStatefulWidget {
  const GitHubPage({super.key});

  @override
  ConsumerState<GitHubPage> createState() => _GitHubPageState();
}

class _GitHubPageState extends ConsumerState<GitHubPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(githubRefreshTickProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(githubActiveConnectionProvider);
    final signIn = ref.watch(githubSignInProvider);
    return MaidKitAppScaffold(
      body: connection == null
          ? _SignedOutView(signIn: signIn)
          : _SignedInView(connection: connection),
    );
  }
}

class _SignedOutView extends ConsumerWidget {
  const _SignedOutView({required this.signIn});

  final GitHubSignInState signIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final awaiting = signIn.phase == GitHubSignInPhase.awaitingUser;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Symbols.rocket_launch, size: 48, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'githubSignInTitle'.tr(),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'githubSignInDescription'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'githubTokenLocalHint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (awaiting) ...[
                _DeviceCodeCard(signIn: signIn),
              ] else if (signIn.phase == GitHubSignInPhase.failed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'githubAuthFailed'.tr(args: [signIn.error ?? '']),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!awaiting)
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(githubSignInProvider.notifier).start(),
                  icon: const Icon(Symbols.login),
                  label: Text('githubSignIn'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCodeCard extends ConsumerWidget {
  const _DeviceCodeCard({required this.signIn});

  final GitHubSignInState signIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            'githubDeviceCodeHint'.tr(),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: SelectableText(
                    signIn.userCode ?? '',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'IBM Plex Mono',
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'commonCopy'.tr(),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: signIn.userCode ?? ''),
                    );
                    if (context.mounted) {
                      showSnackBar('commonCopiedToClipboard'.tr());
                    }
                  },
                  icon: const Icon(Symbols.content_copy, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (signIn.verificationUri != null)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(signIn.verificationUri!)),
              icon: const Icon(Symbols.open_in_new, size: 18),
              label: Text('githubOpenBrowser'.tr()),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'githubWaitingForAuthorization'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.read(githubSignInProvider.notifier).cancel(),
            child: Text('githubCancel'.tr()),
          ),
        ],
      ),
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.connection});

  final GitHubConnection connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pinned =
        ref.watch(githubPinnedReposProvider).asData?.value ??
        const <GitHubRepoPin>[];
    final runsSnapshot = ref.watch(githubRunsProvider).asData?.value;
    final hasFailures = ref.watch(githubHasFailuresProvider);
    final pullRequests =
        ref.watch(githubPullRequestsProvider).asData?.value ?? const [];
    final releases =
        ref.watch(githubReleasesProvider).asData?.value ?? const [];
    final loadingRuns =
        ref.watch(githubRunsProvider).isLoading && runsSnapshot == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _AccountHeader(connection: connection),
        if (hasFailures) ...[const SizedBox(height: 12), _FailureBanner()],
        const SizedBox(height: 20),
        _SectionHeader(icon: Symbols.push_pin, title: 'githubPinnedRepos'.tr()),
        const SizedBox(height: 8),
        if (pinned.isEmpty)
          Text(
            'githubNoPinnedRepos'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pin in pinned)
                InputChip(
                  label: Text('${pin.owner}/${pin.name}'),
                  avatar: const Icon(Symbols.inventory_2, size: 18),
                  onDeleted: () =>
                      ref.read(githubRepositoryProvider).unpinRepo(pin),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Symbols.add, size: 18),
            label: Text('githubAddRepo'.tr()),
            onPressed: () => _openRepoPicker(context, ref, pinned),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _SectionHeader(
              icon: Symbols.rocket_launch,
              title: 'githubRuns'.tr(),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'githubRefresh'.tr(),
              onPressed: () =>
                  ref.read(githubRefreshTickProvider.notifier).refresh(),
              icon: const Icon(Symbols.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (loadingRuns)
          const LinearProgressIndicator()
        else if (pinned.isEmpty)
          Text(
            'githubNoPinnedRepos'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else if (runsSnapshot == null || runsSnapshot.repos.isEmpty)
          Text(
            'githubNoRuns'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else ...[
          for (final repo in runsSnapshot.repos) ...[
            _RepoRunsSection(repo: repo),
            const SizedBox(height: 8),
          ],
          if (runsSnapshot.errors.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final error in runsSnapshot.errors)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.warning, size: 16, color: scheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
        const SizedBox(height: 20),
        _SectionHeader(
          icon: Symbols.call_merge,
          title: 'githubPullRequests'.tr(),
        ),
        const SizedBox(height: 8),
        if (pullRequests.isEmpty)
          Text(
            'githubNoPullRequests'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final repo in pullRequests) ...[
            _RepoPrSection(repo: repo),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 20),
        _SectionHeader(icon: Symbols.tag, title: 'githubReleases'.tr()),
        const SizedBox(height: 8),
        if (releases.isEmpty)
          Text(
            'githubNoReleases'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final repo in releases) ...[
            _RepoReleasesSection(repo: repo),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Future<void> _openRepoPicker(
    BuildContext context,
    WidgetRef ref,
    List<GitHubRepoPin> pinned,
  ) async {
    final connection = ref.read(githubActiveConnectionProvider);
    if (connection == null) return;
    final pinnedSlugs = {for (final pin in pinned) '${pin.owner}/${pin.name}'};
    final selected = await showModalBottomSheet<GitHubRepo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RepoPickerSheet(pinnedSlugs: pinnedSlugs),
    );
    if (selected == null) return;
    await ref
        .read(githubRepositoryProvider)
        .pinRepo(
          connection.id,
          GitHubRepoRef(owner: selected.owner, name: selected.name),
        );
    ref.read(githubRefreshTickProvider.notifier).refresh();
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.connection});

  final GitHubConnection connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundImage: connection.avatarUrl.isEmpty
              ? null
              : NetworkImage(connection.avatarUrl),
          child: connection.avatarUrl.isEmpty
              ? const Icon(Symbols.person, size: 20)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (connection.accountName.isNotEmpty &&
                  connection.accountName != connection.accountLogin)
                Text(
                  connection.accountName,
                  style: theme.textTheme.titleMedium,
                ),
              Text(
                connection.accountLogin,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            await ref.read(githubSignInProvider.notifier).signOut();
            showSnackBar('githubSignedOut'.tr());
          },
          icon: const Icon(Symbols.logout, size: 18),
          label: Text('githubSignOut'.tr()),
        ),
      ],
    );
  }
}

class _FailureBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = ref.watch(githubRunsProvider).asData?.value;
    final failing = snapshot?.failingRuns ?? const [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Symbols.error, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'githubFailureBanner'.tr(args: ['${failing.length}']),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _RepoRunsSection extends StatelessWidget {
  const _RepoRunsSection({required this.repo});

  final PinnedRepoRuns repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${repo.owner}/${repo.name}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        if (repo.runs.isEmpty)
          Text(
            'githubNoRuns'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: [
              for (final run in repo.runs) ...[
                _RunTile(owner: repo.owner, name: repo.name, run: run),
                const SizedBox(height: 6),
              ],
            ],
          ),
      ],
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.owner, required this.name, required this.run});

  final String owner;
  final String name;
  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The page background paints a colored DecoratedBox between the scaffold
    // Material and this tile; a transparent Material keeps the ListTile's ink
    // (and the debug assertion about hidden ink) on a real Material ancestor.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        leading: _RunStatusIcon(status: run.status, conclusion: run.conclusion),
        title: Text(
          run.displayTitle.isEmpty ? run.name : run.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (run.headBranch.isNotEmpty) run.headBranch,
            if (run.runNumber > 0) '#${run.runNumber}',
            if (run.actorLogin.isNotEmpty)
              'githubActor'.tr(args: [run.actorLogin]),
            _timeAgo(context, run.updatedAt ?? run.createdAt),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (run.conclusion != null)
              _ConclusionChip(conclusion: run.conclusion!),
            const SizedBox(width: 4),
            const Icon(Symbols.chevron_right, size: 20),
          ],
        ),
        onTap: () => context.router.push(
          GitHubRunDetailRoute(
            owner: owner,
            name: name,
            runId: run.id,
            run: run,
          ),
        ),
      ),
    );
  }
}

class _RepoPrSection extends StatelessWidget {
  const _RepoPrSection({required this.repo});

  final PinnedRepoPullRequests repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (repo.pullRequests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${repo.owner}/${repo.name}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        for (final pr in repo.pullRequests) ...[
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              leading: const Icon(Symbols.call_merge, size: 20),
              title: Text(
                '#${pr.number} ${pr.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  pr.headRef,
                  'githubActor'.tr(args: [pr.authorLogin]),
                  _timeAgo(context, pr.updatedAt),
                  if (pr.draft) 'githubDraft'.tr(),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _PrChecksSummary(
                checks: repo.checks[pr.number] ?? const [],
              ),
              onTap: () => launchUrl(Uri.parse(pr.htmlUrl)),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _PrChecksSummary extends StatelessWidget {
  const _PrChecksSummary({required this.checks});

  final List<CheckRun> checks;

  @override
  Widget build(BuildContext context) {
    if (checks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final failing = checks.where((check) => check.failed).length;
    final inProgress = checks
        .where(
          (check) =>
              check.status == WorkflowRunStatus.queued ||
              check.status == WorkflowRunStatus.inProgress,
        )
        .length;
    final color = failing > 0
        ? theme.colorScheme.error
        : inProgress > 0
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          failing > 0 ? Symbols.error : Symbols.verified_user,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${checks.length}',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _RepoReleasesSection extends StatelessWidget {
  const _RepoReleasesSection({required this.repo});

  final PinnedRepoReleases repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (repo.releases.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${repo.owner}/${repo.name}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        for (final release in repo.releases.take(5)) ...[
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(
              release.prerelease ? Symbols.science : Symbols.tag,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              release.tagName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'IBM Plex Mono',
              ),
            ),
            subtitle: Text(
              [
                if (release.name.isNotEmpty) release.name,
                _timeAgo(context, release.publishedAt),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'githubRunOpen'.tr(),
              onPressed: () => launchUrl(Uri.parse(release.htmlUrl)),
              icon: const Icon(Symbols.open_in_new, size: 18),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _RepoPickerSheet extends ConsumerStatefulWidget {
  const _RepoPickerSheet({required this.pinnedSlugs});

  final Set<String> pinnedSlugs;

  @override
  ConsumerState<_RepoPickerSheet> createState() => _RepoPickerSheetState();
}

class _RepoPickerSheetState extends ConsumerState<_RepoPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repos =
        ref.watch(githubAvailableReposProvider).asData?.value ??
        const <GitHubRepo>[];
    final query = _query.trim().toLowerCase();
    final filtered = repos.where((repo) {
      if (query.isEmpty) return true;
      return repo.slug.toLowerCase().contains(query) ||
          (repo.description?.toLowerCase().contains(query) ?? false);
    }).toList();

    return SizedBox(
      width: 560,
      child: SheetScaffold(
        titleText: 'githubAddRepo'.tr(),
        heightFactor: 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'githubSearchRepos'.tr(),
                  prefixIcon: const Icon(Symbols.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'commonClearSearch'.tr(),
                          icon: const Icon(Symbols.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('githubNoReposFound'.tr()))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final repo = filtered[index];
                        final pinned = widget.pinnedSlugs.contains(repo.slug);
                        return ListTile(
                          leading: Icon(
                            repo.private ? Symbols.lock : Symbols.inventory_2,
                            size: 20,
                          ),
                          title: Text(repo.slug),
                          subtitle: repo.description == null
                              ? null
                              : Text(
                                  repo.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: pinned
                              ? const Icon(Symbols.check_circle, size: 18)
                              : null,
                          enabled: !pinned,
                          onTap: pinned
                              ? null
                              : () => Navigator.pop(context, repo),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunStatusIcon extends StatelessWidget {
  const _RunStatusIcon({required this.status, this.conclusion});

  final WorkflowRunStatus status;
  final WorkflowRunConclusion? conclusion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      WorkflowRunStatus.queued => (
        Symbols.hourglass_top,
        scheme.onSurfaceVariant,
      ),
      WorkflowRunStatus.inProgress => (Symbols.play_arrow, scheme.primary),
      WorkflowRunStatus.completed => (
        conclusion == WorkflowRunConclusion.failure ||
                conclusion == WorkflowRunConclusion.timedOut ||
                conclusion == WorkflowRunConclusion.actionRequired
            ? Symbols.error
            : conclusion == WorkflowRunConclusion.cancelled
            ? Symbols.cancel
            : conclusion == WorkflowRunConclusion.success
            ? Symbols.check_circle
            : Symbols.remove_circle_outline,
        conclusion == WorkflowRunConclusion.failure ||
                conclusion == WorkflowRunConclusion.timedOut ||
                conclusion == WorkflowRunConclusion.actionRequired
            ? scheme.error
            : conclusion == WorkflowRunConclusion.cancelled
            ? scheme.onSurfaceVariant
            : conclusion == WorkflowRunConclusion.success
            ? const Color(0xFF2E7D32)
            : scheme.onSurfaceVariant,
      ),
      WorkflowRunStatus.unknown => (Symbols.help, scheme.onSurfaceVariant),
    };
    return Icon(icon, size: 22, color: color);
  }
}

class _ConclusionChip extends StatelessWidget {
  const _ConclusionChip({required this.conclusion});

  final WorkflowRunConclusion conclusion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, label) = switch (conclusion) {
      WorkflowRunConclusion.success => (
        const Color(0xFF2E7D32),
        Colors.white,
        'githubConclusionSuccess',
      ),
      WorkflowRunConclusion.failure => (
        theme.colorScheme.error,
        theme.colorScheme.onError,
        'githubConclusionFailure',
      ),
      WorkflowRunConclusion.timedOut => (
        const Color(0xFFE65100),
        Colors.white,
        'githubConclusionTimedOut',
      ),
      WorkflowRunConclusion.cancelled => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'githubConclusionCancelled',
      ),
      WorkflowRunConclusion.actionRequired => (
        const Color(0xFF6A1B9A),
        Colors.white,
        'githubConclusionActionRequired',
      ),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'githubConclusionUnknown',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.tr(),
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

String _timeAgo(BuildContext context, DateTime? time) {
  if (time == null) return '';
  final difference = DateTime.now().difference(time);
  if (difference.inMinutes < 1) return 'agentJustNow'.tr();
  if (difference.inHours < 1) {
    return 'agentMinutesAgo'.tr(args: ['${difference.inMinutes}']);
  }
  if (difference.inDays < 1) {
    return 'agentHoursAgo'.tr(args: ['${difference.inHours}']);
  }
  return 'agentDaysAgo'.tr(args: ['${difference.inDays}']);
}
