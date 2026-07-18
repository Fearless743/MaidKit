import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libghostty/libghostty.dart' as ghostty;
import 'package:maid_kit/servers/ghostty_terminal_session_adapter.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/servers/terminal_adapter_preferences.dart';
import 'package:maid_kit/servers/terminal_session_adapter.dart';

void main() {
  test(
    'persists the selected terminal adapter through the settings store',
    () async {
      final settings = InMemoryTerminalAdapterSettings();
      final container = ProviderContainer(
        overrides: [
          terminalAdapterPreferencesProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedTerminalSessionAdapterProvider), 'ghostty');

      await container
          .read(selectedTerminalSessionAdapterProvider.notifier)
          .select('xterm');

      expect(container.read(selectedTerminalSessionAdapterProvider), 'xterm');
      expect(settings.selectedAdapterId, 'xterm');
    },
  );

  test('Ghostty adapter reports terminal resize events', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final resize = adapter.resizeEvents.first;

    adapter.resize(columns: 120, rows: 36, pixelWidth: 960, pixelHeight: 720);

    expect(
      await resize,
      isA<TerminalResize>()
          .having((event) => event.columns, 'columns', 120)
          .having((event) => event.rows, 'rows', 36),
    );
    await adapter.dispose();
  });

  test('Ghostty adapter encodes cursor keys for the remote shell', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendKey(ghostty.Key.arrowUp);

    expect(utf8.decode(await output), '\u001b[A');
    await adapter.dispose();
  });

  test('Ghostty adapter encodes backspace for the remote shell', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendKey(ghostty.Key.backspace);

    expect(utf8.decode(await output), '\u007f');
    await adapter.dispose();
  });

  test('forwards shell output, terminal input, and resize events', () async {
    final stdout = StreamController<Uint8List>();
    final stderr = StreamController<Uint8List>();
    final adapter = _FakeTerminalSessionAdapter();
    final sent = <Uint8List>[];
    final resizes = <TerminalResize>[];
    final binding = TerminalSessionBinding(
      adapter: adapter,
      stdout: stdout.stream,
      stderr: stderr.stream,
      send: sent.add,
      resize: resizes.add,
    );

    stdout.add(Uint8List.fromList([1, 2]));
    stderr.add(Uint8List.fromList([3]));
    adapter.emitInput(Uint8List.fromList([4]));
    const resize = TerminalResize(
      columns: 120,
      rows: 36,
      pixelWidth: 960,
      pixelHeight: 720,
    );
    adapter.emitResize(resize);
    await Future<void>.delayed(Duration.zero);

    expect(adapter.received, [
      Uint8List.fromList([1, 2]),
      Uint8List.fromList([3]),
    ]);
    expect(sent, [
      Uint8List.fromList([4]),
    ]);
    expect(resizes, [resize]);

    await binding.close();
    expect(adapter.disposed, isTrue);
    await stdout.close();
    await stderr.close();
  });

  test(
    'closing a shell binding stops forwarding and disposes the adapter',
    () async {
      final stdout = StreamController<Uint8List>();
      final stderr = StreamController<Uint8List>();
      final adapter = _FakeTerminalSessionAdapter();
      var sent = 0;
      final binding = TerminalSessionBinding(
        adapter: adapter,
        stdout: stdout.stream,
        stderr: stderr.stream,
        send: (_) => sent++,
        resize: (_) {},
      );

      await binding.close();
      stdout.add(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);

      expect(adapter.received, isEmpty);
      expect(sent, 0);
      expect(adapter.disposed, isTrue);
      await stdout.close();
      await stderr.close();
    },
  );
}

class _FakeTerminalSessionAdapter implements TerminalSessionAdapter {
  final received = <Uint8List>[];
  final _outgoing = StreamController<Uint8List>.broadcast();
  final _resizes = StreamController<TerminalResize>.broadcast();
  var disposed = false;

  @override
  Stream<Uint8List> get outgoingBytes => _outgoing.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizes.stream;

  @override
  Widget buildView({
    bool autofocus = false,
    bool readOnly = false,
    bool showCursor = true,
  }) => const SizedBox();

  @override
  int find(String query, {bool caseSensitive = false}) => 0;

  @override
  void findJump(int index) {}

  @override
  void findClear() {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _outgoing.close();
    await _resizes.close();
  }

  void emitInput(Uint8List bytes) => _outgoing.add(bytes);

  void emitResize(TerminalResize resize) => _resizes.add(resize);

  @override
  void write(Uint8List bytes) => received.add(bytes);
}
