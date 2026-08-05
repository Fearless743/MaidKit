import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'server_models.dart';

/// Registration state of the platform serial bridge helper.
enum SerialBridgeStatus {
  /// The helper is registered and can open serial sessions.
  enabled,

  /// The helper is registered but needs approval in System Settings.
  requiresApproval,

  /// The helper is not registered as a login/launch item.
  notRegistered,

  /// The helper binary could not be located.
  notFound,

  /// Serial ports are not supported on this platform.
  unsupported,

  /// The platform reported an error or an unexpected status.
  error,
}

/// A failure talking to the serial bridge helper.
class SerialBridgeException implements Exception {
  const SerialBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A raw duplex byte session with a serial device, tunneled over loopback TCP
/// by the platform bridge helper.
///
/// Wraps a [Socket]: [bytes] carries device output, [write] sends input, and
/// [done] completes when either side closes the connection.
class SerialPortSession {
  SerialPortSession._(this._socket) {
    _data = StreamController<Uint8List>();
    _subscription = _socket.listen(
      _onChunk,
      onDone: _onSocketClosed,
      onError: _onSocketError,
    );
  }

  /// Handshake replies never exceed a single short line; anything larger
  /// indicates a broken helper rather than a legitimately huge device stream.
  static const _maxHandshakeLineLength = 4096;

  final Socket _socket;
  late final StreamController<Uint8List> _data;
  late final StreamSubscription<Uint8List> _subscription;

  /// Bytes received while the handshake is still in flight. Once the handshake
  /// completes, leftover bytes are delivered before any live traffic.
  final BytesBuilder _handshakeBuffer = BytesBuilder(copy: false);

  /// Wakes [readHandshakeLine] when new data arrives or the socket closes.
  Completer<void>? _dataSignal;
  Object? _handshakeError;
  var _socketClosed = false;
  var _handshakeComplete = false;

  /// Bytes received from the serial device.
  Stream<Uint8List> get bytes => _data.stream;

  /// Sends [data] to the serial device.
  void write(List<int> data) => _socket.add(data);

  /// Closes the session and releases the underlying socket.
  Future<void> close() async {
    // The peer may have already reset the connection by the time teardown
    // runs. Ensure the done future never surfaces an unhandled error from a
    // discarded session; other listeners (e.g. the connection manager) still
    // receive it independently.
    unawaited(_socket.done.catchError((_) {}));
    _completeDone();
    await _subscription.cancel();
    // The terminal binding cancels its subscription before closing the
    // session, so the controller usually has no listener left. A
    // single-subscription controller's close future only completes once a
    // listener drains it, so never await it here.
    if (!_data.isClosed) unawaited(_data.close());
    try {
      // A graceful close can hang indefinitely when the peer already closed
      // or reset the connection, so bound it and destroy as a fallback.
      await _socket.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      _socket.destroy();
    }
  }

  /// Completes when the underlying socket closes, for either side.
  ///
  /// dart:io's `Socket.done` only completes after the local side closes, so a
  /// peer-initiated FIN (e.g. the helper dropping the connection when the
  /// device goes away) would never surface. The socket listener's onDone /
  /// onError fire on both peer-close and local-close, so [done] is driven from
  /// those instead.
  final Completer<void> _doneCompleter = Completer<void>();

  Future<void> get done => _doneCompleter.future;

  void _completeDone() {
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }

  // Handshake support used by [SerialBridgeClient] (same library). The socket
  // stream is single-subscription, so the session owns the one subscription
  // and the client pulls newline-delimited replies out of its buffer.

  /// Waits for the next newline-terminated handshake reply.
  ///
  /// Any bytes that arrive after the newline stay buffered and are delivered
  /// through [bytes] once [finishHandshake] is called.
  Future<String> readHandshakeLine(DateTime deadline) async {
    while (true) {
      final bytes = _handshakeBuffer.toBytes();
      final newline = bytes.indexOf(0x0A);
      if (newline >= 0) {
        final line = utf8.decode(
          bytes.sublist(0, newline),
          allowMalformed: true,
        );
        final rest = bytes.sublist(newline + 1);
        _handshakeBuffer.clear();
        if (rest.isNotEmpty) _handshakeBuffer.add(rest);
        return line.trimRight();
      }
      if (bytes.length > _maxHandshakeLineLength) {
        throw const SerialBridgeException(
          'Serial bridge handshake response exceeded 4096 bytes.',
        );
      }
      final error = _handshakeError;
      if (error != null) {
        throw SerialBridgeException(
          'The serial bridge connection failed during handshake: $error',
        );
      }
      if (_socketClosed) {
        throw const SerialBridgeException(
          'The serial bridge closed the connection during the handshake.',
        );
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw const SerialBridgeException(
          'Timed out during the serial bridge handshake.',
        );
      }
      _dataSignal ??= Completer<void>();
      final signal = _dataSignal!;
      try {
        await signal.future.timeout(remaining);
      } on TimeoutException {
        throw const SerialBridgeException(
          'Timed out during the serial bridge handshake.',
        );
      }
    }
  }

