import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// The result of a successful SOCKS5 handshake: the raw [socket] (used for
/// writes) and a [stream] that yields every byte that arrives after the SOCKS
/// reply (used for the WebSocket upgrade). Both views share a single
/// subscription, so no bytes are ever lost or duplicated.
class SocksConnection {
  final Socket socket;
  final Stream<List<int>> stream;
  SocksConnection(this.socket, this.stream);
}

/// Minimal SOCKS5 client that opens a TCP stream to a host through Tor's
/// local SOCKS proxy (127.0.0.1:9050 on Android).
class Socks5Client {
  final String proxyHost;
  final int proxyPort;

  Socks5Client({required this.proxyHost, required this.proxyPort});

  /// Establishes a SOCKS5 connection to [targetHost]:[targetPort]. DNS
  /// resolution happens on the proxy side so onion addresses are resolved by
  /// Tor itself.
  Future<SocksConnection> connect(String targetHost, int targetPort,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('[SOCKS] connect $targetHost:$targetPort via $proxyHost:$proxyPort (${timeout.inSeconds}s timeout)');
    final socket = await Socket.connect(proxyHost, proxyPort, timeout: timeout);
    final reader = _SocksReader(socket);
    try {
      // --- greeting: version 5, no auth ---
      socket.add([0x05, 0x01, 0x00]);
      await socket.flush();

      final greeting = await reader.readExact(2, timeout: timeout);
      debugPrint('[SOCKS] greeting reply ${greeting.map((b) => b.toRadixString(16)).join(' ')} after ${stopwatch.elapsedMilliseconds}ms');
      if (greeting[0] != 0x05) {
        throw const SocketException('SOCKS: bad version in greeting');
      }
      if (greeting[1] == 0xff) {
        throw const SocketException('SOCKS: no acceptable auth method');
      }

      // --- connect request ---
      final hostBytes = _encodeHost(targetHost);
      final request = BytesBuilder()
        ..addByte(0x05) // version
        ..addByte(0x01) // CONNECT
        ..addByte(0x00) // reserved
        ..add(hostBytes)
        ..addByte((targetPort >> 8) & 0xff)
        ..addByte(targetPort & 0xff);
      socket.add(request.toBytes());
      await socket.flush();

      final reply = await reader.readExact(4, timeout: timeout);
      debugPrint('[SOCKS] connect reply ${reply.map((b) => b.toRadixString(16)).join(' ')} after ${stopwatch.elapsedMilliseconds}ms');
      if (reply[0] != 0x05) {
        throw const SocketException('SOCKS: bad version in reply');
      }
      if (reply[1] != 0x00) {
        throw SocketException(_socksError(reply[1], targetHost));
      }
      // Skip the bound address (we do not need it).
      final atyp = reply[3];
      final toSkip = switch (atyp) {
        0x01 => 6, // IPv4 + port
        0x04 => 18, // IPv6 + port
        _ => null,
      };
      if (toSkip != null) {
        await reader.readExact(toSkip, timeout: timeout);
      } else {
        final lenByte = await reader.readExact(1, timeout: timeout);
        await reader.readExact(lenByte[0] + 2, timeout: timeout);
      }
      debugPrint('[SOCKS] connected in ${stopwatch.elapsedMilliseconds}ms');
      return SocksConnection(socket, reader.takeOver());
    } catch (e) {
      debugPrint('[SOCKS] FAILED after ${stopwatch.elapsedMilliseconds}ms: $e');
      socket.destroy();
      rethrow;
    }
  }

  Uint8List _encodeHost(String host) {
    final ipv4 = InternetAddress.tryParse(host);
    if (ipv4 != null && ipv4.type == InternetAddressType.IPv4) {
      return Uint8List.fromList([0x01, ...ipv4.rawAddress]);
    }
    final ipv6 = InternetAddress.tryParse(host);
    if (ipv6 != null && ipv6.type == InternetAddressType.IPv6) {
      return Uint8List.fromList([0x04, ...ipv6.rawAddress]);
    }
    final bytes = utf8.encode(host);
    return Uint8List.fromList([0x03, bytes.length, ...bytes]);
  }

