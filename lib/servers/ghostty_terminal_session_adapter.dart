import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libghostty/libghostty.dart' as ghostty;

import 'package:maid_kit/theme.dart';
import 'terminal_session_adapter.dart';

/// Experimental terminal adapter backed by libghostty-vt.
///
/// libghostty supplies VT state and PTY callbacks, but not a Flutter renderer.
/// This prototype renders the visible grid with Flutter text painting. It is
/// intentionally kept separate from the production xterm adapter while input,
/// selection, and styling parity are evaluated.
class GhosttyTerminalSessionAdapterFactory
    implements TerminalSessionAdapterFactory {
  const GhosttyTerminalSessionAdapterFactory({
    required this.cursorAnimationEnabled,
  });

  final bool cursorAnimationEnabled;

  @override
  TerminalSessionAdapter create() => GhosttyTerminalSessionAdapter(
    cursorAnimationEnabled: cursorAnimationEnabled,
  );
}

class GhosttyTerminalSessionAdapter implements TerminalSessionAdapter {
  GhosttyTerminalSessionAdapter({this.cursorAnimationEnabled = true})
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
  final bool cursorAnimationEnabled;
  final _keyEncoder = ghostty.KeyEncoder();
  final _outgoingBytes = StreamController<Uint8List>.broadcast();
  final _resizeEvents = StreamController<TerminalResize>.broadcast();
  final _matches = <_GhosttyMatch>[];

  /// Bumped whenever find highlights change so the renderer repaints.
  final findRevision = ValueNotifier<int>(0);
  var _findIndex = 0;
  var _disposed = false;
  var _columns = _initialColumns;
  var _rows = _initialRows;

  void _bumpFind() {
    findRevision.value++;
  }

  @override
  Stream<Uint8List> get outgoingBytes => _outgoingBytes.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizeEvents.stream;

  @override
  void write(Uint8List bytes) {
    if (!_disposed) _terminal.write(bytes);
  }

  @override
  int find(String query, {bool caseSensitive = false}) {
    findClear();
    if (_disposed || query.isEmpty) return 0;

    final needle = caseSensitive ? query : query.toLowerCase();
    if (needle.isEmpty) return 0;

    // Prefer select-all plain text (includes scrollback). Keep soft wraps as
    // separate rows (unwrap: false) so column indices match the painted grid.
    final lines = _extractFindLines();
    for (var row = 0; row < lines.length; row++) {
      final line = lines[row];
      final haystack = caseSensitive ? line : line.toLowerCase();
      var from = 0;
      while (true) {
        final index = haystack.indexOf(needle, from);
        if (index < 0) break;
        _matches.add(
          _GhosttyMatch(row: row, start: index, end: index + needle.length),
        );
        from = index + 1;
      }
    }

    _findIndex = 0;
    _bumpFind();
    return _matches.length;
  }

  /// Rows of plain text covering scrollback + active area when possible.
  List<String> _extractFindLines() {
    final selection = _terminal.selectAll();
    if (selection != null) {
      final text = selection.format(unwrap: false, trim: false);
      if (text.isNotEmpty) {
        // Drop a trailing empty split from a final newline.
        final lines = text.split('\n');
        if (lines.isNotEmpty && lines.last.isEmpty) {
          return lines.sublist(0, lines.length - 1);
        }
        return lines;
      }
    }

    // Fallback: format the active screen only.
    final formatter = ghostty.Formatter(
      terminal: _terminal,
      format: ghostty.FormatterFormat.plain,
      unwrap: false,
      trim: false,
    );
    try {
      final text = formatter.format();
      final lines = text.split('\n');
      if (lines.isNotEmpty && lines.last.isEmpty) {
        return lines.sublist(0, lines.length - 1);
      }
      return lines;
    } finally {
      formatter.dispose();
    }
  }

