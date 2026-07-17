import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libghostty/libghostty.dart' as ghostty;

import 'terminal_session_adapter.dart';

/// Experimental terminal adapter backed by libghostty-vt.
///
/// libghostty supplies VT state and PTY callbacks, but not a Flutter renderer.
/// This prototype renders the visible grid with Flutter text painting. It is
/// intentionally kept separate from the production xterm adapter while input,
/// selection, and styling parity are evaluated.
class GhosttyTerminalSessionAdapterFactory
    implements TerminalSessionAdapterFactory {
  const GhosttyTerminalSessionAdapterFactory();

  @override
  TerminalSessionAdapter create() => GhosttyTerminalSessionAdapter();
}

class GhosttyTerminalSessionAdapter implements TerminalSessionAdapter {
  GhosttyTerminalSessionAdapter()
    : _terminal = ghostty.Terminal(
        cols: _initialColumns,
        rows: _initialRows,
        maxScrollback: 10000,
      ) {
    _terminal.onWritePty = (data) {
      if (!_disposed) _outgoingBytes.add(Uint8List.fromList(data));
    };
  }

  static const _initialColumns = 80;
  static const _initialRows = 24;

  final ghostty.Terminal _terminal;
  final _outgoingBytes = StreamController<Uint8List>.broadcast();
  final _resizeEvents = StreamController<TerminalResize>.broadcast();
  var _disposed = false;
  var _columns = _initialColumns;
  var _rows = _initialRows;

  @override
  Stream<Uint8List> get outgoingBytes => _outgoingBytes.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizeEvents.stream;

  @override
  void write(Uint8List bytes) {
    if (!_disposed) _terminal.write(bytes);
  }

  @override
  Widget buildView({bool autofocus = false}) =>
      _GhosttyTerminalView(adapter: this, autofocus: autofocus);

  void sendInput(String text) {
    if (!_disposed && text.isNotEmpty) {
      _outgoingBytes.add(Uint8List.fromList(utf8.encode(text)));
    }
  }

  void resize({
    required int columns,
    required int rows,
    required int pixelWidth,
    required int pixelHeight,
  }) {
    if (_disposed || (columns == _columns && rows == _rows)) return;
    _columns = columns;
    _rows = rows;
    _terminal.resize(
      cols: columns,
      rows: rows,
      cellWidthPx: pixelWidth ~/ columns,
      cellHeightPx: pixelHeight ~/ rows,
    );
    _resizeEvents.add(
      TerminalResize(
        columns: columns,
        rows: rows,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _terminal.onWritePty = null;
    _terminal.dispose();
    await _outgoingBytes.close();
    await _resizeEvents.close();
  }
}

class _GhosttyTerminalView extends StatefulWidget {
  const _GhosttyTerminalView({required this.adapter, required this.autofocus});

  final GhosttyTerminalSessionAdapter adapter;
  final bool autofocus;

  @override
  State<_GhosttyTerminalView> createState() => _GhosttyTerminalViewState();
}

class _GhosttyTerminalViewState extends State<_GhosttyTerminalView> {
  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 12.0;
  static const _cellWidth = 8.4;
  static const _cellHeight = 18.0;

  final _focusNode = FocusNode();
  final _renderState = ghostty.RenderState();
  final _rows = ghostty.RowIterator();
  final _cells = ghostty.CellIterator();
  var _resizeScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.adapter._terminal.addListener(_onTerminalChanged);
  }

  @override
  void dispose() {
    widget.adapter._terminal.removeListener(_onTerminalChanged);
    _cells.dispose();
    _rows.dispose();
    _renderState.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTerminalChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleResize(BoxConstraints constraints) {
    if (_resizeScheduled ||
        !constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight) {
      return;
    }
    _resizeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resizeScheduled = false;
      if (!mounted) return;
      final availableWidth = (constraints.maxWidth - _horizontalPadding * 2)
          .clamp(1.0, double.infinity);
      final availableHeight = (constraints.maxHeight - _verticalPadding * 2)
          .clamp(1.0, double.infinity);
      final columns = (availableWidth / _cellWidth).floor().clamp(1, 500);
      final rows = (availableHeight / _cellHeight).floor().clamp(1, 300);
      widget.adapter.resize(
        columns: columns,
        rows: rows,
        pixelWidth: availableWidth.round(),
        pixelHeight: availableHeight.round(),
      );
    });
  }

