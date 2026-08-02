import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'socks5_client.dart';

/// Minimal HTTP/1.1 client that runs through Tor's SOCKS proxy, used to push
/// and pull shared media to/from the room host. The media never leaves the
/// Tor network — the host's phone is the server.
class SocksHttp {
  final String socksHost;
  final int socksPort;
  final String targetHost;
  final int targetPort;
  final String roomKey;

  SocksHttp({
    required this.socksHost,
    required this.socksPort,
    required this.targetHost,
    required this.targetPort,
    required this.roomKey,
  });

  /// POSTs [body] to `path`. Returns the response body.
  Future<Uint8List> upload({
    required String path,
    required Uint8List body,
    required String contentType,
    String? name,
  }) async {
    final headers = <String, String>{
      'Content-Type': contentType,
      'Content-Length': '${body.length}',
      'X-Room-Key': roomKey,
      if (name != null && name.isNotEmpty) 'X-Media-Name': name,
    };
    return (await _exchange('POST', path, headers, body)).body;
  }

  /// GETs `path`. Returns the response body.
  Future<Uint8List> get(String path) async {
    return (await _exchange('GET', path, const {'X-Room-Key': ''}, null)).body;
  }

  Future<({int status, Uint8List body})> _exchange(
    String method,
    String path,
    Map<String, String> headers,
    Uint8List? body,
  ) async {
    final socks = Socks5Client(proxyHost: socksHost, proxyPort: socksPort);
    final conn = await socks.connect(
      targetHost,
      targetPort,
      timeout: const Duration(seconds: 60),
    );
    final socket = conn.socket;
    final request = StringBuffer()
      ..write('$method $path HTTP/1.1\r\n')
      ..write('Host: $targetHost\r\n')
      ..write('Connection: close\r\n');
    final allHeaders = {'X-Room-Key': roomKey, ...headers};
    for (final e in allHeaders.entries) {
      request.write('${e.key}: ${e.value}\r\n');
    }
    request.write('\r\n');

    final buf = BytesBuilder();
    final completer = Completer<void>();
    late int status;
    late Uint8List responseBody;
    var done = false;

    void onData(List<int> chunk) {
      if (done) return;
      buf.add(chunk);
      final bytes = buf.toBytes();
      final headerEnd = _findHeaderEnd(bytes);
      if (headerEnd < 0) return;
      final headerText =
          utf8.decode(bytes.sublist(0, headerEnd), allowMalformed: true);
      final lines = headerText.split('\r\n');
      final parts = lines.first.split(' ');
      status = parts.length >= 2 ? int.tryParse(parts[1]) ?? 0 : 0;
      var contentLength = 0;
      for (final line in lines.skip(1)) {
        if (line.toLowerCase().startsWith('content-length:')) {
          contentLength =
              int.tryParse(line.substring(line.indexOf(':') + 1).trim()) ?? 0;
        }
      }
      final bodyStart = headerEnd + 4;
      if (bytes.length >= bodyStart + contentLength) {
        responseBody = Uint8List.fromList(
          bytes.sublist(bodyStart, bodyStart + contentLength),
        );
        done = true;
        if (!completer.isCompleted) completer.complete();
      }
    }

    final sub = conn.stream.listen(
      onData,
      onError: (Object e) {
        if (!done && !completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!done && !completer.isCompleted) {
          completer.completeError(
            const SocketException('Media HTTP connection closed early'),
          );
        }
      },
    );

    try {
      socket.add(utf8.encode(request.toString()));
      if (body != null) socket.add(body);
      await socket.flush();

      final timer = Timer(const Duration(minutes: 10), () {
        if (!done && !completer.isCompleted) {
          completer.completeError(
            const SocketException('Media HTTP timed out'),
          );
        }
      });
      try {
        await completer.future;
      } finally {
        timer.cancel();
      }

      if (status >= 400) {
        throw SocketException('Host returned HTTP $status');
      }
      return (status: status, body: responseBody);
    } finally {
      sub.cancel();
      try {
        socket.destroy();
      } catch (_) {}
    }
  }

  static int _findHeaderEnd(Uint8List bytes) {
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 0x0d &&
          bytes[i + 1] == 0x0a &&
          bytes[i + 2] == 0x0d &&
          bytes[i + 3] == 0x0a) {
        return i;
      }
    }
    return -1;
  }
}
