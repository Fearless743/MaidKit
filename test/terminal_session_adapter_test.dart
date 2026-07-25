import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:flterm/flterm.dart' as flterm;
import 'package:maid_kit/servers/ghostty_terminal_session_adapter.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/servers/terminal_adapter_preferences.dart';
import 'package:maid_kit/servers/terminal_color_scheme.dart';
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

  test(
    'persists the selected terminal color scheme through settings',
    () async {
      final settings = InMemoryTerminalAdapterSettings(
        colorSchemeId: TerminalColorSchemes.catppuccinMocha.id,
      );
      final container = ProviderContainer(
        overrides: [
          terminalAdapterPreferencesProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(terminalColorSchemeProvider),
        TerminalColorSchemes.catppuccinMocha,
      );

      await container
          .read(terminalColorSchemeProvider.notifier)
          .select(TerminalColorSchemes.nord.id);

      expect(
        container.read(terminalColorSchemeProvider),
        TerminalColorSchemes.nord,
      );
      expect(settings.colorSchemeId, TerminalColorSchemes.nord.id);
    },
  );

  test('applies the selected palette to both terminal renderers', () async {
    final scheme = TerminalColorSchemes.catppuccinMocha;
    final xtermAdapter = XtermTerminalSessionAdapter(colorScheme: scheme);
    final ghostty = GhosttyTerminalSessionAdapter(colorScheme: scheme);
    addTearDown(xtermAdapter.dispose);
    addTearDown(ghostty.dispose);

    final xtermView = xtermAdapter.buildView() as KeyedSubtree;
    expect(
      (xtermView.child as xterm.TerminalView).theme.background,
      scheme.background,
    );

    final ghosttyView = ghostty.buildView() as flterm.TerminalView;
    expect(ghosttyView.theme!.background, scheme.background);
    expect(ghosttyView.theme!.foreground, scheme.foreground);
    expect(
      ghosttyView.theme!.cursorMotionDuration,
      const Duration(milliseconds: 90),
    );
  });

  test('Ghostty adapter encodes cursor keys for the remote shell', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendKey(flterm.Key.arrowUp);

    expect(utf8.decode(await output), '\u001b[A');
    await adapter.dispose();
  });

  test('Ghostty adapter encodes backspace for the remote shell', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendKey(flterm.Key.backspace);

    expect(utf8.decode(await output), '\u007f');
    await adapter.dispose();
  });

  testWidgets('Ghostty adapter renders with flterm and reports its grid size', (
    tester,
  ) async {
    final adapter = GhosttyTerminalSessionAdapter();
    final resizes = <TerminalResize>[];
    final subscription = adapter.resizeEvents.listen(resizes.add);
    addTearDown(subscription.cancel);
    addTearDown(adapter.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 800, height: 600, child: adapter.buildView()),
      ),
    );
    await tester.pump();

    expect(find.byType(flterm.TerminalView), findsOneWidget);
    expect(resizes, isNotEmpty);
    expect(resizes.last.columns, greaterThan(0));
    expect(resizes.last.rows, greaterThan(0));
  });

  test('Ghostty adapter sends terminal control sequences', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendInput('\u0003\t\u001b');

    expect(utf8.decode(await output), '\u0003\t\u001b');
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
    await Future<void>.delayed(const Duration(milliseconds: 12));

    expect(adapter.received, [
      Uint8List.fromList([1, 2, 3]),
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

  @override
  void sendInput(String text) =>
      _outgoing.add(Uint8List.fromList(utf8.encode(text)));
}
