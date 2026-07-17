import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/local/app_database.dart';
import 'server_providers.dart';

@RoutePage()
class ServersPage extends ConsumerWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _ServersView(servers: servers),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
      ),
    );
  }
}

class _ServersView extends StatelessWidget {
  const _ServersView({required this.servers});

  final AsyncValue<List<Server>> servers;

  @override
  Widget build(BuildContext context) {
    return servers.when(
      data: (items) => items.isEmpty
          ? const _EmptyServers()
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(items[index].name),
                subtitle: Text(items[index].host),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Could not load servers: $error')),
    );
  }
}

class _EmptyServers extends StatelessWidget {
  const _EmptyServers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No servers yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Add an SSH host to start managing it from MaidKit.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add server'),
            ),
          ],
        ),
      ),
    );
  }
}
