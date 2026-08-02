import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import 'socks5_client.dart';

/// A minimal RFC 6455 WebSocket CLIENT implemented over a raw [Socket].
///
/// dart:io cannot run [WebSocket.connect] through a SOCKS proxy, and
/// [WebSocket.fromUpgradedSocket] cannot be used because a [Socket] is a
/// single-subscription stream that cannot be re-listened after the manual
/// handshake read. So we speak the wire protocol ourselves: one persistent
/// subscription that first parses the handshake response and then decodes
/// frames (leftover bytes are never lost).
class TorWebSocket {
  final Socket socket;
  final String host;

  final _text = StreamController<String>.broadcast();
  final _closed = StreamController<void>.broadcast();

  /// Stream of decoded text messages.
  Stream<String> get text => _text.stream;

  /// Fired exactly once when the connection closes.
  Stream<void> get closed => _closed.stream;

  final BytesBuilder _buf = BytesBuilder();
  StreamSubscription<List<int>>? _sub;
  bool _closedFlag = false;
  bool _handshakeDone = false;

  // Fragmentation state.
  String? _fragment;

  TorWebSocket._(this.socket, this.host);

  /// Performs the WebSocket upgrade handshake on an already-connected [conn]
  /// (one opened through Tor's SOCKS proxy) and returns a ready client.
  static Future<TorWebSocket> connect(SocksConnection conn, String host) async {
    final ws = TorWebSocket._(conn.socket, host);
    final key = _randomKey();
    final request = StringBuffer()
      ..write('GET / HTTP/1.1\r\n')
      ..write('Host: $host\r\n')
      ..write('Upgrade: websocket\r\n')
      ..write('Connection: Upgrade\r\n')
      ..write('Sec-WebSocket-Key: $key\r\n')
      ..write('Sec-WebSocket-Version: 13\r\n')
      ..write('\r\n');
    conn.socket.add(utf8.encode(request.toString()));
    await conn.socket.flush();
    debugPrint('[WS] handshake sent to $host, waiting for 101…');

    final completer = Completer<void>();
    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        debugPrint('[WS] handshake TIMEOUT (30s)');
        completer.completeError(const SocketException('WebSocket handshake timeout'));
      }
    });

    ws._sub = conn.stream.listen(
      (data) => ws._handleChunk(data, key, completer, timer),
      onError: (Object e) {
        timer.cancel();
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const SocketException('WebSocket handshake closed early'));
        }
        ws._teardown();
      },
    );

    await completer.future;
    return ws;
  }

  void _handleChunk(
    List<int> chunk,
    String key,
    Completer<void> completer,
    Timer timer,
  ) {
    _buf.add(chunk);
    if (!_handshakeDone) {
      final bytes = _buf.toBytes();
      final headerEnd = _findHeaderEnd(bytes);
      if (headerEnd < 0) return; // wait for more data
      final headerText = utf8.decode(bytes.sublist(0, headerEnd), allowMalformed: true);
      final status = headerText.split('\r\n').first;
      debugPrint('[WS] handshake response: $status');
      if (!status.contains(' 101 ')) {
        _fail(completer, SocketException('WebSocket upgrade failed: $status'));
        return;
      }
      final accept = _findHeader(headerText, 'sec-websocket-accept');
      if (accept != null && accept != _acceptValue(key)) {
        _fail(completer, const SocketException('WebSocket accept key mismatch'));
        return;
      }
      _handshakeDone = true;
      timer.cancel();
      final leftover = bytes.sublist(headerEnd + 4);
      _buf.clear();
      if (leftover.isNotEmpty) _buf.add(leftover);
      if (!completer.isCompleted) completer.complete();
    }
    _parseFrames();
  }

  void _fail(Completer<void> completer, Object error) {
    if (!completer.isCompleted) completer.completeError(error);
    _teardown();
  }

  // ------------------------------------------------------------------ send

  void sendText(String message) {
    final payload = utf8.encode(message);
    final header = BytesBuilder()
      ..addByte(0x81) // FIN + text opcode
      ..addByte(0x80 | _lengthCode(payload.length)); // mask bit + length
    _addLengthBytes(header, payload.length);
    final mask = _randomBytes(4);
    header.add(mask);
    for (var i = 0; i < payload.length; i++) {
      header.addByte(payload[i] ^ mask[i % 4]);
    }
    socket.add(header.toBytes());
    socket.flush();
  }

  void sendClose({int code = 1000}) {
    if (_closedFlag) return;
    final header = BytesBuilder()
      ..addByte(0x88)
      ..addByte(0x80 | 2);
    final mask = _randomBytes(4);
    header.add(mask);
    header.addByte(code >> 8 & 0xff ^ mask[0]);
    header.addByte(code & 0xff ^ mask[1]);
    socket.add(header.toBytes());
    socket.flush();
  }

  Future<void> close() async {
    sendClose();
    _teardown();
    if (!_closed.isClosed) await _closed.close();
  }

  // ------------------------------------------------------------------ frames

  void _parseFrames() {
    final bytes = _buf.toBytes();
    var offset = 0;
    final len = bytes.length;

    while (len - offset >= 2) {
      final b0 = bytes[offset];
      final b1 = bytes[offset + 1];
      final fin = (b0 & 0x80) != 0;
      final opcode = b0 & 0x0f;
      final masked = (b1 & 0x80) != 0;
      var payloadLen = b1 & 0x7f;
      var headerLen = 2;

      if (payloadLen == 126) {
        if (len - offset < 4) break;
        payloadLen = (bytes[offset + 2] << 8) | bytes[offset + 3];
        headerLen = 4;
      } else if (payloadLen == 127) {
        if (len - offset < 10) break;
        payloadLen = 0;
        for (var i = 0; i < 8; i++) {
          payloadLen = payloadLen * 256 + bytes[offset + 2 + i];
        }
        headerLen = 10;
      }

      var maskKey = const <int>[];
      if (masked) {
        if (len - offset < headerLen + 4) break;
        maskKey = bytes.sublist(offset + headerLen, offset + headerLen + 4);
        headerLen += 4;
      }

      if (len - offset < headerLen + payloadLen) break; // wait for more data

      final payload = Uint8List.fromList(
        bytes.sublist(offset + headerLen, offset + headerLen + payloadLen),
      );
      if (masked) {
        for (var i = 0; i < payload.length; i++) {
          payload[i] = payload[i] ^ maskKey[i % 4];
        }
      }

      _handleFrame(fin, opcode, payload);
      offset += headerLen + payloadLen;
    }

    if (offset > 0) {
      final rest = bytes.sublist(offset);
      _buf.clear();
      if (rest.isNotEmpty) _buf.add(rest);
    }
  }

  void _handleFrame(bool fin, int opcode, Uint8List payload) {
    switch (opcode) {
      case 0x1: // text
        final text = utf8.decode(payload, allowMalformed: true);
        if (fin) {
          _fragment = null;
          _emitText(text);
        } else {
          _fragment = (_fragment ?? '') + text;
        }
      case 0x0: // continuation
        final text = utf8.decode(payload, allowMalformed: true);
        _fragment = (_fragment ?? '') + text;
        if (fin) {
          _emitText(_fragment!);
          _fragment = null;
        }
      case 0x2: // binary — ignore
      case 0x8: // close
        sendClose();
        _teardown();
      case 0x9: // ping
        _sendPong(payload);
      case 0xa: // pong — ignore
    }
  }

  void _sendPong(Uint8List payload) {
    final header = BytesBuilder()
      ..addByte(0x8a)
      ..addByte(0x80 | payload.length);
    final mask = _randomBytes(4);
    header.add(mask);
    for (var i = 0; i < payload.length; i++) {
      header.addByte(payload[i] ^ mask[i % 4]);
    }
    socket.add(header.toBytes());
    socket.flush();
  }

  void _emitText(String text) {
    if (!_text.isClosed) _text.add(text);
  }

  // ------------------------------------------------------------------ helpers

  int _lengthCode(int len) {
    if (len < 126) return len;
    if (len <= 0xffff) return 126;
    return 127;
  }

  void _addLengthBytes(BytesBuilder header, int len) {
    if (len < 126) return;
    if (len <= 0xffff) {
      header.addByte((len >> 8) & 0xff);
      header.addByte(len & 0xff);
    } else {
      for (var shift = 56; shift >= 0; shift -= 8) {
        header.addByte((len >> shift) & 0xff);
      }
    }
  }

  static int _findHeaderEnd(Uint8List bytes) {
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 0x0d && bytes[i + 1] == 0x0a && bytes[i + 2] == 0x0d && bytes[i + 3] == 0x0a) {
        return i;
      }
    }
    return -1;
  }

  static String? _findHeader(String headerText, String name) {
    for (final line in headerText.split('\r\n').skip(1)) {
      final idx = line.indexOf(':');
      if (idx > 0 && line.substring(0, idx).trim().toLowerCase() == name) {
        return line.substring(idx + 1).trim();
      }
    }
    return null;
  }

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rng.nextInt(256)));
  }

  static String _randomKey() => base64Encode(_randomBytes(16));

  static String _acceptValue(String key) {
    const magic = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
    final digest = crypto.sha1.convert(utf8.encode('$key$magic'));
    return base64Encode(digest.bytes);
  }

  void _teardown() {
    if (_closedFlag) return;
    _closedFlag = true;
    _sub?.cancel();
    _sub = null;
    try {
      socket.destroy();
    } catch (_) {}
    if (!_closed.isClosed) _closed.add(null);
    if (!_text.isClosed) _text.close();
  }
}
