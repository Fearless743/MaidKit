import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// File name used for an optional user-provided workspace background image.
///
/// Keeping it in the application-support directory follows Island's approach
/// and avoids making a large image part of the app bundle.
const kMaidKitBackgroundImagePath = 'maidkit_app_background';

final maidKitBackgroundImageProvider = FutureProvider<File?>((ref) async {
  if (kIsWeb) return null;

  final directory = await getApplicationSupportDirectory();
  final file = File('${directory.path}/$kMaidKitBackgroundImagePath');
  return file.existsSync() ? file : null;
});

/// Paints the normal app surface, optionally softened by a user background.
///
/// The layer belongs inside a page scaffold rather than the root window shell,
/// so a route's safe-area and back-swipe transitions remain self-contained.
class MaidKitAppBackground extends ConsumerWidget {
  const MaidKitAppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(maidKitBackgroundImageProvider).asData?.value;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        image: image == null
            ? null
            : DecorationImage(
                image: FileImage(image),
                fit: BoxFit.cover,
                opacity: 0.08,
                colorFilter: ColorFilter.mode(
                  scheme.surface.withValues(alpha: 0.72),
                  BlendMode.srcOver,
                ),
              ),
      ),
      child: child,
    );
  }
}

/// Standard page foundation for MaidKit routes.
///
/// Unlike the former window-level safe-area shell, this keeps MediaQuery
/// insets intact until the page that owns the content decides to consume them.
/// The scaffold always paints an opaque Material surface, which keeps iOS
/// gesture-back transitions from revealing a transparent route underneath.
class MaidKitAppScaffold extends StatelessWidget {
  const MaidKitAppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.endDrawer,
    this.extendBody = false,
    this.useSafeArea = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool extendBody;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final bodyContent = body == null
        ? const SizedBox.shrink()
        : MaidKitAppBackground(
            child: useSafeArea
                ? SafeArea(
                    top: appBar == null,
                    bottom: bottomNavigationBar == null,
                    child: body!,
                  )
                : body!,
          );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appBar,
      body: bodyContent,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      drawer: drawer,
      endDrawer: endDrawer,
      extendBody: extendBody,
    );
  }
}
