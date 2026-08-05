import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'server_providers.dart';

class StartupConnectionBootstrap extends ConsumerStatefulWidget {
  const StartupConnectionBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupConnectionBootstrap> createState() =>
      _StartupConnectionBootstrapState();
}

class _StartupConnectionBootstrapState
    extends ConsumerState<StartupConnectionBootstrap> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(connectOnStartupProvider);
    if (enabled && !_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_connectSavedServers());
      });
    }
    return widget.child;
  }

  Future<void> _connectSavedServers() async {
    final repository = ref.read(serverRepositoryProvider);
    final manager = ref.read(connectionManagerProvider);
    for (final server in await repository.all()) {
      try {
        final credential = await repository.credentialFor(server);
        final proxy = await repository.proxyFor(server);
        await manager.connect(
          server,
          credential,
          (_) async => false,
          knownHostKeyFingerprint: server.hostKeyFingerprint,
          proxy: proxy,
        );
        await repository.markConnected(server.id);
      } catch (_) {
        // The connection manager exposes the failure state to the server grid.
      }
    }
  }
}