  @override
  void findJump(int index) {
    if (_disposed || _matches.isEmpty) return;
    final safe = index.clamp(0, _matches.length - 1);
    _findIndex = safe;
    final match = _matches[safe];
    // Pin the match near the top of the viewport so the highlight is visible.
    final visible = _terminal.scrollbar.visible;
    final target = (match.row - (visible ~/ 3)).clamp(0, 1 << 30);
    _terminal.scrollToRow(target);
    _bumpFind();
  }

  @override
  void findClear() {
    final had = _matches.isNotEmpty;
    _matches.clear();
    _findIndex = 0;
    if (!_disposed && had) {
      _terminal.selection = null;
    }
    if (had) _bumpFind();
  }

  @override
  Widget buildView({
    bool autofocus = false,
    bool readOnly = false,
    bool showCursor = true,
  }) => _GhosttyTerminalView(
    key: ObjectKey(this),
    adapter: this,
    autofocus: autofocus,
    readOnly: readOnly,
    showCursor: showCursor,
    cursorAnimationEnabled: cursorAnimationEnabled,
  );

  void sendInput(String text) {
    if (!_disposed && text.isNotEmpty) {
      _terminal.selection = null;
      _outgoingBytes.add(Uint8List.fromList(utf8.encode(text)));
    }
  }

  void sendKey(ghostty.Key key) {
    if (_disposed) return;
    final event = ghostty.KeyEvent()
      ..action = ghostty.KeyAction.press
      ..key = key;
    _keyEncoder.sync(_terminal);
    final encoded = _keyEncoder.encode(event);
    event.dispose();
    sendInput(encoded);
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
    _matches.clear();
    findRevision.dispose();
    _terminal.onWritePty = null;
    _keyEncoder.dispose();
    _terminal.dispose();
    await _outgoingBytes.close();
    await _resizeEvents.close();
  }
}

class _GhosttyMatch {
  const _GhosttyMatch({
    required this.row,
    required this.start,
    required this.end,
  });

  final int row;
  final int start;
  final int end;
}

class _GhosttyFindHit {
  const _GhosttyFindHit({
    required this.viewportRow,
    required this.start,
    required this.end,
    required this.current,
  });

  final int viewportRow;
  final int start;
  final int end;
  final bool current;
}

class _GhosttyTerminalView extends StatefulWidget {
  const _GhosttyTerminalView({
    super.key,
    required this.adapter,
    required this.autofocus,
    required this.readOnly,
    required this.showCursor,
    required this.cursorAnimationEnabled,
  });

  final GhosttyTerminalSessionAdapter adapter;
  final bool autofocus;
  final bool readOnly;
  final bool showCursor;
  final bool cursorAnimationEnabled;

  @override
  State<_GhosttyTerminalView> createState() => _GhosttyTerminalViewState();
}