  /// Ends the handshake phase. Buffered device bytes are emitted before any
  /// subsequent traffic.
  void finishHandshake() {
    _handshakeComplete = true;
    final leftover = _handshakeBuffer.takeBytes();
    if (leftover.isNotEmpty) _data.add(leftover);
  }

  void _onChunk(Uint8List chunk) {
    if (_handshakeComplete) {
      _data.add(chunk);
      return;
    }
    _handshakeBuffer.add(chunk);
    final signal = _dataSignal;
    if (signal != null) {
      _dataSignal = null;
      signal.complete();
    }
  }

  void _onSocketClosed() {
    _socketClosed = true;
    _completeDone();
    final signal = _dataSignal;
    _dataSignal = null;
    if (signal != null && !signal.isCompleted) signal.complete();
    if (!_data.isClosed) _data.close();
  }

  void _onSocketError(Object error, StackTrace stack) {
    _completeDone();
    if (_handshakeComplete) {
      if (!_data.isClosed) _data.addError(error, stack);
      return;
    }
    _handshakeError = error;
    final signal = _dataSignal;
    _dataSignal = null;
    if (signal != null && !signal.isCompleted) signal.complete();
  }
}

/// Client for the platform serial bridge helper.
///
/// The helper (an unsandboxed LaunchAgent on macOS) publishes a rendezvous
/// file with a loopback TCP port and an auth token, then speaks a tiny
/// newline-delimited handshake before tunneling raw device bytes.
class SerialBridgeClient {
  static const channelName = 'dev.solsynth.maidKit/serial_bridge';

  static const _rendezvousFileName = 'serial-bridge.json';
  static const _rendezvousPollInterval = Duration(milliseconds: 250);
  static const _rendezvousTimeout = Duration(seconds: 10);
  static const _handshakeTimeout = Duration(seconds: 10);
  static const _connectTimeout = Duration(seconds: 5);

  final MethodChannel _channel = const MethodChannel(channelName);

  /// Cached so registration is not re-invoked on every open.
  SerialBridgeStatus? _registrationStatus;

  /// Ensures the bridge helper is registered and reports its status. The
  /// result is cached for the lifetime of this client.
  Future<SerialBridgeStatus> ensureRegistered() async {
    final cached = _registrationStatus;
    if (cached != null) return cached;
    SerialBridgeStatus status;
    try {
      final result = await _channel.invokeMethod<String>('ensureRegistered');
      status = _statusFromPlatform(result);
    } on PlatformException {
      status = SerialBridgeStatus.error;
    }
    _registrationStatus = status;
    return status;
  }

  /// Opens System Settings → Login Items so the user can approve the helper.
  Future<void> openLoginItemsSettings() async {
    await _channel.invokeMethod<void>('openLoginItemsSettings');
  }

  /// Lists serial devices the bridge helper can open (e.g. /dev/cu.* on
  /// macOS). Throws [SerialBridgeException] when the helper is unavailable or
  /// rejects the handshake.
  Future<List<String>> listDevices() async {
    final status = await ensureRegistered();
    _throwIfUnavailable(status);

    final rendezvous = await _waitForRendezvous();
    try {
      return await _listDevices(rendezvous);
    } on SocketException {
      // The helper may have restarted with a new port after our first read.
      final refreshed = await _readRendezvousFile();
      if (refreshed == null) rethrow;
      return await _listDevices(refreshed);
    }
  }

  /// Opens a raw byte session with [config]'s serial device.
  ///
  /// Throws [SerialBridgeException] when the helper is unavailable, cannot be
  /// reached, or rejects the handshake.
  Future<SerialPortSession> open(SerialConfig config) async {
    final status = await ensureRegistered();
    _throwIfUnavailable(status);

    final rendezvous = await _waitForRendezvous();
    try {
      return await _connectAndHandshake(rendezvous, config);
    } on SocketException {
      // The helper may have restarted with a new port after our first read.
      final refreshed = await _readRendezvousFile();
      if (refreshed == null) rethrow;
      return await _connectAndHandshake(refreshed, config);
    }
  }

