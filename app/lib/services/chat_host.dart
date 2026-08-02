import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/chat_message.dart';
import 'chat_protocol.dart';

/// A room hosted by the device itself. Accepts WebSocket clients over Tor
/// (the hidden service forwards onion:80 -> 127.0.0.1:[port]), authenticates
/// them against the room password, asks for a username and broadcasts messages
/// to every authenticated participant — the exact same protocol as chat.js.
///
/// Keeps a roster of participants (username, bio, profile picture, join time)
/// so everyone can see each other's profile.
class ChatHost {
  final int port;
  final String? password;
  String ownerUsername;
  String? ownerBio;
  String? ownerAvatar;

  HttpServer? _server;
  final _clients = <_HostClient>{};
  final _pending = <_HostClient>[];
  int _colorIdx = 0;
  int _startedAt = 0;
  String? _ownerAvatarData;

  /// In-memory shared media (photos/videos). Bytes live only on this device —
  /// the host phone is the server — and are served over Tor via the hidden
  /// service's HTTP endpoint, so no third party ever sees them.
  final _media = <String, _StoredMedia>{};

  /// Upper bound for a single upload, so Tor isn't choked by huge files.
  static const int maxMediaBytes = 64 * 1024 * 1024;

  /// Called whenever the host stores a media payload, so the owner can also
  /// persist it to disk (survives restarts). Errors are ignored.
  Future<void> Function(String mediaId, Uint8List bytes)? onMediaStore;

  /// The host's authoritative message history (seeded from disk, then kept
  /// current with every message/edit/delete). Sent to previously-known users
  /// when they rejoin so edits and deletions are reflected for offline friends.
  final List<ChatMessage> _history = [];
  static const int _maxHistory = 1000;

  /// Usernames (lowercased) that were ever members of this room. On rejoin they
  /// receive the full history; brand-new users start fresh (WhatsApp-style).
  final Set<String> knownUsernames = {};

  final _messages = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messages => _messages.stream;

  /// Join requests waiting for the host's approval.
  final _onJoinRequest = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onJoinRequest => _onJoinRequest.stream;

  /// A message in the room was edited (carries the new version).
  final _onEdit = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onEdit => _onEdit.stream;

  /// A message in the room was deleted (carries the [ChatMessage.id]).
  final _onDelete = StreamController<String>.broadcast();
  Stream<String> get onDelete => _onDelete.stream;

  /// The owner wiped every photo/video in the room.
  final _onDeleteAllMedia = StreamController<void>.broadcast();
  Stream<void> get onDeleteAllMedia => _onDeleteAllMedia.stream;

  /// The owner wiped every message in the room.
  final _onDeleteAllMessages = StreamController<void>.broadcast();
  Stream<void> get onDeleteAllMessages => _onDeleteAllMessages.stream;

  final _onClientCount = StreamController<int>.broadcast();
  Stream<int> get onClientCount => _onClientCount.stream;

  /// Roster updates (a user joined). Payload is the member map.
  final _onMember = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMember => _onMember.stream;

  /// A participant changed their persona mid-chat. Payload carries
  /// `oldUsername` plus the updated member fields.
  final _onProfile = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onProfile => _onProfile.stream;

  /// System notices emitted by the host itself (owner joins, etc.).
  final _system = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get system => _system.stream;

  ChatHost({
    required this.port,
    required this.password,
    required this.ownerUsername,
    this.ownerBio,
    this.ownerAvatar,
  });

  bool get isRunning => _server != null;

  /// Approved participants currently in the room (pending requests excluded).
  int get clientCount =>
      _clients.where((c) => c.joined).length;

  /// Read-only view of the authoritative history (used by the smoke test to
  /// verify edits/deletions/wipe behaviour).
  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Seeds the authoritative history from the owner's persisted store, so
  /// previously-known users see full history (and edits/deletions) on rejoin.
  void seedHistory(List<ChatMessage> history) {
    if (history.length > _maxHistory) {
      _history.addAll(history.sublist(history.length - _maxHistory));
    } else {
      _history.addAll(history);
    }
  }

  /// True when the owner is viewing this room (the owner "joins" locally
  /// without a Tor round-trip, since the hidden service descriptor can take
  /// ~30s to propagate after a fresh start).
  bool ownerJoined = false;