class _GhosttyTerminalViewState extends State<_GhosttyTerminalView>
    with SingleTickerProviderStateMixin {
  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 12.0;
  static const _cellWidth = 8.4;
  static const _cellHeight = 18.0;

  final _focusNode = FocusNode();
  final _renderState = ghostty.RenderState();
  final _rows = ghostty.RowIterator();
  final _cells = ghostty.CellIterator();
  late final _cursorAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );
  var _resizeScheduled = false;

  /// Trackpad/wheel deltas are often smaller than one cell; accumulate so we
  /// do not drop sub-line scrolls (which feels like "scroll is broken").
  var _scrollAccumulator = 0.0;
  String? _composingText;
  ghostty.Position? _selectionStart;
  var _draggingSelection = false;
  Offset? _cursorFrom;
  Offset? _cursorTo;

  @override
  void initState() {
    super.initState();
    widget.adapter._terminal.addListener(_onTerminalChanged);
    widget.adapter.findRevision.addListener(_onTerminalChanged);
  }

  @override
  void didUpdateWidget(_GhosttyTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.adapter, widget.adapter)) {
      oldWidget.adapter._terminal.removeListener(_onTerminalChanged);
      oldWidget.adapter.findRevision.removeListener(_onTerminalChanged);
      widget.adapter._terminal.addListener(_onTerminalChanged);
      widget.adapter.findRevision.addListener(_onTerminalChanged);
    }
  }

  @override
  void dispose() {
    widget.adapter._terminal.removeListener(_onTerminalChanged);
    widget.adapter.findRevision.removeListener(_onTerminalChanged);
    _cells.dispose();
    _rows.dispose();
    _renderState.dispose();
    _cursorAnimation.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTerminalChanged() {
    if (mounted) setState(() {});
  }

  /// Map absolute screen-row find hits into the current viewport.
  List<_GhosttyFindHit> _visibleFindHits() {
    final matches = widget.adapter._matches;
    if (matches.isEmpty) return const [];
    final scrollbar = widget.adapter._terminal.scrollbar;
    final offset = scrollbar.offset;
    final visible = scrollbar.visible;
    final current = widget.adapter._findIndex;
    final hits = <_GhosttyFindHit>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final viewportRow = match.row - offset;
      if (viewportRow < 0 || viewportRow >= visible) continue;
      hits.add(
        _GhosttyFindHit(
          viewportRow: viewportRow,
          start: match.start,
          end: match.end,
          current: i == current,
        ),
      );
    }
    return hits;
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
    final colors = _renderState.colors;
    final rows = <List<_GhosttyTerminalCell>>[];
    _rows.reset(_renderState);
    while (_rows.next()) {
      final cells = <_GhosttyTerminalCell>[];
      _cells.reset(_rows);
      while (_cells.next()) {
        cells.add(
          _GhosttyTerminalCell(
            column: _cells.col,
            text: _cells.content,
            foregroundArgb: _cells.foregroundArgb,
            backgroundArgb: _cells.backgroundArgb,
            wide: _cells.wide == ghostty.CellWidth.wide,
            spacer:
                _cells.wide == ghostty.CellWidth.spacerTail ||
                _cells.wide == ghostty.CellWidth.spacerHead,
            selected: _cells.isSelected,
          ),
        );
      }
      rows.add(cells);
      _rows.dirty = false;
    }
    _renderState.dirty = ghostty.DirtyState.clean;
    return _GhosttyTerminalFrame(
      rows: rows,
      cursor: _renderState.cursor,
      foregroundArgb: colors.foreground.toArgb32,
      backgroundArgb: colors.background.toArgb32,
      cursorArgb: colors.cursor?.toArgb32,
      composingText: _composingText,
    );
  }

  void _animateCursor(ghostty.Cursor cursor) {
    final target = Offset(
      cursor.position.col.toDouble(),
      cursor.position.row.toDouble(),
    );
    if (_cursorTo == null) {
      _cursorFrom = target;
      _cursorTo = target;
      return;
    }
    if (!widget.cursorAnimationEnabled) {
      _cursorAnimation.stop();
      _cursorFrom = target;
      _cursorTo = target;
      return;
    }
    if (target == _cursorTo) return;
    _cursorFrom = Offset.lerp(
      _cursorFrom,
      _cursorTo,
      Curves.easeOutCubic.transform(_cursorAnimation.value),
    )!;
    _cursorTo = target;
    _cursorAnimation.forward(from: 0);
  }

  ghostty.Position _positionFor(Offset offset) {
    final column = ((offset.dx - _horizontalPadding) / _cellWidth)
        .floor()
        .clamp(0, _renderState.cols - 1);
    final row = ((offset.dy - _verticalPadding) / _cellHeight).floor().clamp(
      0,
      _renderState.rows - 1,
    );
    return ghostty.Position(row: row, col: column);
  }

  void _updateSelection(ghostty.Position end) {
    final start = _selectionStart;
    if (start == null) return;
    final terminal = widget.adapter._terminal;
    terminal.selection = ghostty.Selection.fromRefs(
      start: ghostty.GridRef.at(terminal, start, pointTag: .viewport),
      end: ghostty.GridRef.at(terminal, end, pointTag: .viewport),
    );
  }

  Future<void> _copySelection() async {
    final text = widget.adapter._terminal.formatSelection(trim: true);
    if (text != null && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<void> _paste() async {
    if (widget.readOnly) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text != null && text.isNotEmpty) widget.adapter.sendInput(text);
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final command =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (command &&
        event.logicalKey == LogicalKeyboardKey.keyC &&
        widget.adapter._terminal.selection != null) {
      unawaited(_copySelection());
      return KeyEventResult.handled;
    }
    // Log playback and other read-only surfaces ignore typing/paste.
    if (widget.readOnly) return KeyEventResult.ignored;
    if (command && event.logicalKey == LogicalKeyboardKey.keyV) {
      unawaited(_paste());
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    final ghosttyKey = switch (key) {
      LogicalKeyboardKey.arrowUp => ghostty.Key.arrowUp,
      LogicalKeyboardKey.arrowDown => ghostty.Key.arrowDown,
      LogicalKeyboardKey.arrowRight => ghostty.Key.arrowRight,
      LogicalKeyboardKey.arrowLeft => ghostty.Key.arrowLeft,
      LogicalKeyboardKey.backspace => ghostty.Key.backspace,
      LogicalKeyboardKey.delete => ghostty.Key.delete,
      _ => null,
    };
    if (ghosttyKey != null) {
      widget.adapter.sendKey(ghosttyKey);
      return KeyEventResult.handled;
    }

    final escape = switch (key) {
      LogicalKeyboardKey.enter => '\r',
      LogicalKeyboardKey.tab => '\t',
      LogicalKeyboardKey.escape => '\u001b',
      LogicalKeyboardKey.home => '\u001b[H',
      LogicalKeyboardKey.end => '\u001b[F',
      LogicalKeyboardKey.pageUp => '\u001b[5~',
      LogicalKeyboardKey.pageDown => '\u001b[6~',
      _ => null,
    };
    if (escape != null) {
      widget.adapter.sendInput(escape);
      return KeyEventResult.handled;
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

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final frame = _visibleFrame();
    _animateCursor(frame.cursor);
    return ClipRect(
      child: ColoredBox(
        color: const Color(0xFF111315),
        child: _GhosttyTextInput(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _onKeyEvent,
          onInsert: widget.adapter.sendInput,
          onDelete: () => widget.adapter.sendKey(ghostty.Key.backspace),
          onAction: () => widget.adapter.sendInput('\r'),
          onComposing: (text) {
            if (_composingText != text && mounted) {
              setState(() => _composingText = text);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusNode.requestFocus,
            child: Listener(
              onPointerDown: (event) {
                if (event.buttons == kPrimaryButton) {
                  _selectionStart = _positionFor(event.localPosition);
                  _draggingSelection = false;
                }
              },
              onPointerMove: (event) {
                if (_selectionStart != null &&
                    event.buttons == kPrimaryButton) {
                  _draggingSelection = true;
                  _updateSelection(_positionFor(event.localPosition));
                }
              },
              onPointerUp: (_) {
                if (!_draggingSelection) {
                  widget.adapter._terminal.selection = null;
                }
                _selectionStart = null;
                _draggingSelection = false;
              },
              onPointerSignal: (event) {
                if (event is! PointerScrollEvent) return;
                _scrollAccumulator += event.scrollDelta.dy;
                final lines = _scrollAccumulator ~/ _cellHeight;
                if (lines == 0) return;
                _scrollAccumulator -= lines * _cellHeight;
                widget.adapter._terminal.scrollViewport(lines);
                setState(() {});
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _scheduleResize(constraints);
                  return CustomPaint(
                    painter: _GhosttyTerminalPainter(
                      frame,
                      cursorAnimation: _cursorAnimation,
                      cursorFrom: _cursorFrom!,
                      cursorTo: _cursorTo!,
                      showCursor: widget.showCursor,
                      findHits: _visibleFindHits(),
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Invisible native text-input bridge so desktop IMEs can compose text before
/// committing it to the terminal stream.
class _GhosttyTextInput extends StatefulWidget {
  const _GhosttyTextInput({
    required this.child,
    required this.focusNode,
    required this.autofocus,
    required this.onInsert,
    required this.onDelete,
    required this.onAction,
    required this.onComposing,
    required this.onKeyEvent,
  });

  final Widget child;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onInsert;
  final VoidCallback onDelete;
  final VoidCallback onAction;
  final ValueChanged<String?> onComposing;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  @override
  State<_GhosttyTextInput> createState() => _GhosttyTextInputState();
}

class _GhosttyTextInputState extends State<_GhosttyTextInput>
    with TextInputClient {
  static const _initialValue = TextEditingValue(
    selection: TextSelection.collapsed(offset: 0),
  );

  TextInputConnection? _connection;
  var _editingValue = _initialValue;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_GhosttyTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    _closeConnection();
    super.dispose();
  }

  bool get _hasConnection => _connection?.attached ?? false;

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openConnection();
    } else if (!widget.focusNode.hasFocus) {
      _closeConnection();
    }
  }

  void _openConnection() {
    if (_hasConnection) {
      _connection!.show();
      return;
    }
    _connection = TextInput.attach(
      this,
      const TextInputConfiguration(
        inputType: TextInputType.text,
        inputAction: TextInputAction.newline,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
      ),
    )..show();
    _connection!.setEditingState(_initialValue);
  }

  void _closeConnection() {
    if (_hasConnection) _connection!.close();
    _connection = null;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_editingValue.composing.isCollapsed) {
      return KeyEventResult.skipRemainingHandlers;
    }
    // TextInput consumes these keys as editing commands, which prevents them
    // reaching the PTY. They are terminal controls, not edits to our invisible
    // composing buffer, so pass them directly to the terminal handler.
    switch (event.logicalKey) {
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.tab:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.home:
      case LogicalKeyboardKey.end:
      case LogicalKeyboardKey.pageUp:
      case LogicalKeyboardKey.pageDown:
        return widget.onKeyEvent(node, event);
      default:
        break;
    }
    final isTerminalShortcut =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isTerminalShortcut &&
        event.character != null &&
        event.character!.isNotEmpty) {
      // Let the platform text-input client receive printable keys. This is
      // required for IMEs to build and commit a composed character instead of
      // forwarding each composing keystroke to the remote shell.
      return KeyEventResult.skipRemainingHandlers;
    }
    return widget.onKeyEvent(node, event);
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.focusNode,
    autofocus: widget.autofocus,
    onKeyEvent: _onKeyEvent,
    child: widget.child,
  );

  @override
  TextEditingValue? get currentTextEditingValue => _editingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    final previous = _editingValue;
    _editingValue = value;
    if (!value.composing.isCollapsed) {
      widget.onComposing(value.composing.textInside(value.text));
      return;
    }

    widget.onComposing(null);
    if (value.text.isEmpty && previous.text.isNotEmpty) {
      widget.onDelete();
    } else if (value.text.isNotEmpty) {
      widget.onInsert(value.text);
    }
    _editingValue = _initialValue;
    _connection?.setEditingState(_initialValue);
  }

  @override
  void performAction(TextInputAction action) => widget.onAction();

  @override
  void connectionClosed() {
    _connection = null;
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}
}

class _GhosttyTerminalPainter extends CustomPainter {
  _GhosttyTerminalPainter(
    this.frame, {
    required this.cursorAnimation,
    required this.cursorFrom,
    required this.cursorTo,
    required this.showCursor,
    required this.findHits,
  }) : super(repaint: cursorAnimation);

  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 12.0;
  static const _cellWidth = 8.4;
  static const _cellHeight = 18.0;
  static const _selectionOverlay = Color(0x6638BDF8);
  // Strong enough to read on dark terminal chrome after cell backgrounds.
  static const _findHitOverlay = Color(0x99E5E510);
  static const _findCurrentOverlay = Color(0xCC39FF14);

  final _GhosttyTerminalFrame frame;
  final Animation<double> cursorAnimation;
  final Offset cursorFrom;
  final Offset cursorTo;
  final bool showCursor;
  final List<_GhosttyFindHit> findHits;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Color(frame.backgroundArgb), BlendMode.src);
    const textStyle = TextStyle(
      fontFamily: MaidKitFonts.mono,
      fontSize: 14,
      height: 1.2857,
    );

    // 1) Cell backgrounds
    for (var rowIndex = 0; rowIndex < frame.rows.length; rowIndex++) {
      int? backgroundRunColor;
      int? backgroundRunStart;
      var backgroundRunEnd = 0;
      for (final cell in frame.rows[rowIndex]) {
        if (cell.spacer) continue;
        final color = cell.backgroundArgb ?? frame.backgroundArgb;
        final cellEnd = cell.column + (cell.wide ? 2 : 1);
        if (backgroundRunColor == color && cell.column <= backgroundRunEnd) {
          if (cellEnd > backgroundRunEnd) backgroundRunEnd = cellEnd;
          continue;
        }
        if (backgroundRunColor != null) {
          _paintBackgroundRun(
            canvas,
            rowIndex: rowIndex,
            start: backgroundRunStart!,
            end: backgroundRunEnd,
            color: backgroundRunColor,
          );
        }
        backgroundRunColor = color;
        backgroundRunStart = cell.column;
        backgroundRunEnd = cellEnd;
      }
      if (backgroundRunColor != null) {
        _paintBackgroundRun(
          canvas,
          rowIndex: rowIndex,
          start: backgroundRunStart!,
          end: backgroundRunEnd,
          color: backgroundRunColor,
        );
      }
    }

    // 2) Find highlights (above cell bg, under glyphs) so they stay visible.
    for (final hit in findHits) {
      if (hit.viewportRow < 0 || hit.viewportRow >= frame.rows.length) {
        continue;
      }
      final end = hit.end <= hit.start ? hit.start + 1 : hit.end;
      _paintOverlayRun(
        canvas,
        rowIndex: hit.viewportRow,
        start: hit.start,
        end: end,
        color: hit.current ? _findCurrentOverlay : _findHitOverlay,
      );
    }

    // 3) Glyphs, selection, then cursor.
    for (var rowIndex = 0; rowIndex < frame.rows.length; rowIndex++) {
      for (final cell in frame.rows[rowIndex]) {
        final x = _horizontalPadding + cell.column * _cellWidth;
        final y = _verticalPadding + rowIndex * _cellHeight;
        // A wide glyph owns its trailing spacer cell. Its leading cell paints
        // the two-cell background and glyph, so the spacer must not repaint
        // either half of it.
        if (cell.spacer) continue;
        if (cell.text.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(
            text: cell.text,
            style: textStyle.copyWith(
              color: Color(cell.foregroundArgb ?? frame.foregroundArgb),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        painter.paint(canvas, Offset(x, y));
      }
      int? selectionStart;
      var selectionEnd = 0;
      for (final cell in frame.rows[rowIndex]) {
        final cellEnd = cell.column + (cell.wide ? 2 : 1);
        if (!cell.selected) {
          if (selectionStart != null) {
            _paintSelectionRun(
              canvas,
              rowIndex: rowIndex,
              start: selectionStart,
              end: selectionEnd,
            );
            selectionStart = null;
          }
          continue;
        }
        selectionStart ??= cell.column;
        if (cellEnd > selectionEnd) selectionEnd = cellEnd;
      }
      if (selectionStart != null) {
        _paintSelectionRun(
          canvas,
          rowIndex: rowIndex,
          start: selectionStart,
          end: selectionEnd,
        );
      }
    }
    final cursor = frame.cursor;
    final cursorPosition = Offset.lerp(
      cursorFrom,
      cursorTo,
      Curves.easeOutCubic.transform(cursorAnimation.value),
    )!;
    if (showCursor &&
        cursor.visible &&
        cursorPosition.dy >= 0 &&
        cursorPosition.dy < frame.rows.length) {
      final cursorPaint = Paint()
        ..color = Color(frame.cursorArgb ?? frame.foregroundArgb);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _horizontalPadding + cursorPosition.dx * _cellWidth,
            _verticalPadding + cursorPosition.dy * _cellHeight + 2,
            2,
            _cellHeight - 4,
          ),
          const Radius.circular(1),
        ),
        cursorPaint,
      );
    }
    final composingText = frame.composingText;
    if (composingText?.isNotEmpty ?? false) {
      final painter = TextPainter(
        text: TextSpan(
          text: composingText,
          style: textStyle.copyWith(
            color: Color(frame.foregroundArgb),
            decoration: TextDecoration.underline,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          _horizontalPadding + cursor.position.col * _cellWidth,
          _verticalPadding + cursor.position.row * _cellHeight,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_GhosttyTerminalPainter oldDelegate) =>
      !identical(frame, oldDelegate.frame) ||
      cursorFrom != oldDelegate.cursorFrom ||
      cursorTo != oldDelegate.cursorTo ||
      showCursor != oldDelegate.showCursor ||
      !_sameFindHits(findHits, oldDelegate.findHits);

  bool _sameFindHits(List<_GhosttyFindHit> a, List<_GhosttyFindHit> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.viewportRow != right.viewportRow ||
          left.start != right.start ||
          left.end != right.end ||
          left.current != right.current) {
        return false;
      }
    }
    return true;
  }

  void _paintOverlayRun(
    Canvas canvas, {
    required int rowIndex,
    required int start,
    required int end,
    required Color color,
  }) {
    if (end <= start) return;
    final rect = Rect.fromLTWH(
      _horizontalPadding + start * _cellWidth,
      _verticalPadding + rowIndex * _cellHeight,
      (end - start) * _cellWidth,
      _cellHeight,
    );
    canvas.drawRect(rect, Paint()..color = color);
  }

  void _paintSelectionRun(
    Canvas canvas, {
    required int rowIndex,
    required int start,
    required int end,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(
        _horizontalPadding + start * _cellWidth,
        _verticalPadding + rowIndex * _cellHeight,
        (end - start) * _cellWidth,
        _cellHeight,
      ),
      Paint()..color = _selectionOverlay,
    );
  }

  void _paintBackgroundRun(
    Canvas canvas, {
    required int rowIndex,
    required int start,
    required int end,
    required int color,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(
        _horizontalPadding + start * _cellWidth,
        _verticalPadding + rowIndex * _cellHeight,
        (end - start) * _cellWidth,
        _cellHeight,
      ),
      Paint()..color = Color(color),
    );
  }
}

class _GhosttyTerminalFrame {
  const _GhosttyTerminalFrame({
    required this.rows,
    required this.cursor,
    required this.foregroundArgb,
    required this.backgroundArgb,
    required this.cursorArgb,
    required this.composingText,
  });

  final List<List<_GhosttyTerminalCell>> rows;
  final ghostty.Cursor cursor;
  final int foregroundArgb;
  final int backgroundArgb;
  final int? cursorArgb;
  final String? composingText;
}

class _GhosttyTerminalCell {
  const _GhosttyTerminalCell({
    required this.column,
    required this.text,
    required this.foregroundArgb,
    required this.backgroundArgb,
    required this.wide,
    required this.spacer,
    required this.selected,
  });

  final int column;
  final String text;
  final int? foregroundArgb;
  final int? backgroundArgb;
  final bool wide;
  final bool spacer;
  final bool selected;
}