  _GhosttyTerminalFrame _visibleFrame() {
    _renderState.update(widget.adapter._terminal);
    final lines = <String>[];
    _rows.reset(_renderState);
    while (_rows.next()) {
      final buffer = StringBuffer();
      _cells.reset(_rows);
      while (_cells.next()) {
        buffer.write(_cells.content.isEmpty ? ' ' : _cells.content);
      }
      lines.add(buffer.toString().trimRight());
      _rows.dirty = false;
    }
    _renderState.dirty = ghostty.DirtyState.clean;
    return _GhosttyTerminalFrame(lines, _renderState.cursor);
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character != null && character.isNotEmpty) {
      final control = HardwareKeyboard.instance.isControlPressed;
      final alt = HardwareKeyboard.instance.isAltPressed;
      final value = control && character.length == 1
          ? String.fromCharCode(character.toUpperCase().codeUnitAt(0) & 0x1f)
          : character;
      widget.adapter.sendInput('${alt ? '\u001b' : ''}$value');
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;
    final escape = switch (key) {
      LogicalKeyboardKey.enter => '\r',
      LogicalKeyboardKey.tab => '\t',
      LogicalKeyboardKey.backspace => '\u007f',
      LogicalKeyboardKey.escape => '\u001b',
      LogicalKeyboardKey.arrowUp => '\u001b[A',
      LogicalKeyboardKey.arrowDown => '\u001b[B',
      LogicalKeyboardKey.arrowRight => '\u001b[C',
      LogicalKeyboardKey.arrowLeft => '\u001b[D',
      LogicalKeyboardKey.home => '\u001b[H',
      LogicalKeyboardKey.end => '\u001b[F',
      LogicalKeyboardKey.delete => '\u001b[3~',
      LogicalKeyboardKey.pageUp => '\u001b[5~',
      LogicalKeyboardKey.pageDown => '\u001b[6~',
      _ => null,
    };
    if (escape == null) return KeyEventResult.ignored;
    widget.adapter.sendInput(escape);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final frame = _visibleFrame();
    return ColoredBox(
      color: const Color(0xFF111315),
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _scheduleResize(constraints);
              return CustomPaint(
                painter: _GhosttyTerminalPainter(frame),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GhosttyTerminalPainter extends CustomPainter {
  const _GhosttyTerminalPainter(this.frame);

  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 12.0;
  static const _cellWidth = 8.4;
  static const _cellHeight = 18.0;

  final _GhosttyTerminalFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    const style = TextStyle(
      color: Color(0xFFE6E8EA),
      fontFamily: 'Menlo',
      fontFamilyFallback: ['Consolas', 'DejaVu Sans Mono', 'monospace'],
      fontSize: 14,
      height: 1.2857,
    );
    for (var index = 0; index < frame.lines.length; index++) {
      final painter = TextPainter(
        text: TextSpan(text: frame.lines[index], style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width - _horizontalPadding * 2);
      painter.paint(
        canvas,
        Offset(_horizontalPadding, _verticalPadding + index * _cellHeight),
      );
    }
    final cursor = frame.cursor;
    if (cursor.visible &&
        cursor.position.row >= 0 &&
        cursor.position.row < frame.lines.length) {
      final cursorPaint = Paint()..color = const Color(0xFFB8C2CC);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _horizontalPadding + cursor.position.col * _cellWidth,
            _verticalPadding + cursor.position.row * _cellHeight + 2,
            2,
            _cellHeight - 4,
          ),
          const Radius.circular(1),
        ),
        cursorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GhosttyTerminalPainter oldDelegate) =>
      !identical(frame, oldDelegate.frame);
}

class _GhosttyTerminalFrame {
  const _GhosttyTerminalFrame(this.lines, this.cursor);

  final List<String> lines;
  final ghostty.Cursor cursor;
}
