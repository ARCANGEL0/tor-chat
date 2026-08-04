import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import 'chat_protocol.dart';
import 'socks5_client.dart';
import 'socks_http.dart';
import 'tor_web_socket.dart';

/// Outbound chat connection. Opens a raw socket through Tor's SOCKS proxy,
/// upgrades it to WebSocket with [TorWebSocket], then speaks the OnionChat
/// protocol.
class ChatClient {
  final String socksHost;
  final int socksPort;
  final String targetHost;
  final int targetPort;

  TorWebSocket? _ws;
  bool _disposed = false;
  String? _password;

  final _messages = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messages => _messages.stream;

  /// Fired when the server asks for a username (i.e. auth succeeded).
  final _onPrompt = StreamController<void>.broadcast();
  Stream<void> get onPrompt => _onPrompt.stream;

  /// Fired when the server accepted our username and chat is live. Carries
  /// the full `ready` message (with the roster of existing members).
  final _onReady = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onReady => _onReady.stream;

  /// Fired when another user joins (roster update).
  final _onMember = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMember => _onMember.stream;

  /// Fired when another user changes their persona mid-chat. Carries the full
  /// `profile` message (with `oldUsername` and the updated member fields).
  final _onProfile = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onProfile => _onProfile.stream;

  /// Fired when authentication failed (wrong password).
  final _onAuthFailed = StreamController<void>.broadcast();
  Stream<void> get onAuthFailed => _onAuthFailed.stream;

  /// Fired when the host put our join on hold: entry needs approval.
  final _onPending = StreamController<void>.broadcast();
  Stream<void> get onPending => _onPending.stream;

  /// Fired when the host rejected our entry.
  final _onDenied = StreamController<void>.broadcast();
  Stream<void> get onDenied => _onDenied.stream;

  /// Fired when the host kicked us out of the room.
  final _onKicked = StreamController<void>.broadcast();
  Stream<void> get onKicked => _onKicked.stream;

  /// Fired when a message in the room was edited. Carries the new version
  /// (same [ChatMessage.id], new text).
  final _onEdit = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onEdit => _onEdit.stream;

  /// Fired when a message in the room was deleted. Carries the [ChatMessage.id].
  final _onDelete = StreamController<String>.broadcast();
  Stream<String> get onDelete => _onDelete.stream;

  /// Fired when the host wiped every photo/video in the room.
  final _onDeleteAllMedia = StreamController<void>.broadcast();
  Stream<void> get onDeleteAllMedia => _onDeleteAllMedia.stream;

  /// Fired when the host wiped every message in the room.
  final _onDeleteAllMessages = StreamController<void>.broadcast();
  Stream<void> get onDeleteAllMessages => _onDeleteAllMessages.stream;

  /// Fired when the connection closes unexpectedly.
  final _onClose = StreamController<void>.broadcast();
  Stream<void> get onClose => _onClose.stream;

  final _onError = StreamController<Object>.broadcast();
  Stream<Object> get onError => _onError.stream;

  ChatClient({
    required this.socksHost,
    required this.socksPort,
    required this.targetHost,
    required this.targetPort,
  });