  /// Authenticates a fresh connection with the helper's token.
  Future<SerialPortSession> _connectAndAuth(_RendezvousInfo rendezvous) async {
    final socket = await Socket.connect(
      '127.0.0.1',
      rendezvous.port,
      timeout: _connectTimeout,
    );
    final session = SerialPortSession._(socket);
    try {
      final deadline = DateTime.now().add(_handshakeTimeout);
      session.write(utf8.encode('AUTH ${rendezvous.token}\n'));
      final authReply = await session.readHandshakeLine(deadline);
      if (authReply != 'OK') {
        throw SerialBridgeException(_rejectReason('AUTH', authReply));
      }
      return session;
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  Future<List<String>> _listDevices(_RendezvousInfo rendezvous) async {
    final session = await _connectAndAuth(rendezvous);
    try {
      final deadline = DateTime.now().add(_handshakeTimeout);
      session.write(utf8.encode('LIST\n'));
      final reply = await session.readHandshakeLine(deadline);
      if (!reply.startsWith('LIST ')) {
        throw SerialBridgeException(_rejectReason('LIST', reply));
      }
      final decoded = jsonDecode(reply.substring('LIST '.length));
      if (decoded is! List) {
        throw const SerialBridgeException(
          'Serial bridge returned an invalid device list.',
        );
      }
      return decoded.whereType<String>().toList();
    } finally {
      // The helper closes the connection after a LIST reply; release the
      // session either way.
      await session.close();
    }
  }

  Future<SerialPortSession> _connectAndHandshake(
    _RendezvousInfo rendezvous,
    SerialConfig config,
  ) async {
    final session = await _connectAndAuth(rendezvous);
    try {
      final deadline = DateTime.now().add(_handshakeTimeout);
      session.write(utf8.encode('OPEN ${jsonEncode(config.toJson())}\n'));
      final openReply = await session.readHandshakeLine(deadline);
      if (openReply != 'OK') {
        throw SerialBridgeException(_rejectReason('OPEN', openReply));
      }
    } catch (_) {
      await session.close();
      rethrow;
    }
    session.finishHandshake();
    return session;
  }

  String _rejectReason(String step, String reply) {
    if (reply.startsWith('ERR ')) return reply.substring(4);
    return 'Serial bridge rejected $step: $reply';
  }

  /// Polls the rendezvous file until the helper publishes its port (up to
  /// ~10 seconds), then returns the parsed port and token.
  Future<_RendezvousInfo> _waitForRendezvous() async {
    final deadline = DateTime.now().add(_rendezvousTimeout);
    while (true) {
      final rendezvous = await _readRendezvousFile();
      if (rendezvous != null) return rendezvous;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw const SerialBridgeException(
          'Timed out waiting for the serial bridge helper to publish its '
          'port. Make sure the MaidKit helper is installed and running.',
        );
      }
      await Future<void>.delayed(_rendezvousPollInterval);
    }
  }

  /// One attempt at reading and parsing the rendezvous file. Returns null when
  /// the file is missing, mid-write, or malformed.
  Future<_RendezvousInfo?> _readRendezvousFile() async {
    try {
      final support = await getApplicationSupportDirectory();
      final file = File('${support.path}/$_rendezvousFileName');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final port = decoded['port'];
      final token = decoded['token'];
      if (port is int && token is String && token.isNotEmpty) {
        return _RendezvousInfo(port: port, token: token);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _throwIfUnavailable(SerialBridgeStatus status) {
    switch (status) {
      case SerialBridgeStatus.enabled:
        return;
      case SerialBridgeStatus.requiresApproval:
        throw const SerialBridgeException(
          'The serial bridge helper needs approval. Enable it under '
          'System Settings → General → Login Items & Extensions, then try '
          'again.',
        );
      case SerialBridgeStatus.notRegistered:
        throw const SerialBridgeException(
          'The serial bridge helper is not registered. Reinstall or relaunch '
          'the MaidKit helper to use serial ports.',
        );
      case SerialBridgeStatus.notFound:
        throw const SerialBridgeException(
          'The serial bridge helper could not be found on this device.',
        );
      case SerialBridgeStatus.unsupported:
        throw const SerialBridgeException(
          'Serial ports are not supported on this device.',
        );
      case SerialBridgeStatus.error:
        throw const SerialBridgeException(
          'The serial bridge helper is unavailable. Check that the MaidKit '
          'helper app is installed.',
        );
    }
  }

  SerialBridgeStatus _statusFromPlatform(String? value) {
    switch (value) {
      case 'enabled':
        return SerialBridgeStatus.enabled;
      case 'requiresApproval':
        return SerialBridgeStatus.requiresApproval;
      case 'notRegistered':
        return SerialBridgeStatus.notRegistered;
      case 'notFound':
        return SerialBridgeStatus.notFound;
      case 'unsupported':
        return SerialBridgeStatus.unsupported;
      default:
        // Includes `error:<detail>` and any unexpected result.
        return SerialBridgeStatus.error;
    }
  }
}

class _RendezvousInfo {
  const _RendezvousInfo({required this.port, required this.token});

  final int port;
  final String token;
}
