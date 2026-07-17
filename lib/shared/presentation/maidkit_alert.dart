import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

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

/// An Island command-palette-shaped overlay for searchable app actions.
Future<T?> showMaidKitCommandPalette<T>({
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
    builder: (context) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: barrierDismissible ? () => close(null) : null,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.sizeOf(context).height * 0.2,
              ),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                tween: Tween(begin: 0.8, end: 1),
                builder: (context, scale, child) => Opacity(
                  opacity: ((scale - 0.8) / 0.2).clamp(0, 1),
                  child: Transform.scale(scale: scale, child: child),
                ),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: math.max(
                      MediaQuery.sizeOf(context).width * 0.6,
                      320,
                    ),
                    constraints: const BoxConstraints(
                      maxWidth: 600,
                      maxHeight: 500,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      child: builder(context, close),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  return completer.future;
}
