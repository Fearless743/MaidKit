// ContextMenuSession + SimpleNotifier are not part of the package public API
// but are the same path DesktopContextMenuWidget uses for Flutter fallbacks.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:super_context_menu/src/scaffold/desktop/menu_session.dart';
import 'package:super_context_menu/src/util.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:super_native_extensions/raw_menu.dart' as raw;

/// Shows a [super_context_menu] desktop menu at [globalPosition].
///
/// Prefer wrapping surfaces with [AppContextMenuRegion] for right-click. Use
/// this when a primary-click control must open the same [Menu] model.
Future<void> showAppContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required Menu menu,
}) async {
  if (!context.mounted) return;

  final mq = MediaQuery.of(context);
  final iconTheme = const IconThemeData.fallback().copyWith(
    color: mq.platformBrightness == Brightness.light
        ? const Color(0xFF090909)
        : const Color(0xFFF0F0F0),
  );
  final options = raw.MenuSerializationOptions(
    iconTheme: iconTheme,
    destructiveIconTheme: iconTheme,
    devicePixelRatio: mq.devicePixelRatio,
  );

  final menuContext = await raw.MenuContext.instance();
  final handle = await menuContext.registerMenu(menu, options);
  final pointerUp = SimpleNotifier();
  try {
    if (!context.mounted) return;
    await menuContext.showContextMenu(
      raw.DesktopContextMenuRequest(
        menu: handle,
        position: globalPosition,
        iconTheme: iconTheme,
        writingToolsConfiguration: null,
        fallback: () {
          final completer = Completer<MenuResult>();
          // Flutter overlay path when native menus are unavailable.
          // ignore: use_build_context_synchronously
          ContextMenuSession(
            context: context,
            iconTheme: iconTheme,
            menu: handle.menu,
            menuWidgetBuilder: DefaultDesktopMenuWidgetBuilder(),
            onDone: completer.complete,
            onInitialPointerUp: pointerUp,
            position: globalPosition,
            tapRegionGroupIds: const {},
          );
          // Button-triggered menus are not held open by a pointer down.
          scheduleMicrotask(pointerUp.notify);
          return completer.future;
        },
      ),
    );
  } finally {
    pointerUp.dispose();
    handle.dispose();
  }
}

/// Overflow control that opens a [Menu] on primary click and also supports
/// right-click / control-click via [ContextMenuWidget].
class AppContextMenuButton extends StatelessWidget {
  const AppContextMenuButton({
    super.key,
    required this.menuBuilder,
    this.tooltip = 'Actions',
    this.icon = Symbols.more_vert,
    this.enabled = true,
    this.iconSize,
    this.visualDensity,
  });

  final Menu Function() menuBuilder;
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final double? iconSize;
  final VisualDensity? visualDensity;

  void _showFromButton(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset(box.size.width, box.size.height));
    unawaited(
      showAppContextMenu(
        context: context,
        globalPosition: origin,
        menu: menuBuilder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      visualDensity: visualDensity,
      onPressed: enabled ? () => _showFromButton(context) : null,
      icon: Icon(icon, size: iconSize),
    );
    if (!enabled) return button;
    return ContextMenuWidget(menuProvider: (_) => menuBuilder(), child: button);
  }
}

/// Wraps [child] so right-click / control-click presents [menuBuilder].
class AppContextMenuRegion extends StatelessWidget {
  const AppContextMenuRegion({
    super.key,
    required this.menuBuilder,
    required this.child,
    this.enabled = true,
  });

  final Menu Function() menuBuilder;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ContextMenuWidget(menuProvider: (_) => menuBuilder(), child: child);
  }
}
