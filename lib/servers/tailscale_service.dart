import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tailscale/tailscale.dart';

/// Whether the embedded Tailscale runtime is available on this platform.
/// `package:tailscale` is POSIX-only today, so Windows and web are excluded.
bool get tailscaleSupported => Platform.isMacOS || Platform.isLinux;

bool _tailscaleInitialized = false;

/// Configures the embedded Tailscale node exactly once per process.
///
/// The state directory holds the node's WireGuard private key and must stay
/// out of cloud backups. The application-support directory is not synced by
/// iCloud on macOS and is the location recommended by the package.
Future<void> ensureTailscaleInitialized() async {
  if (_tailscaleInitialized) return;
  if (!tailscaleSupported) {
    throw const TailscaleUsageException(
      'Tailscale is not supported on this platform.',
    );
  }
  final support = await getApplicationSupportDirectory();
  Tailscale.init(stateDir: p.join(support.path, 'tailscale'));
  _tailscaleInitialized = true;
}

/// The singleton embedded node, typed as [TailscaleClient] so tests can
/// substitute a fake without loading the native runtime.
final tailscaleClientProvider = Provider<TailscaleClient>((ref) {
  return Tailscale.instance;
});

/// Thin wrapper that ensures the runtime is initialized before each call.
class TailscaleService {
  TailscaleService(this._client);

  final TailscaleClient _client;

  /// Hostname this app's node uses on the tailnet.
  static const hostname = 'MaidKit';

  /// Brings the node up. [authKey] is required on first registration; later
  /// launches reconnect from persisted credentials without it.
  Future<TailscaleStatus> up({String? authKey}) async {
    await ensureTailscaleInitialized();
    return _client.up(hostname: hostname, authKey: authKey);
  }

  Future<TailscaleStatus> status() async {
    await ensureTailscaleInitialized();
    return _client.status();
  }

  Future<List<TailscaleNode>> nodes() async {
    await ensureTailscaleInitialized();
    return _client.nodes();
  }

  Future<void> logout() async {
    await ensureTailscaleInitialized();
    await _client.logout();
  }

  Stream<NodeState> get onStateChange => _client.onStateChange;
  Stream<TailscaleRuntimeError> get onError => _client.onError;
}

final tailscaleServiceProvider = Provider<TailscaleService>((ref) {
  return TailscaleService(ref.watch(tailscaleClientProvider));
});
