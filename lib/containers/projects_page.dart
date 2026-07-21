import 'dart:convert';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'deployment_project_models.dart';
import 'project_repository.dart';

/// The managed deployment catalog. It deliberately shows only projects stored
/// by MaidKit; remote container discovery belongs in the server workspace.
@RoutePage()
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    var draftName = '';
    final projectName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New deployment project'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project name',
            helperText: 'Add web servers, Compose stacks, and integrations.',
          ),
          onChanged: (value) => draftName = value,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draftName),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (projectName == null || projectName.trim().isEmpty) return;
    await ref.read(projectRepositoryProvider).createProject(name: projectName);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final source = await ref.read(projectRepositoryProvider).exportToml();
      await FilePicker.saveFile(
        dialogTitle: 'Export deployment catalog',
        fileName: 'maidkit-projects.toml',
        type: FileType.custom,
        allowedExtensions: const ['toml'],
        bytes: utf8.encode(source),
      );
    } catch (error) {
      if (context.mounted) {
        showStyledSnackBar(
          message: '$error',
          title: 'Could not export catalog',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['toml'],
      );
      final path = result?.files.singleOrNull?.path;
      if (path == null) return;
      await ref
          .read(projectRepositoryProvider)
          .importToml(await File(path).readAsString());
    } catch (error) {
      if (context.mounted) {
        showStyledSnackBar(
          message: '$error',
          title: 'Could not import catalog',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(deploymentProjectsProvider);
    final resources = ref.watch(deploymentResourcesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load projects: $error')),
        data: (items) {
          final allResources =
              resources.asData?.value ?? const <DeploymentResource>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deployment projects',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} managed project${items.length == 1 ? '' : 's'} · ${allResources.length} resource${allResources.length == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Import or export TOML catalog',
                      onSelected: (value) => value == 'import'
                          ? _import(context, ref)
                          : _export(context, ref),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'import',
                          child: Text('Import TOML catalog'),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: Text('Export TOML catalog'),
                        ),
                      ],
                      icon: const Icon(Symbols.import_export),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Symbols.add, size: 18),
                      label: const Text('New project'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(
                        onCreate: () => _create(context, ref),
                        onImport: () => _import(context, ref),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 360,
                              mainAxisExtent: 150,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _ProjectCard(
                          project: items[index],
                          resources: allResources
                              .where((r) => r.projectId == items[index].id)
                              .toList(),
                          onOpen: () => context.router.push(
                            ProjectDetailRoute(projectId: items[index].id),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.resources,
    required this.onOpen,
  });
  final DeploymentProject project;
  final List<DeploymentResource> resources;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kinds = <String>{
      for (final resource in resources)
        deploymentResourceKindFromId(resource.kind).name,
    };
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.deployed_code, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Symbols.chevron_right),
                ],
              ),
              const Spacer(),
              Text(
                resources.isEmpty
                    ? 'No resources yet'
                    : '${resources.length} resource${resources.length == 1 ? '' : 's'} · ${kinds.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate, required this.onImport});
  final VoidCallback onCreate;
  final VoidCallback onImport;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.deployed_code, size: 40),
          const SizedBox(height: 16),
          Text(
            'No managed projects yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a deployment project, or import a portable TOML catalog.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: onCreate,
                child: const Text('New project'),
              ),
              OutlinedButton(
                onPressed: onImport,
                child: const Text('Import TOML'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
