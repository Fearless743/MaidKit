import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'package:maid_kit/theme.dart';

/// A terminal emulator instance attached to one remote shell.
///
/// The adapter owns emulator-specific state and rendering. SSH transport code
/// only needs to forward byte streams and react to input and resize events.
abstract interface class TerminalSessionAdapter {
  /// Bytes produced by keyboard, paste, or mouse input in the terminal.
  Stream<Uint8List> get outgoingBytes;

  /// Terminal size changes requested by the renderer.
  Stream<TerminalResize> get resizeEvents;

  /// Displays bytes received from the remote shell.
  void write(Uint8List bytes);

  /// Builds this adapter's terminal renderer.
  ///
  /// [readOnly] disables keyboard input when the surface is used for log
  /// playback rather than an interactive shell.
  /// [showCursor] hides the caret (useful for static log playback).
  Widget buildView({
    bool autofocus = false,
    bool readOnly = false,
    bool showCursor = true,
  });

  /// Finds all matches for [query] in the terminal buffer. Returns the count.
  int find(String query, {bool caseSensitive = false});

  /// Jumps to the match at [index] (0-based) and highlights it.
  void findJump(int index);

  /// Clears find highlights / selection produced by [find].
  void findClear();

  /// Releases emulator-specific resources.
  Future<void> dispose();
}