  Future<void> start() async {
    _startedAt = DateTime.now().millisecondsSinceEpoch;
    _ownerAvatarData = _avatarDataFor(ownerAvatar);
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_onRequest);
    _emitSystem('$ownerUsername started the room (hidden service online)');
  }

  /// Broadcasts a message as the owner, exactly like a remote client would.
  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = ChatMessage.newId();
    _broadcast({
      'type': ChatProtocol.kMessage,
      'username': ownerUsername,
      'color': 0,
      'text': trimmed,
      'id': id,
    });
    _addMessage(ChatMessage(
      type: ChatProtocol.kMessage,
      username: ownerUsername,
      text: trimmed,
      ts: _now(),
      id: id,
      rawColor: '0',
    ));
  }

  void _onRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'POST' && path == '/media') {
      await _handleMediaUpload(request);
      return;
    }
    if (request.method == 'GET' && path.startsWith('/media/')) {
      await _handleMediaDownload(request, path.substring('/media/'.length));
      return;
    }
    if (path != '/' && path != '/ws') {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    final client = _HostClient(socket, colorIndex: _colorIdx++);
    _clients.add(client);
    _onClientCount.add(clientCount);

    socket.listen(
      (raw) => _handleMessage(client, raw),
      onError: (_) => _drop(client),
      onDone: () => _drop(client),
    );
  }

  bool _isRoomKey(String? key) {
    if (password == null || password!.isEmpty) return true;
    return key == password;
  }

  Future<void> _handleMediaUpload(HttpRequest request) async {
    try {
      if (!_isRoomKey(request.headers.value('x-room-key'))) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final length = request.contentLength;
      if (length <= 0 || length > maxMediaBytes) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        await request.response.close();
        return;
      }
      final mime =
          request.headers.value('content-type') ?? 'application/octet-stream';
      final name = request.headers.value('x-media-name') ?? '';
      final chunks = <int>[];
      await for (final chunk in request) {
        chunks.addAll(chunk);
      }
      final id = _storeMedia(
        Uint8List.fromList(chunks),
        mime: mime,
        name: name,
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'id': id}));
      await request.response.close();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleMediaDownload(HttpRequest request, String id) async {
    if (!_isRoomKey(request.headers.value('x-room-key'))) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    final m = _media[id];
    if (m == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response.headers.contentType = ContentType.parse(m.mime);
    request.response.contentLength = m.bytes.length;
    request.response.add(m.bytes);
    await request.response.close();
  }

  String _storeMedia(
    Uint8List bytes, {
    required String mime,
    required String name,
  }) {
    final id = '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
    _media[id] = _StoredMedia(
      bytes: bytes,
      mime: mime,
      name: name,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    final persist = onMediaStore;
    if (persist != null) {
      persist(id, bytes).catchError((_) {});
    }
    return id;
  }

  /// Re-injects media reloaded from disk (after an app restart) so the host
  /// can keep serving it to peers.
  void addStoredMedia(String id, Uint8List bytes) {
    _media[id] = _StoredMedia(
      bytes: bytes,
      mime: 'application/octet-stream',
      name: '',
      ts: 0,
    );
  }

  /// Bytes of a stored media item (used by the owner locally — the host is
  /// this same process, so no round-trip through Tor is needed).
  Uint8List? mediaBytes(String id) => _media[id]?.bytes;

  /// The host's own send-media path (owner). Stores [bytes] and announces it.
  String storeAndSendMedia(
    Uint8List bytes, {
    required String mediaType,
    String? name,
    String? mime,
  }) {
    final id = _storeMedia(
      bytes,
      mime: mime ?? _defaultMimeFor(mediaType),
      name: name ?? '',
    );
    sendMedia(
      mediaId: id,
      mediaType: mediaType,
      name: name,
      size: bytes.length,
      mime: mime,
    );
    return id;
  }

  void sendMedia({
    required String mediaId,
    required String mediaType,
    String? name,
    int? size,
    String? mime,
  }) {
    final id = ChatMessage.newId();
    _broadcast({
      'type': ChatProtocol.kMedia,
      'username': ownerUsername,
      'color': 0,
      'mediaId': mediaId,
      'mediaType': mediaType,
      'mediaName': name,
      'mediaSize': size,
      'mediaMime': mime,
      'id': id,
    });
    _addMessage(ChatMessage(
      type: ChatProtocol.kMedia,
      username: ownerUsername,
      text: '',
      ts: _now(),
      id: id,
      rawColor: '0',
      mediaType: mediaType,
      mediaId: mediaId,
      mediaName: name,
      mediaSize: size,
      mediaMime: mime,
    ));
  }

  static String _defaultMimeFor(String mediaType) =>
      mediaType == 'video' ? 'video/mp4' : 'image/jpeg';

  /// Adds a message to the authoritative history (trimmed to [_maxHistory])
  /// and emits it to live listeners.
  void _addMessage(ChatMessage m) {
    _history.add(m);
    if (_history.length > _maxHistory) {
      _history.removeRange(0, _history.length - _maxHistory);
    }
    _messages.add(m);
  }

  /// Rewrites [oldName] -> [newName] for non-system history entries (used when
  /// someone renames, so replayed history shows the current name).
  void _renameHistory(String oldName, String newName) {
    if (oldName == newName) return;
    for (var i = 0; i < _history.length; i++) {
      final m = _history[i];
      if (!m.isSystem && m.username == oldName) {
        _history[i] = m.copyWith(username: newName);
      }
    }
  }

  /// The owner edits one of their own messages.
  void editMessage(String messageId, String newText) {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    _applyEdit(messageId, trimmed, actor: ownerUsername);
  }

  /// The owner deletes one of their own messages.
  void deleteMessage(String messageId) {
    _applyDelete(messageId, actor: ownerUsername);
  }

  /// Kicks every connected client out (their sockets are closed) while the
  /// room keeps running for new visitors. Used by "Disconnect everyone".
  void disconnectEveryone() {
    for (final c in _clients.toList()) {
      if (c.joined) {
        _broadcast(
          {'type': ChatProtocol.kSystem, 'text': '${c.username} disconnected!'},
          except: c,
        );
      }
      _drop(c);
    }
    _onClientCount.add(clientCount);
  }

  /// Wipes every photo/video in the room for everyone: media messages are
  /// dropped from the authoritative history, the stored bytes are cleared and
  /// clients are told to drop their local media too.
  void deleteAllMedia() {
    _history.removeWhere((m) => m.isMedia);
    _media.clear();
    _broadcast({'type': ChatProtocol.kDeleteAllMedia});
    _onDeleteAllMedia.add(null);
  }

  /// Wipes the entire room history for everyone, media included.
  void deleteAllMessages() {
    _history.clear();
    _media.clear();
    _broadcast({'type': ChatProtocol.kDeleteAllMessages});
    _onDeleteAllMessages.add(null);
  }

  void _applyEdit(String messageId, String text, {required String? actor}) {
    final idx = _history.indexWhere((m) => m.id == messageId && !m.isSystem);
    if (idx < 0 || _history[idx].username != actor) return;
    final updated = _history[idx].copyWith(text: text);
    _history[idx] = updated;
    _broadcast({
      'type': ChatProtocol.kEdit,
      'messageId': messageId,
      'text': text,
      'username': updated.username,
      'ts': updated.ts,
    });
    _onEdit.add(updated);
  }

  void _applyDelete(String messageId, {required String? actor}) {
    final idx = _history.indexWhere((m) => m.id == messageId && !m.isSystem);
    if (idx < 0 || _history[idx].username != actor) return;
    _history.removeAt(idx);
    _broadcast({'type': ChatProtocol.kDelete, 'messageId': messageId});
    _onDelete.add(messageId);
  }

  /// Approves a pending join request: the client gets the roster (and, if they
  /// were previously a member, the full history so edits/deletions persist for
  /// offline friends), and everyone else is notified.
  void approveClient(String username) {
    final idx = _pending.indexWhere((c) => c.username == username);
    if (idx < 0) return;
    final client = _pending.removeAt(idx);
    client.approved = true;

    final members = <Map<String, dynamic>>[
      _ownerMember(),
      for (final c in _clients)
        if (c != client && c.joined) _clientMember(c),
    ];
    final known = knownUsernames.contains(client.username!.toLowerCase());
    _send(client, {
      'type': ChatProtocol.kReady,
      'username': client.username,
      'color': client.colorIndex,
      'members': members,
      if (known) 'history': _history.map((m) => m.toJson()).toList(),
    });

    final member = _clientMember(client);
    for (final c in _clients) {
      if (c != client && c.joined) {
        _send(c, {'type': ChatProtocol.kMember, 'member': member});
      }
    }
    _onMember.add(member);

    final sysText = '${client.username} has connected!';
    _broadcast({'type': ChatProtocol.kSystem, 'text': sysText}, except: client);
    _addMessage(ChatMessage(
      type: ChatProtocol.kSystem,
      username: '',
      text: sysText,
      ts: _now(),
    ));
    _onClientCount.add(clientCount);
  }

  /// Rejects a pending join request.
  void denyClient(String username) {
    final idx = _pending.indexWhere((c) => c.username == username);
    if (idx < 0) return;
    final client = _pending.removeAt(idx);
    _send(client, {'type': ChatProtocol.kDenied});
    _drop(client);
  }

  void _handleMessage(_HostClient client, dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type']) {
      case ChatProtocol.kAuth:
        if (password != null && password!.isNotEmpty) {
          final sent = msg['password'] as String? ?? '';
          if (sent != password) {
            _send(client, {'type': ChatProtocol.kAuthFailed, 'text': 'WRONG ACCESS CODE'});
            return;
          }
        }
        client.authed = true;
        _send(client, {'type': ChatProtocol.kPrompt, 'step': 'username'});
        break;

      case ChatProtocol.kUsername:
        if (!client.authed) return;
        var username = (msg['username'] as String? ?? '').trim();
        if (username.isEmpty || username.length > 32) {
          username = 'anon-${100 + Random().nextInt(900)}';
        }
        client.username = username;
        client.bio = (msg['bio'] as String? ?? '').trim();
        client.avatar = msg['avatar'] as String?;
        final avatarData = msg['avatarData'] as String?;
        if (avatarData != null && avatarData.isNotEmpty) {
          client.avatarData = avatarData;
        }
        client.joinedAt = DateTime.now().millisecondsSinceEpoch;

        // Entry requires the host's approval. Add to the pending queue and ask
        // the owner; the client is told to wait until a decision arrives.
        _pending.add(client);
        _send(client, {'type': ChatProtocol.kPending});
        _onJoinRequest.add({
          'username': client.username,
          'color': client.colorIndex,
          'bio': client.bio.isEmpty ? null : client.bio,
          'avatar': client.avatar,
          'avatarData': client.avatarData,
          'joinedAt': client.joinedAt,
        });
        break;

      case ChatProtocol.kMessage:
        if (!client.joined) return;
        final text = (msg['text'] as String? ?? '').trim();
        if (text.isEmpty) return;
        final id = msg['id'] as String? ?? ChatMessage.newId();
        _broadcast({
          'type': ChatProtocol.kMessage,
          'username': client.username,
          'color': client.colorIndex,
          'text': text,
          'id': id,
        });
        _addMessage(ChatMessage(
          type: ChatProtocol.kMessage,
          username: client.username!,
          text: text,
          ts: _now(),
          id: id,
          rawColor: '${client.colorIndex}',
        ));
        break;

      case ChatProtocol.kMedia:
        if (!client.joined) return;
        final mediaId = msg['mediaId'] as String? ?? '';
        final m = _media[mediaId];
        if (mediaId.isEmpty || m == null) return;
        final mediaType = msg['mediaType'] as String? ?? 'image';
        final id = msg['id'] as String? ?? ChatMessage.newId();
        _broadcast({
          'type': ChatProtocol.kMedia,
          'username': client.username,
          'color': client.colorIndex,
          'mediaId': mediaId,
          'mediaType': mediaType,
          'mediaName': m.name,
          'mediaSize': m.bytes.length,
          'mediaMime': m.mime,
          'id': id,
        });
        _addMessage(ChatMessage(
          type: ChatProtocol.kMedia,
          username: client.username!,
          text: '',
          ts: _now(),
          id: id,
          rawColor: '${client.colorIndex}',
          mediaType: mediaType,
          mediaId: mediaId,
          mediaName: m.name,
          mediaSize: m.bytes.length,
          mediaMime: m.mime,
        ));
        break;

      case ChatProtocol.kEdit:
        if (!client.joined) return;
        _applyEdit(
          msg['messageId'] as String? ?? '',
          msg['text'] as String? ?? '',
          actor: client.username,
        );
        break;

      case ChatProtocol.kDelete:
        if (!client.joined) return;
        _applyDelete(
          msg['messageId'] as String? ?? '',
          actor: client.username,
        );
        break;

      case ChatProtocol.kProfile:
        if (!client.authed || client.username == null) return;
        final oldName = client.username!;
        final newName = (msg['username'] as String? ?? '').trim();
        if (newName.isEmpty || newName.length > 32) return;
        client.username = newName;
        client.bio = (msg['bio'] as String? ?? '').trim();
        client.avatar = msg['avatar'] as String?;
        final avatarData = msg['avatarData'] as String?;
        if (avatarData != null && avatarData.isNotEmpty) {
          client.avatarData = avatarData;
        }
        _renameHistory(oldName, newName);
        final member = _clientMember(client);
        final update = {
          'type': ChatProtocol.kProfile,
          'oldUsername': oldName,
          ...member,
        };
        _onProfile.add(update);
        for (final c in _clients) {
          if (c == client || !c.joined) continue;
          _send(c, update);
        }
    }
  }

  Map<String, dynamic> _ownerMember() => ChatProtocol.memberJson(
        username: ownerUsername,
        color: 0,
        bio: ownerBio,
        avatar: ownerAvatar,
        avatarData: _ownerAvatarData,
        joinedAt: _startedAt,
      );

  /// Propagates a change to the owner's own persona (name, picture, bio) to
  /// everyone connected, so clients can rename the owner's past messages.
  void updateOwnerProfile({
    required String oldUsername,
    required String username,
    String? bio,
    String? avatar,
  }) {
    if (oldUsername.isEmpty || username.isEmpty) return;
    if (oldUsername == username && bio == ownerBio && avatar == ownerAvatar) {
      return;
    }
    ownerUsername = username;
    ownerBio = bio;
    ownerAvatar = avatar;
    _ownerAvatarData = _avatarDataFor(ownerAvatar);
    _renameHistory(oldUsername, username);
    final member = _ownerMember();
    final update = {'type': ChatProtocol.kProfile, 'oldUsername': oldUsername, ...member};
    _broadcast(update);
    _onProfile.add(update);
  }

  Map<String, dynamic> _clientMember(_HostClient c) => ChatProtocol.memberJson(
        username: c.username!,
        color: c.colorIndex,
        bio: c.bio,
        avatar: c.avatar,
        avatarData: c.avatarData,
        joinedAt: c.joinedAt,
      );

  void _drop(_HostClient client) {
    if (!_clients.remove(client)) return;
    _pending.remove(client);
    _onClientCount.add(clientCount);
    if (client.joined) {
      final name = client.username!;
      _broadcast(
        {'type': ChatProtocol.kSystem, 'text': '$name disconnected!'},
        except: client,
      );
      _addMessage(ChatMessage(
        type: ChatProtocol.kSystem,
        username: '',
        text: '$name disconnected!',
        ts: _now(),
      ));
    }
  }

  void _send(_HostClient client, Map<String, dynamic> msg) {
    if (client.socket.readyState == WebSocket.open) {
      client.socket.add(jsonEncode(msg));
    }
  }

  void _broadcast(Map<String, dynamic> msg, {_HostClient? except}) {
    for (final c in _clients) {
      if (c == except || !c.joined) continue;
      if (c.socket.readyState == WebSocket.open) {
        c.socket.add(jsonEncode(msg));
      }
    }
  }

  void _emitSystem(String text) {
    final msg = ChatMessage(
      type: ChatProtocol.kSystem,
      username: '',
      text: text,
      ts: _now(),
    );
    _addMessage(msg);
    _system.add(msg);
  }

  static String _now() => DateTime.now().toLocal().toString().substring(11, 16);

  /// Reads a custom avatar file as base64 (small images only). Returns null for
  /// bundled avatars (`asset:`/`null`) or unreadable files.
  static String? _avatarDataFor(String? avatar) {
    if (avatar == null || avatar.startsWith('asset:')) return null;
    try {
      final f = File(avatar);
      if (!f.existsSync()) return null;
      return base64Encode(f.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  Future<void> stop() async {
    for (final c in _clients) {
      try {
        c.socket.close();
      } catch (_) {}
    }
    _clients.clear();
    _pending.clear();
    _history.clear();
    _media.clear();
    final server = _server;
    _server = null;
    await server?.close(force: true);
    await _messages.close();
    await _onClientCount.close();
    await _system.close();
    await _onMember.close();
    await _onProfile.close();
    await _onJoinRequest.close();
    await _onEdit.close();
    await _onDelete.close();
    await _onDeleteAllMedia.close();
    await _onDeleteAllMessages.close();
  }
}

class _StoredMedia {
  final Uint8List bytes;
  final String mime;
  final String name;
  final int ts;

  _StoredMedia({
    required this.bytes,
    required this.mime,
    required this.name,
    required this.ts,
  });
}

class _HostClient {
  final WebSocket socket;
  final int colorIndex;
  bool authed = false;

  /// Host approved this client's entry (pending requests can't see anything).
  bool approved = false;
  String? username;
  String bio = '';
  String? avatar;
  String? avatarData;
  int joinedAt = 0;

  _HostClient(this.socket, {required this.colorIndex});

  bool get joined => authed && approved && username != null;
}
