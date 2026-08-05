import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'github_models.dart';

/// Failure notifications for pinned workflow runs.
///
/// The rail badge and in-app banner are always available; OS notifications go
/// through [FlutterLocalNotificationsPlugin] and are best-effort — a missing
/// plugin, denied permission, or unsupported platform silently degrades to
/// the in-app surfaces.
class GitHubNotifications {
  GitHubNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Runs that newly failed since [previous]. Pure so the polling layer and
  /// tests can compute alerts without touching the plugin.
  static List<FailedRunAlert> diff(
    GitHubRunsSnapshot previous,
    GitHubRunsSnapshot next,
  ) {
    final known = <String>{
      for (final repo in previous.repos)
        for (final run in repo.runs.where((run) => run.failed))
          '${repo.owner}/${repo.name}#${run.id}',
    };
    return [
      for (final repo in next.repos)
        for (final run in repo.runs.where((run) => run.failed))
          if (!known.contains('${repo.owner}/${repo.name}#${run.id}'))
            FailedRunAlert(owner: repo.owner, name: repo.name, run: run),
    ];
  }

  /// Fires OS notifications for [alerts]. No-op on web and on platforms the
  /// plugin cannot initialize.
  static Future<void> notify(List<FailedRunAlert> alerts) async {
    if (alerts.isEmpty || kIsWeb) return;
    await _ensureInitialized();
    if (!_initialized) return;
    for (final alert in alerts) {
      try {
        await _plugin.show(
          id: alert.run.id,
          title: 'GitHub Actions failed — ${alert.owner}/${alert.name}',
          body:
              '${alert.run.displayTitle} (run #${alert.run.runNumber}) failed.',
          notificationDetails: const NotificationDetails(
            macOS: DarwinNotificationDetails(),
            linux: LinuxNotificationDetails(),
            android: AndroidNotificationDetails(
              'github_runs',
              'GitHub workflow runs',
              channelDescription: 'Workflow run status',
            ),
          ),
        );
      } catch (_) {
        // Notifications are best-effort; the in-app surfaces still apply.
      }
    }
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
          windows: WindowsInitializationSettings(
            appName: 'MaidKit',
            appUserModelId: 'dev.solsynth.maid.MaidKit',
            guid: 'c1f3d0e4-5b2a-4f8e-9d7c-2a6b3e4f5a01',
          ),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }
}
