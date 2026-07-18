import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/shared/presentation/deploy_terminal.dart';
import 'container_models.dart';

/// Runs a [ComposeProjectAction] in the shared attention-modal task terminal
/// (same UX as standalone `docker run` / deploy compose).
///
/// Call sites only supply project identity and credentials; streaming logs,
/// hide/show, and success/failure chrome come from [runWithDeployTerminal].
Future<void> runComposeProjectActionWithTerminal({
  required WidgetRef ref,
  required int serverId,
  required String serverName,
  required ContainerRuntime runtime,
  required ContainerScope scope,
  required String projectName,
  required String directory,
  required ComposeProjectAction action,
  String? sudoPassword,
}) {
  final command =
      '${runtime.name} compose -p $projectName ${action.composeArgs}'
      '  ($directory)';
  return runWithDeployTerminal(
    ref: ref,
    title: '${action.progressLabel} $projectName',
    subtitle: serverName,
    command: command,
    run: (onOutput) => ref
        .read(connectionManagerProvider)
        .runComposeProjectAction(
          serverId,
          runtime: runtime,
          scope: scope,
          projectName: projectName,
          directory: directory,
          action: action,
          sudoPassword: sudoPassword,
          onOutput: onOutput,
        ),
  );
}
