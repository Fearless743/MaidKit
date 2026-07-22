import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';

import 'package:maid_kit/servers/terminal_command_palette.dart';
import 'task_progress.dart';

final desktopWindowProvider = Provider<bool>(
  (ref) => DesktopWindowFrame.isPlatformDesktop,
);

class MaidKitWindowScaffold extends ConsumerWidget {
  const MaidKitWindowScaffold({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ref.watch(desktopWindowProvider);

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.tab &&
            HardwareKeyboard.instance.isShiftPressed) {
          showTerminalCommandPalette(context, ref);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DesktopWindowFrame(
        isDesktopPlatform: isDesktop,
        title: Text(
          title ?? 'MaidKit',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        // Desktop chrome owns the window edge; mobile must inset for notch /
        // status bar / home indicator so every route respects safe area.
        child: isDesktop
            ? Column(
                children: [
                  Expanded(child: child),
                  const TaskProgressBar(),
                ],
              )
            : _MobileSafeAreaShell(
                child: Column(
                  children: [
                    Expanded(child: child),
                    const TaskProgressBar(),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Applies [MediaQuery.paddingOf] on mobile and zeroes the consumed insets for
/// descendants so nested scaffolds do not double-pad.
///
/// Bottom inset is left in [MediaQuery.padding] so [Scaffold.bottomNavigationBar]
/// still clears the home indicator. Top/left/right are applied here once for
/// every route under the window shell. The inset band is painted with
/// [ColorScheme.surface] so the status bar / notch region matches the app.
class _MobileSafeAreaShell extends StatelessWidget {
  const _MobileSafeAreaShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.only(
          top: padding.top,
          left: padding.left,
          right: padding.right,
        ),
        child: MediaQuery(
          data: media.copyWith(
            padding: padding.copyWith(top: 0, left: 0, right: 0),
          ),
          child: child,
        ),
      ),
    );
  }
}