  /// Maps a SOCKS5 reply code to a human-readable message. Code 4 (host
  /// unreachable) is by far the most common for .onion targets: it means Tor
  /// could not find or reach the hidden service.
  String _socksError(int code, String target) {
    final reason = switch (code) {
      1 => 'general SOCKS server failure',
      2 => 'connection not allowed by ruleset',
      3 => 'network unreachable',
      4 => 'host unreachable',
      5 => 'connection refused',
      6 => 'TTL expired',
      7 => 'command not supported',
      8 => 'address type not supported',
      _ => 'unknown error ($code)',
    };
    if (target.endsWith('.onion')) {
      return 'SOCKS: $reason — Tor could not reach that hidden service. '
          'The host may be offline, the room may have just restarted (descriptor '
          'takes up to a minute to propagate), or the namecode/password don\'t '
          'match the room.';
    }
    return 'SOCKS: $reason for $target';
  }
}

/// Owns the socket's single subscription during the SOCKS handshake, then
/// hands the remaining byte stream over to the caller via [takeOver].
class _SocksReader {
  final Socket socket;
  final BytesBuilder _buf = BytesBuilder();
  final _waiters = <_ReadRequest>[];
  bool _closed = false;
  Object? _error;

  final _stream = StreamController<List<int>>();
  bool _handedOff = false;

  _SocksReader(this.socket) {
    socket.listen((data) {
      if (_handedOff) {
        _stream.add(data);
        return;
      }
      _buf.add(data);
      _pump();
    }, onError: (Object e) {
      _closed = true;
      _error = e;
      _flushWaiters();
      if (_handedOff && !_stream.isClosed) _stream.addError(e);
    }, onDone: () {
      _closed = true;
      _flushWaiters();
      if (_handedOff && !_stream.isClosed) _stream.close();
    });
  }

  void _pump() {
    while (_waiters.isNotEmpty) {
      final req = _waiters.first;
      final bytes = _buf.toBytes();
      if (bytes.length < req.length) break;
      _waiters.removeAt(0);
      req.timer.cancel();
      final result = Uint8List.fromList(bytes.sublist(0, req.length));
      _buf.clear();
      if (bytes.length > req.length) _buf.add(bytes.sublist(req.length));
      if (!req.completer.isCompleted) req.completer.complete(result);
    }
  }

  void _flushWaiters() {
    for (final req in _waiters) {
      req.timer.cancel();
      if (!req.completer.isCompleted) {
        req.completer.completeError(_error ?? const SocketException('SOCKS: closed early'));
      }
    }
    _waiters.clear();
  }

  Future<Uint8List> readExact(int length,
      {Duration timeout = const Duration(seconds: 30)}) {
    final bytes = _buf.toBytes();
    if (bytes.length >= length) {
      final result = Uint8List.fromList(bytes.sublist(0, length));
      _buf.clear();
      if (bytes.length > length) _buf.add(bytes.sublist(length));
      return Future.value(result);
    }
    if (_closed) {
      return Future.error(_error ?? const SocketException('SOCKS: closed'));
    }

    final completer = Completer<Uint8List>();
    final timer = Timer(timeout, () {
      _waiters.removeWhere((r) => identical(r.completer, completer));
      if (!completer.isCompleted) {
        completer.completeError(const SocketException('SOCKS: read timeout'));
      }
    });
    _waiters.add(_ReadRequest(completer, timer, length));
    return completer.future;
  }

  /// After the SOCKS handshake, the socket's subscription starts feeding
  /// [stream]. The caller must listen to it immediately.
  Stream<List<int>> takeOver() {
    _handedOff = true;
    final pending = _buf.toBytes();
    if (pending.isNotEmpty) {
      _buf.clear();
      // Replay bytes that arrived while waiting for the handshake reply but
      // were not yet consumed (should not happen, but stay safe).
      _stream.add(pending);
    }
    return _stream.stream;
  }
}

class _ReadRequest {
  final Completer<Uint8List> completer;
  final Timer timer;
  final int length;
  _ReadRequest(this.completer, this.timer, this.length);
}
