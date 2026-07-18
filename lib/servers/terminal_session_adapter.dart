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
  Widget buildView({bool autofocus = false});

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
  final _outgoingBytes = StreamController<Uint8List>.broadcast();
  final _resizeEvents = StreamController<TerminalResize>.broadcast();
  var _disposed = false;

  @override
  Stream<Uint8List> get outgoingBytes => _outgoingBytes.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizeEvents.stream;

  @override
  void write(Uint8List bytes) {
    if (!_disposed) _terminal.write(utf8.decode(bytes, allowMalformed: true));
  }

  @override
  Widget buildView({bool autofocus = false}) => KeyedSubtree(
    key: ObjectKey(this),
    child: TerminalView(
      _terminal,
      autofocus: autofocus,
      backgroundOpacity: 0,
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

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _terminal.onOutput = null;
    _terminal.onResize = null;
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
