import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'server_providers.dart';
import 'server_models.dart';

@RoutePage()
class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: sessions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Could not load sessions: $error')),
          data: (items) => items.isEmpty
              ? const Center(
                  child: Text('Active SSH sessions will appear here.'),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = items[index];
                    return ListTile(
                      leading: Icon(
                        session.status == SessionStatus.connected
                            ? Icons.link
                            : Icons.link_off,
                      ),
                      title: Text(session.serverName),
                      subtitle: Text(
                        '${session.status.name} · ${session.connectedAt.toLocal()}${session.error == null ? '' : '\n${session.error}'}',
                      ),
                      isThreeLine: session.error != null,
                      trailing: session.status == SessionStatus.connected
                          ? TextButton(
                              onPressed: () => ref
                                  .read(connectionManagerProvider)
                                  .disconnect(session.serverId),
                              child: const Text('Disconnect'),
                            )
                          : null,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
