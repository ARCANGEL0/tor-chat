import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class TorHiddenService {
  static const MethodChannel _methodChannel = MethodChannel('tor_hidden_service');
  static const EventChannel _eventChannel = EventChannel('tor_hidden_service/logs');
  static const int _torHttpProxyPort = 9080;

  /// Stream of Tor log lines.
  static Stream<String> get onLog {
    return _eventChannel.receiveBroadcastStream().cast<String>();
  }

  /// Starts the Tor process with the given hidden services.
  /// If [services] is empty, Tor acts as a pure SOCKS client.
  /// Each service needs a [roomId] (used as stable directory name) and [port].
  /// Returns a list of .onion addresses for each service.
  static Future<List<String>> startTor({
    required List<Map<String, dynamic>> services,
    bool useBridges = false,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('startTor', {
        'services': services,
        'useBridges': useBridges,
      });
      return List<String>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to start Tor: ${e.message}');
    }
  }

  /// Stops the Tor process.
  static Future<void> stop() async {
    await _methodChannel.invokeMethod('stopTor');
  }

  /// Gets the Tor version string.
  static Future<String?> getTorVersion() async {
    try {
      return await _methodChannel.invokeMethod('getTorVersion') as String?;
    } on PlatformException catch (_) {
      return null;
    }
  }

  /// Reads the Tor log file.
  static Future<String?> readTorLog() async {
    try {
      return await _methodChannel.invokeMethod('readTorLog') as String?;
    } on PlatformException catch (_) {
      return null;
    }
  }

  /// Gets the .onion address for the first (legacy) hidden service.
  static Future<String?> getOnionHostname() async {
    try {
      return await _methodChannel.invokeMethod('getHostname');
    } on PlatformException catch (_) {
      return null;
    }
  }

  HttpClient getSecureTorClient() {
    final client = HttpClient();
    client.findProxy = (uri) => "PROXY localhost:$_torHttpProxyPort";
    client.connectionTimeout = const Duration(seconds: 30);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }

  TorOnionClient getUnsecureTorClient() {
    return TorOnionClient(proxyPort: _torHttpProxyPort);
  }
}

class TorOnionClient {
  final int proxyPort;

  TorOnionClient({required this.proxyPort});

  Future<TorResponse> get(String url, {Map<String, String>? headers}) async {
    return _send('GET', url, headers: headers);
  }

  Future<TorResponse> post(String url, {Map<String, String>? headers, String? body}) async {
    return _send('POST', url, headers: headers, body: body);
  }

  Future<TorResponse> _send(String method, String url, {
    Map<String, String>? headers,
    String? body
  }) async {
    Socket? socket;
    try {
      final uri = Uri.parse(url);

      socket = await Socket.connect('127.0.0.1', proxyPort, timeout: const Duration(seconds: 20));

      final targetPort = uri.port == 0 ? 80 : uri.port;
      final handshake = 'CONNECT ${uri.host}:$targetPort HTTP/1.1\r\n'
                        'Host: ${uri.host}:$targetPort\r\n'
                        '\r\n';
      socket.write(handshake);
      await socket.flush();

      final responseCompleter = Completer<TorResponse>();
      final buffer = <int>[]; // Raw byte buffer
      bool handshakeComplete = false;

      socket.listen((data) {
        buffer.addAll(data);

        if (!handshakeComplete) {
          // Decode loosely just to check headers
          final tempString = utf8.decode(buffer, allowMalformed: true);

          if (tempString.contains('\r\n\r\n')) {
            if (tempString.contains(' 200 ')) {
              // Clear buffer of proxy handshake garbage
              buffer.clear();
              handshakeComplete = true;
              _writeHttpRequest(socket!, method, uri, headers, body);
            } else {
              socket!.destroy();
              if (!responseCompleter.isCompleted) {
                responseCompleter.completeError("Proxy Handshake Failed");
              }
            }
          }
        }
      }, onDone: () {
        if (handshakeComplete && !responseCompleter.isCompleted) {
          // Pass raw bytes to parser
          responseCompleter.complete(_parseRawResponse(Uint8List.fromList(buffer)));
        } else if (!responseCompleter.isCompleted) {
          responseCompleter.completeError("Connection closed early");
        }
      }, onError: (e) {
        if (!responseCompleter.isCompleted) responseCompleter.completeError(e);
      });

      return await responseCompleter.future;

    } catch (e) {
      socket?.destroy();
      throw Exception("Tor Request Failed: $e");
    }
  }

  void _writeHttpRequest(Socket socket, String method, Uri uri, Map<String, String>? headers, String? body) {
    final path = uri.path.isEmpty ? "/" : uri.path + (uri.hasQuery ? "?${uri.query}" : "");
    final sb = StringBuffer();

    sb.write('$method $path HTTP/1.1\r\n');
    sb.write('Host: ${uri.host}\r\n');
    sb.write('Connection: close\r\n');
    sb.write('Accept-Encoding: identity\r\n');

    headers?.forEach((key, value) {
      if (key.toLowerCase() != 'content-length') {
        sb.write('$key: $value\r\n');
      }
    });

    List<int>? bodyBytes;
    if (body != null) {
      bodyBytes = utf8.encode(body);
      sb.write('Content-Length: ${bodyBytes.length}\r\n');
      if (headers == null || !headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
        sb.write('Content-Type: application/json\r\n');
      }
    }

    sb.write('\r\n');
    socket.write(sb.toString());

    if (bodyBytes != null) {
      socket.add(bodyBytes);
    }
    socket.flush();
  }

  TorResponse _parseRawResponse(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return TorResponse(statusCode: 500, body: "", bodyBytes: Uint8List(0), headers: {});

    // Find the header/body separator (\r\n\r\n) in raw bytes
    int splitIndex = -1;
    for (int i = 0; i < rawBytes.length - 3; i++) {
      if (rawBytes[i] == 13 && rawBytes[i+1] == 10 && rawBytes[i+2] == 13 && rawBytes[i+3] == 10) {
        splitIndex = i;
        break;
      }
    }

    if (splitIndex == -1) {
      // Fallback: convert everything to string (might be error message)
      final str = utf8.decode(rawBytes, allowMalformed: true);
      return TorResponse(statusCode: 500, body: str, bodyBytes: rawBytes, headers: {});
    }

    // Decode Headers only
    final headerBytes = rawBytes.sublist(0, splitIndex);
    final headerString = utf8.decode(headerBytes, allowMalformed: true);

    // Body is everything after \r\n\r\n
    final bodyBytes = rawBytes.sublist(splitIndex + 4);
    // Lazily decode string body for JSON users, but keep bytes for file users
    final bodyString = utf8.decode(bodyBytes, allowMalformed: true);

    final statusLine = headerString.split('\r\n')[0];
    final parts = statusLine.split(' ');
    final statusCode = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return TorResponse(
      statusCode: statusCode,
      body: bodyString,     // For JSON
      bodyBytes: bodyBytes, // For Files
      headers: {},
    );
  }
}

class TorResponse {
  final int statusCode;
  final String body;
  final Uint8List bodyBytes;
  final Map<String, String> headers;

  TorResponse({
    required this.statusCode,
    required this.body,
    required this.bodyBytes,
    required this.headers,
  });

  @override
  String toString() => 'TorResponse($statusCode, bytes: ${bodyBytes.length})';
}