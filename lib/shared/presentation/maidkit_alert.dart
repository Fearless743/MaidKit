import 'dart:async';

import 'package:flutter/material.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';

/// An Overlay-based dialog patterned after Island's alert helper. It keeps
/// transient confirmation UI above the desktop window frame and avoids route
/// dialogs for app-level prompts.
Future<T?> showMaidKitOverlayDialog<T>({
  required Widget Function(BuildContext context, void Function(T? result) close)
  builder,
  bool barrierDismissible = true,
}) {
  final overlay = IslandUIFoundation.overlayKey?.currentState;
  if (overlay == null) return Future.value(null);

  final completer = Completer<T?>();
  late final OverlayEntry entry;

  void close(T? result) {
    if (completer.isCompleted) return;
    entry.remove();
    completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: barrierDismissible ? () => close(null) : null,
            child: const ColoredBox(color: Colors.black54),
          ),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            ),
            child: builder(context, close),
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry);
  return completer.future;
}
