import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailscale/tailscale.dart';

import 'package:maid_kit/servers/tailscale_ssh_socket.dart';

void main() {
  group('isTailnetAddress', () {
    test('accepts addresses in the CGNAT range 100.64.0.0/10', () {
      expect(isTailnetAddress('100.64.0.1'), isTrue);
      expect(isTailnetAddress('100.64.0.0'), isTrue);
      expect(isTailnetAddress('100.127.255.255'), isTrue);
    });

    test('rejects addresses outside the CGNAT range', () {
      expect(isTailnetAddress('100.63.255.255'), isFalse);
      expect(isTailnetAddress('100.128.0.1'), isFalse);
      expect(isTailnetAddress('192.168.1.10'), isFalse);
      expect(isTailnetAddress('10.0.0.1'), isFalse);
    });

    test('accepts the Tailscale IPv6 ULA prefix fd7a:115c:a1e0::/48', () {
      expect(isTailnetAddress('fd7a:115c:a1e0::1'), isTrue);
      expect(isTailnetAddress('fd7a:115c:a1e0:0:1:2:3:4'), isTrue);
    });

    test('rejects other IPv6 addresses', () {
      expect(isTailnetAddress('::1'), isFalse);
      expect(isTailnetAddress('fd7a:115c:a1e1::1'), isFalse);
    });

    test('accepts MagicDNS names', () {
      expect(isTailnetAddress('my-node.tailnet.ts.net'), isTrue);
      expect(isTailnetAddress('node.example.ts.net'), isTrue);
    });

    test('rejects ordinary hostnames', () {
      expect(isTailnetAddress('example.com'), isFalse);
      expect(isTailnetAddress('my-node'), isFalse);
    });
  });

  group('TailscaleSshSocket', () {
    test('forwards reads from the tailnet connection', () async {
      final connection = _FakeConnection();
      final socket = TailscaleSshSocket(connection);
      final received = <Uint8List>[];
      final subscription = socket.stream.listen(received.add);
      connection.inputController.add(utf8.encode('hello'));
      await Future<void>.delayed(Duration.zero);
      expect(utf8.decode(received.single), 'hello');
      await subscription.cancel();
    });

    test('forwards writes through the output half', () async {
      final connection = _FakeConnection();
      final socket = TailscaleSshSocket(connection);
      socket.sink.add(utf8.encode('ping'));
      await Future<void>.delayed(Duration.zero);
      expect(utf8.decode(connection.writes.single), 'ping');
    });

    test('close propagates to the connection', () async {
      final connection = _FakeConnection();
      final socket = TailscaleSshSocket(connection);
      var done = false;
      unawaited(socket.done.then((_) => done = true));
      await socket.close();
      expect(connection.closed, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('destroy aborts the connection', () async {
      final connection = _FakeConnection();
      final socket = TailscaleSshSocket(connection);
      socket.destroy();
      expect(connection.aborted, isTrue);
    });
  });
}

class _FakeConnection implements TailscaleConnection {
  final inputController = StreamController<Uint8List>();
  final _done = Completer<void>();
  final writes = <List<int>>[];
  var closed = false;
  var aborted = false;

  @override
  TailscaleEndpoint get local =>
      const TailscaleEndpoint(address: '100.64.0.2', port: 0);

  @override
  TailscaleEndpoint get remote =>
      const TailscaleEndpoint(address: '100.64.0.1', port: 22);

  @override
  TailscaleNodeIdentity? get identity => null;

  @override
  Stream<Uint8List> get input => inputController.stream;

  @override
  TailscaleConnectionOutput get output => _FakeOutput(this);

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> abort() async {
    aborted = true;
    if (!_done.isCompleted) _done.complete();
  }
}

class _FakeOutput implements TailscaleConnectionOutput {
  _FakeOutput(this.connection);

  final _FakeConnection connection;

  @override
  Future<void> write(List<int> bytes) async {
    connection.writes.add(bytes);
  }

  @override
  Future<void> writeAll(Stream<List<int>> chunks, {bool close = false}) async {
    await for (final chunk in chunks) {
      connection.writes.add(chunk);
    }
    if (close) await this.close();
  }

  @override
  Future<void> close() async {
    connection.closed = true;
  }

  @override
  Future<void> get done => Future.value();
}