class TerminalResize {
  const TerminalResize({
    required this.columns,
    required this.rows,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final int columns;
  final int rows;
  final int pixelWidth;
  final int pixelHeight;
}

abstract interface class TerminalSessionAdapterFactory {
  TerminalSessionAdapter create();
}

class TerminalSessionAdapterOption {
  const TerminalSessionAdapterOption({
    required this.id,
    required this.label,
    required this.description,
    required this.factory,
  });

  final String id;
  final String label;
  final String description;
  final TerminalSessionAdapterFactory factory;
}

class XtermTerminalSessionAdapterFactory
    implements TerminalSessionAdapterFactory {
  const XtermTerminalSessionAdapterFactory();

  @override
  TerminalSessionAdapter create() => XtermTerminalSessionAdapter();
}

class _BufferMatch {
  const _BufferMatch(this.line, this.start, this.end);

  final int line;
  final int start;
  final int end;
}

/// The production adapter backed by the xterm Flutter package.
class XtermTerminalSessionAdapter implements TerminalSessionAdapter {
  XtermTerminalSessionAdapter() : _terminal = Terminal(maxLines: 10000) {
    _terminal.onOutput = (data) {
      if (!_disposed) _outgoingBytes.add(Uint8List.fromList(utf8.encode(data)));
    };
    _terminal.onResize = (columns, rows, pixelWidth, pixelHeight) {
      if (!_disposed) {
        _resizeEvents.add(
          TerminalResize(
            columns: columns,
            rows: rows,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
          ),
        );
      }
    };
  }

  final Terminal _terminal;
  final TerminalController _controller = TerminalController();
  final ScrollController _scrollController = ScrollController();
  final _outgoingBytes = StreamController<Uint8List>.broadcast();
  final _resizeEvents = StreamController<TerminalResize>.broadcast();
  final _highlights = <TerminalHighlight>[];
  final _matches = <_BufferMatch>[];
  var _disposed = false;

  static const _hitColor = Color(0x66E5E510);
  static const _currentHitColor = Color(0xAA31FF26);
  static const _approxLineHeight = 18.0;

  @override
  Stream<Uint8List> get outgoingBytes => _outgoingBytes.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizeEvents.stream;

  @override
  void write(Uint8List bytes) {
    if (!_disposed) _terminal.write(utf8.decode(bytes, allowMalformed: true));
  }

  @override
  int find(String query, {bool caseSensitive = false}) {
    findClear();
    if (_disposed || query.isEmpty) return 0;
    final buffer = _terminal.buffer;
    final needle = caseSensitive ? query : query.toLowerCase();
    for (var y = 0; y < buffer.height; y++) {
      final lineText = buffer.lines[y].getText();
      final haystack = caseSensitive ? lineText : lineText.toLowerCase();
      var from = 0;
      while (true) {
        final index = haystack.indexOf(needle, from);
        if (index < 0) break;
        _matches.add(_BufferMatch(y, index, index + query.length));
        from = index + 1;
      }
    }
    _repaintAllHits(currentIndex: _matches.isEmpty ? null : 0);
    return _matches.length;
  }

  @override
  void findJump(int index) {
    if (_disposed || _matches.isEmpty) return;
    final safe = index.clamp(0, _matches.length - 1);
    // Keep every match painted; only restyle the current hit.
    _repaintAllHits(currentIndex: safe);
    final match = _matches[safe];
    final buffer = _terminal.buffer;
    final lineLen = buffer.lines[match.line].length;
    final start = match.start.clamp(0, lineLen);
    final endCol = (match.end - 1).clamp(start, lineLen > 0 ? lineLen - 1 : 0);
    _controller.setSelection(
      buffer.createAnchor(start, match.line),
      buffer.createAnchor(endCol, match.line),
    );
    if (_scrollController.hasClients) {
      final target = (match.line * _approxLineHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    }
  }

  @override
  void findClear({bool keepMatches = false}) {
    for (final highlight in _highlights) {
      highlight.dispose();
    }
    _highlights.clear();
    _controller.clearSelection();
    if (!keepMatches) _matches.clear();
  }

  void _repaintAllHits({required int? currentIndex}) {
    for (final highlight in _highlights) {
      highlight.dispose();
    }
    _highlights.clear();
    for (var i = 0; i < _matches.length; i++) {
      _paintMatch(i, current: currentIndex != null && i == currentIndex);
    }
  }

  void _paintMatch(int index, {required bool current}) {
    final match = _matches[index];
    final buffer = _terminal.buffer;
    final lineLen = buffer.lines[match.line].length;
    final start = match.start.clamp(0, lineLen);
    final endCol = (match.end - 1).clamp(start, lineLen > 0 ? lineLen - 1 : 0);
    _highlights.add(
      _controller.highlight(
        p1: buffer.createAnchor(start, match.line),
        p2: buffer.createAnchor(endCol, match.line),
        color: current ? _currentHitColor : _hitColor,
      ),
    );
  }

  @override
  Widget buildView({
    bool autofocus = false,
    bool readOnly = false,
    bool showCursor = true,
  }) {
    final baseTheme = TerminalThemes.defaultTheme;
    final theme = showCursor
        ? baseTheme
        : TerminalTheme(
            cursor: const Color(0x00000000),
            selection: baseTheme.selection,
            foreground: baseTheme.foreground,
            background: baseTheme.background,
            black: baseTheme.black,
            red: baseTheme.red,
            green: baseTheme.green,
            yellow: baseTheme.yellow,
            blue: baseTheme.blue,
            magenta: baseTheme.magenta,
            cyan: baseTheme.cyan,
            white: baseTheme.white,
            brightBlack: baseTheme.brightBlack,
            brightRed: baseTheme.brightRed,
            brightGreen: baseTheme.brightGreen,
            brightYellow: baseTheme.brightYellow,
            brightBlue: baseTheme.brightBlue,
            brightMagenta: baseTheme.brightMagenta,
            brightCyan: baseTheme.brightCyan,
            brightWhite: baseTheme.brightWhite,
            searchHitBackground: baseTheme.searchHitBackground,
            searchHitBackgroundCurrent: baseTheme.searchHitBackgroundCurrent,
            searchHitForeground: baseTheme.searchHitForeground,
          );
    return KeyedSubtree(
      key: ObjectKey(this),
      child: TerminalView(
        _terminal,
        controller: _controller,
        scrollController: _scrollController,
        autofocus: autofocus,
        readOnly: readOnly,
        hardwareKeyboardOnly: readOnly,
        alwaysShowCursor: false,
        backgroundOpacity: 0,
        theme: theme,
        padding: const EdgeInsets.all(12),
        textStyle: const TerminalStyle(
          fontFamily: MaidKitFonts.mono,
          fontFamilyFallback: [
            'Menlo',
            'Monaco',
            'Consolas',
            'Noto Sans Mono CJK SC',
            'Noto Color Emoji',
            'monospace',
          ],
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    findClear();
    _terminal.onOutput = null;
    _terminal.onResize = null;
    _scrollController.dispose();
    await _outgoingBytes.close();
    await _resizeEvents.close();
  }
}

/// Wires a terminal adapter to one shell's byte streams without coupling the
/// adapter contract to a specific SSH implementation.
class TerminalSessionBinding {
  TerminalSessionBinding({
    required this.adapter,
    required Stream<Uint8List> stdout,
    required Stream<Uint8List> stderr,
    required void Function(Uint8List bytes) send,
    required void Function(TerminalResize resize) resize,
  }) : _subscriptions = [
         stdout.listen(adapter.write),
         stderr.listen(adapter.write),
         adapter.outgoingBytes.listen(send),
         adapter.resizeEvents.listen(resize),
       ];

  final TerminalSessionAdapter adapter;
  final List<StreamSubscription<Object?>> _subscriptions;
  var _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await adapter.dispose();
  }
}
