import 'dart:async';
import 'dart:typed_data';

import 'package:flterm/flterm.dart' as flterm;
import 'package:flutter/material.dart';

import 'terminal_color_scheme.dart';
import 'terminal_session_adapter.dart';

/// Terminal adapter backed by flterm's libghostty-vt renderer.
///
/// flterm owns terminal rendering and interaction while this adapter bridges
/// its controller to MaidKit's SSH transport and terminal-find host.
class GhosttyTerminalSessionAdapterFactory
    implements TerminalSessionAdapterFactory {
  const GhosttyTerminalSessionAdapterFactory({
    required this.cursorAnimationEnabled,
    required this.colorScheme,
  });

  final bool cursorAnimationEnabled;
  final TerminalColorScheme colorScheme;

  @override
  TerminalSessionAdapter create() => GhosttyTerminalSessionAdapter(
    cursorAnimationEnabled: cursorAnimationEnabled,
    colorScheme: colorScheme,
  );
}

class GhosttyTerminalSessionAdapter implements TerminalSessionAdapter {
  GhosttyTerminalSessionAdapter({
    this.cursorAnimationEnabled = true,
    this.colorScheme = TerminalColorSchemes.defaultScheme,
  }) : _controller = flterm.TerminalController(
         config: flterm.TerminalConfig(
           scrollbackLimit: 10 * 1024 * 1024,
           cursorBlink: cursorAnimationEnabled,
         ),
       ) {
    _controller.onOutput = (bytes) {
      if (!_disposed) _outgoingBytes.add(Uint8List.fromList(bytes));
    };
    _controller.onResize = _onResize;
  }

  final bool cursorAnimationEnabled;
  final TerminalColorScheme colorScheme;
  final flterm.TerminalController _controller;
  final flterm.TerminalScrollController _scrollController =
      flterm.TerminalScrollController();
  final _outgoingBytes = StreamController<Uint8List>.broadcast();
  final _resizeEvents = StreamController<TerminalResize>.broadcast();
  final _matches = <_FltermMatch>[];

  var _disposed = false;
  var _lastColumns = 80;
  var _lastRows = 24;

  @override
  Stream<Uint8List> get outgoingBytes => _outgoingBytes.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizeEvents.stream;

  @override
  void write(Uint8List bytes) {
    if (!_disposed) _controller.write(bytes);
  }

  @override
  void sendInput(String text) {
    if (!_disposed && text.isNotEmpty) _controller.sendText(text);
  }

  /// Exposes flterm's key encoder for the adapter integration tests and for
  /// callers that need to send a non-text terminal key programmatically.
  void sendKey(flterm.Key key) {
    if (!_disposed) _controller.sendKey(key);
  }

  void _onResize(int columns, int rows) {
    if (_disposed || (columns == _lastColumns && rows == _lastRows)) return;
    _lastColumns = columns;
    _lastRows = rows;
    _resizeEvents.add(
      TerminalResize(
        columns: columns,
        rows: rows,
        // flterm's public resize callback reports cell dimensions. SSH uses
        // columns/rows for its window change; retain a sensible pixel estimate
        // for the existing transport contract.
        pixelWidth: columns * 8,
        pixelHeight: rows * 18,
      ),
    );
  }

  @override
  Widget buildView({
    bool autofocus = false,
    bool readOnly = false,
    bool showCursor = true,
  }) {
    if (!showCursor) {
      _controller.modeSet(flterm.TerminalMode.cursorVisible(), value: false);
    }

    Widget terminal = flterm.TerminalView(
      controller: _controller,
      scrollController: _scrollController,
      autofocus: autofocus && !readOnly,
      showKeyboard: !readOnly,
      theme: flterm.TerminalTheme(
        palette: flterm.ColorPalette(
          ansiColors: colorScheme.ansiColors,
          background: colorScheme.background,
          foreground: colorScheme.foreground,
        ),
        cursor: flterm.CursorTheme(
          color: flterm.DynamicColor.fixed(colorScheme.cursor),
        ),
        cursorMotionDuration: cursorAnimationEnabled
            ? const Duration(milliseconds: 90)
            : Duration.zero,
        selection: flterm.SelectionTheme(
          background: flterm.DynamicColor.fixed(colorScheme.selection),
        ),
        fontFamily: 'IBM Plex Mono',
      ),
    );
    if (readOnly) terminal = ExcludeFocus(child: terminal);
    return terminal;
  }

  @override
  int find(String query, {bool caseSensitive = false}) {
    findClear();
    if (_disposed || query.isEmpty) return 0;

    final formatter = _controller.createFormatter(
      format: flterm.FormatterFormat.plain,
      unwrap: false,
      trim: false,
    );
    try {
      final needle = caseSensitive ? query : query.toLowerCase();
      final lines = formatter.format().split('\n');
      for (var row = 0; row < lines.length; row++) {
        final line = lines[row];
        final haystack = caseSensitive ? line : line.toLowerCase();
        var from = 0;
        while (true) {
          final start = haystack.indexOf(needle, from);
          if (start < 0) break;
          _matches.add(_FltermMatch(row, start, start + needle.length));
          from = start + 1;
        }
      }
    } finally {
      formatter.dispose();
    }
    if (_matches.isNotEmpty) findJump(0);
    return _matches.length;
  }

  @override
  void findJump(int index) {
    if (_disposed || _matches.isEmpty) return;
    final match = _matches[index.clamp(0, _matches.length - 1)];
    _controller.selectRange(
      start: flterm.Position(row: match.row, col: match.start),
      end: flterm.Position(row: match.row, col: match.end - 1),
    );
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        (match.row * 18.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  @override
  void findClear() {
    _matches.clear();
    if (!_disposed) _controller.clearSelection();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _matches.clear();
    _controller.dispose();
    _scrollController.dispose();
    await _outgoingBytes.close();
    await _resizeEvents.close();
  }
}

class _FltermMatch {
  const _FltermMatch(this.row, this.start, this.end);

  final int row;
  final int start;
  final int end;
}