  /// Quick connection test to check if an onion service exists.
  /// Returns true if connection succeeds (room exists), false otherwise.
  static Future<bool> tryConnect(
    String onionHost,
    String password, {
    Duration timeout = const Duration(seconds: 8),
    String socksHost = '127.0.0.1',
    int socksPort = 9050,
  }) async {
    try {
      final socks = Socks5Client(proxyHost: socksHost, proxyPort: socksPort);
      final conn = await socks.connect(
        onionHost,
        80, // hidden service port
        timeout: timeout,
      );
      final ws = await TorWebSocket.connect(conn, onionHost);
      ws.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get isConnected => _ws != null;

  /// Connects, performs the SOCKS + WebSocket handshake and sends [password].
  ///
  /// If password is null/empty, no auth is sent (open room).
  ///
  /// Retries for a while: right after a room is created (or its host
  /// restarts) the hidden service descriptor can take up to a minute to
  /// propagate, so the first attempts often fail with "host unreachable" even
  /// though the room is reachable moments later. We keep trying with backoff
  /// for roughly three and a half minutes before giving up.
  Future<void> connect({String? password}) async {
    if (_disposed) throw StateError('ChatClient was disposed');
    _password = password;
    Object? lastError;
    for (var attempt = 1; attempt <= 8; attempt++) {
      if (_disposed) throw StateError('ChatClient was closed');
      if (attempt > 1) {
        debugPrint('[CLIENT] attempt $attempt of 8 — waiting ${5 * attempt}s');
        await Future<void>.delayed(Duration(seconds: 5 * attempt));
      }
      if (_disposed) throw StateError('ChatClient was closed');
      try {
        debugPrint('[CLIENT] attempt $attempt of 8 → $targetHost:$targetPort');
        await _attemptConnect(password);
        debugPrint('[CLIENT] connected!');
        return;
      } catch (e) {
        lastError = e;
        debugPrint('[CLIENT] attempt $attempt FAILED: $e');
        try {
          await _ws?.close();
        } catch (_) {}
        _ws = null;
      }
    }
    debugPrint('[CLIENT] gave up after 8 attempts: $lastError');
    throw lastError!;
  }

  Future<void> _attemptConnect(String? password) async {
    if (_disposed) throw StateError('ChatClient was closed');
    final socks = Socks5Client(proxyHost: socksHost, proxyPort: socksPort);
    final conn = await socks.connect(
      targetHost,
      targetPort,
      timeout: const Duration(seconds: 40),
    );
    final ws = await TorWebSocket.connect(conn, targetHost);
    _ws = ws;
    ws.closed.listen((_) {
      // A deliberate close() (user left the room / session teardown) must not
      // surface as an unexpected disconnect.
      if (!_disposed) _onClose.add(null);
    });
    ws.text.listen(_onData);
    // Always send an auth frame so the host replies deterministically:
    // a `prompt` when the room accepts us, or `auth_failed` otherwise. Sending
    // nothing would leave both sides waiting forever (host never issues prompt).
    ws.sendText(ChatProtocol.encodeAuth(password));
  }

  void sendUsername(
    String username, {
    String? bio,
    String? avatar,
    String? avatarData,
  }) {
    _ws?.sendText(ChatProtocol.encodeUsername(
      username,
      bio: bio,
      avatar: avatar,
      avatarData: avatarData,
    ));
  }

  void sendMessage(String text, {String? id}) {
    _ws?.sendText(ChatProtocol.encodeMessage(text, id: id ?? ChatMessage.newId()));
  }

  SocksHttp _mediaHttp() => SocksHttp(
        socksHost: socksHost,
        socksPort: socksPort,
        targetHost: targetHost,
        targetPort: targetPort,
        roomKey: _password ?? '',
      );

  /// Pushes media [bytes] to the host over Tor HTTP and returns its [mediaId].
  Future<String> uploadMedia(
    Uint8List bytes, {
    required String mediaType,
    String? name,
    String? mime,
  }) async {
    final resp = await _mediaHttp().upload(
      path: '/media',
      body: bytes,
      contentType: mime ?? (mediaType == 'video' ? 'video/mp4' : 'image/jpeg'),
      name: name,
    );
    final map = jsonDecode(utf8.decode(resp)) as Map<String, dynamic>;
    return map['id'] as String;
  }

  /// Fetches a media payload from the host over Tor HTTP.
  Future<Uint8List> fetchMedia(String mediaId) async {
    return _mediaHttp().get('/media/$mediaId');
  }

  /// Broadcasts a media message through the WebSocket (metadata only).
  void sendMedia({
    required String mediaId,
    required String mediaType,
    String? name,
    int? size,
    String? mime,
  }) {
    _ws?.sendText(ChatProtocol.encodeMedia(
      mediaId: mediaId,
      mediaType: mediaType,
      name: name,
      size: size,
      mime: mime,
      id: ChatMessage.newId(),
    ));
  }

  /// Asks the host to edit message [messageId] to [text].
  void sendEdit(String messageId, String text) {
    _ws?.sendText(ChatProtocol.encodeEdit(messageId: messageId, text: text));
  }

  /// Asks the host to delete message [messageId] for everyone.
  void sendDelete(String messageId) {
    _ws?.sendText(ChatProtocol.encodeDelete(messageId: messageId));
  }

  /// Tells the host this client changed its persona (name, bio or picture).
  /// The host renames the past messages it stored for [oldUsername] and relays
  /// the change to everyone else.
  void sendProfile({
    required String oldUsername,
    required String username,
    String? bio,
    String? avatar,
    String? avatarData,
  }) {
    _ws?.sendText(jsonEncode({
      'type': ChatProtocol.kProfile,
      'oldUsername': oldUsername,
      'username': username,
      'bio': bio,
      'avatar': avatar,
      'avatarData': avatarData,
    }));
  }

  void _onData(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case ChatProtocol.kPrompt:
        _onPrompt.add(null);
        break;
      case ChatProtocol.kReady:
        _onReady.add(msg);
        break;
      case ChatProtocol.kMember:
        _onMember.add(msg['member'] as Map<String, dynamic>? ?? {});
        break;
      case ChatProtocol.kProfile:
        _onProfile.add(msg);
        break;
      case ChatProtocol.kPending:
        _onPending.add(null);
        break;
      case ChatProtocol.kDenied:
        _onDenied.add(null);
        break;
      case ChatProtocol.kKicked:
        _onKicked.add(null);
        break;
      case ChatProtocol.kEdit:
        _onEdit.add(ChatMessage(
          type: ChatProtocol.kEdit,
          username: msg['username'] as String? ?? '',
          text: msg['text'] as String? ?? '',
          ts: msg['ts'] as String? ?? '',
          id: msg['messageId'] as String? ?? '',
        ));
        break;
      case ChatProtocol.kDelete:
        _onDelete.add(msg['messageId'] as String? ?? '');
        break;
      case ChatProtocol.kDeleteAllMedia:
        _onDeleteAllMedia.add(null);
        break;
      case ChatProtocol.kDeleteAllMessages:
        _onDeleteAllMessages.add(null);
        break;
      case ChatProtocol.kMessage:
      case ChatProtocol.kSystem:
      case ChatProtocol.kMedia:
        _messages.add(ChatMessage.fromJson(msg));
        break;
    }
  }

  Future<void> close() async {
    _disposed = true;
    try {
      await _ws?.close();
    } catch (_) {}
    await _messages.close();
    await _onPrompt.close();
    await _onReady.close();
    await _onMember.close();
    await _onProfile.close();
    await _onAuthFailed.close();
    await _onPending.close();
    await _onDenied.close();
    await _onKicked.close();
    await _onEdit.close();
    await _onDelete.close();
    await _onDeleteAllMedia.close();
    await _onDeleteAllMessages.close();
    await _onClose.close();
    await _onError.close();
  }
}
