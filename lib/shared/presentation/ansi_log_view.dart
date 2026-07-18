import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../servers/server_providers.dart';
import '../../servers/terminal_find_host.dart';
import '../../servers/terminal_session_adapter.dart';

/// Read-only log surface that reuses the user's selected terminal adapter
/// (Ghostty or xterm) so container logs share the same VT parser, colors, and
/// renderer as interactive sessions.
class AnsiLogView extends ConsumerStatefulWidget {
  const AnsiLogView({
    super.key,
    required this.text,

    /// Only bottom corners are rounded by default — the log pane sits under a
    /// tab bar that already provides the top edge of the panel.
    this.borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(12),
    ),
  });

  final String text;
  final BorderRadius borderRadius;

  @override
  ConsumerState<AnsiLogView> createState() => _AnsiLogViewState();
}

class _AnsiLogViewState extends ConsumerState<AnsiLogView> {
  TerminalSessionAdapter? _adapter;
  String? _boundAdapterId;
  String? _loadedText;
  var _writeGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bindAdapter(force: true);
    });
  }

  @override
  void didUpdateWidget(AnsiLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _bindAdapter(force: true);
    }
  }

  @override
  void dispose() {
    unawaited(_adapter?.dispose() ?? Future<void>.value());
    _adapter = null;
    super.dispose();
  }

  void _bindAdapter({bool force = false}) {
    final selectedId = ref.read(selectedTerminalSessionAdapterProvider);
    final factory = ref.read(terminalSessionAdapterFactoryProvider);
    final recreate = force || _adapter == null || _boundAdapterId != selectedId;
    if (!recreate) return;

    final previous = _adapter;
    final adapter = factory.create();
    final generation = ++_writeGeneration;
    _adapter = adapter;
    _boundAdapterId = selectedId;
    _loadedText = widget.text;
    setState(() {});

    // Let the renderer perform its first layout/resize before feeding a bulk
    // log dump. Ghostty sizes the grid in a post-frame callback; writing too
    // early wraps every line at the default 80 columns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _writeGeneration) return;
        if (!identical(_adapter, adapter)) return;
        _writeLogText(adapter, widget.text);
      });
    });

    unawaited(previous?.dispose() ?? Future<void>.value());
  }

  /// VT line discipline treats bare LF as "move down, keep column". Convert
  /// log newlines to CRLF so each line starts at column 0, matching a real PTY.
  void _writeLogText(TerminalSessionAdapter adapter, String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.isEmpty) return;
    final withCrlf = normalized.replaceAll('\n', '\r\n');
    final payload = withCrlf.endsWith('\r\n') ? withCrlf : '$withCrlf\r\n';
    adapter.write(Uint8List.fromList(utf8.encode(payload)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedTerminalSessionAdapterProvider, (
      previous,
      next,
    ) {
      if (previous != next) _bindAdapter(force: true);
    });

    final adapter = _adapter;
    if (adapter == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadedText != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bindAdapter(force: true);
      });
    }

    // Clip bottom corners, expand so the terminal gets a bounded viewport, and
    // enable mouse/trackpad drag devices for nested scrollables (xterm).
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: const Color(0xFF111315),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: true,
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          // Absorb vertical scroll notifications so TabBarView does not steal
          // them when the user scrolls logs.
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => true,
            child: SizedBox.expand(
              child: TerminalFindHost(
                adapter: adapter,
                autofocus: false,
                readOnly: true,
                showCursor: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
