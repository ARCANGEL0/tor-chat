import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/chat_message.dart';
import '../models/peer_info.dart';
import '../models/room.dart';
import '../services/app_assets.dart';
import '../services/chat_client.dart';
import '../services/chat_host.dart';
import '../services/media_store.dart';
import '../services/notification_service.dart';
import '../services/onion_identity.dart';
import '../services/room_store.dart';
import '../services/sound_service.dart';
import '../services/tor_engine.dart';
import 'theme_controller.dart';

enum SessionMode { none, host, client }

/// One active chat session (a room being hosted or joined). Multiple sessions
/// can run at the same time: every hosted room keeps its own Tor hidden
/// service + server, every joined room its own client, all sharing one Tor.
class ChatSession {
  SessionMode mode;
  Room room;
  ChatHost? host;
  ChatClient? client;
  int hostPort;

  final List<ChatMessage> messages = [];
  final Map<String, PeerInfo> members = {};
  final Map<String, Uint8List> mediaCache = {};

  /// Join requests awaiting the host's approval (host side only).
  final Map<String, Map<String, dynamic>> pendingJoins = {};

  /// True while this client's entry awaits host approval.
  bool pendingApproval = false;

  int participantCount = 1;
  bool connected = false;
  String? error;

  final List<StreamSubscription<dynamic>> subs = [];

  ChatSession({
    required this.mode,
    required this.room,
    this.hostPort = AppConfig.hostPort,
  });

  bool get isHost => mode == SessionMode.host;

  void disposeSession() {
    for (final s in subs) {
      s.cancel();
    }
    subs.clear();
  }
}

/// Owns the lifecycle of every chat session. The host's phone IS the server
/// (Tor hidden service) for each room it hosts; peers connect directly over
/// Tor. `.onion` addresses are derived from the namecode + password on both
/// sides, so no third-party directory is needed.
///
/// Only one session is "active" (the room on screen); the others keep running
/// in the background so switching rooms never disconnects anyone.
class RoomController extends ChangeNotifier {
  RoomController._();
  static final RoomController instance = RoomController._();

  final Map<String, ChatSession> _sessions = {};
  ChatSession? _active;

  /// Id of the chat currently on screen (used to suppress redundant system
  /// notifications for the room the user is actively watching).
  static String? visibleRoomId;

  /// Whether the app is currently in the foreground (updated by the app-level
  /// lifecycle observer). Notifications always fire while minimized.
  static bool appInForeground = true;

  final _onServerDisconnect = StreamController<void>.broadcast();

  /// Fired when the active client room's server goes offline (or can't be
  /// reached). The UI pops home and shows the [pendingDisconnect] message.
  Stream<void> get onServerDisconnect => _onServerDisconnect.stream;

  RoomStore? _store;

  String? _pendingDisconnect;

  /// One-shot warning for the home screen after an unexpected disconnect.
  String? takePendingDisconnect() {
    final m = _pendingDisconnect;
    _pendingDisconnect = null;
    return m;
  }

  // ----------------------------------------------------------- active session

  Room? get room => _active?.room;
  SessionMode get mode => _active?.mode ?? SessionMode.none;
  bool get isHost => mode == SessionMode.host;
  bool get isActive => _active != null;
  ChatHost? get host => _active?.host;
  ChatClient? get client => _active?.client;
  List<ChatMessage> get messages => _active?.messages ?? const [];
  Map<String, PeerInfo> get members => _active?.members ?? const {};
  int get participantCount => _active?.participantCount ?? 1;
  bool get connected => _active?.connected ?? false;
  bool get pendingApproval => _active?.pendingApproval ?? false;
  List<Map<String, dynamic>> get pendingJoins =>
      _active?.pendingJoins.values.toList() ?? const [];
  String? get error => _active?.error;

  /// Number of live sessions (hosted or joined) right now.
  int get activeSessionCount => _sessions.length;

  bool isRoomActive(String roomId) => _sessions.containsKey(roomId);

  ChatSession? sessionFor(String roomId) => _sessions[roomId];

  /// Opens a room: focuses its live session if it's still running, otherwise
  /// starts a fresh host/client session. Sessions are never torn down when
  /// switching rooms.
  Future<void> openRoom(Room newRoom) async {
    final existing = _sessions[newRoom.id];
    if (existing != null) {
      _active = existing;
      notifyListeners();
      return;
    }
    if (newRoom.isOwner) {
      await startHost(newRoom);
    } else {
      await startClient(newRoom);
    }
  }

  // ------------------------------------------------------------------ host

  /// Starts hosting [newRoom]: derives its deterministic onion identity and
  /// runs a Tor hidden service + local WebSocket server for exactly that room.
  Future<void> startHost(Room newRoom) async {
    final port = _nextHostPort();
    final s = ChatSession(mode: SessionMode.host, room: newRoom, hostPort: port);
    _sessions[newRoom.id] = s;
    _active = s;
    await _loadHistory(s);
    notifyListeners();

    try {
      final namecode = newRoom.namecode.trim().toLowerCase();
      final onion = await TorEngine.instance.startHosting(
        HostedService(
          roomId: newRoom.id,
          port: port,
        ),
      );
      newRoom.onion = onion;
      debugPrint('[HOST] hosted onion: $onion for room ${newRoom.id}');

      final h = ChatHost(
        port: port,
        password: newRoom.password,
        ownerUsername: newRoom.username,
        ownerBio: _effectiveBio(newRoom),
        ownerAvatar: _effectiveAvatar(newRoom),
      );
      h.onMediaStore = (id, bytes) => MediaStore.save(newRoom.id, id, bytes);
      s.host = h;
      h.knownUsernames
        ..addAll(s.members.keys.map((k) => k.toLowerCase()))
        ..add(newRoom.username.toLowerCase());
      h.seedHistory(List.of(s.messages));
      s.subs.add(h.messages.listen((msg) => _onMessage(s, msg)));
      s.subs.add(h.onMember.listen((m) => _applyMember(s, m)));
      s.subs.add(h.onProfile.listen((m) => _applyProfileUpdate(s, m)));
      s.subs.add(h.onEdit.listen((m) => _onMessageEdited(s, m)));
      s.subs.add(h.onDelete.listen((id) => _onMessageDeleted(s, id)));
      s.subs.add(h.onDeleteAllMedia.listen((_) => _onDeleteAllMedia(s)));
      s.subs.add(h.onDeleteAllMessages.listen((_) => _onDeleteAllMessages(s)));
      s.subs.add(h.onJoinRequest.listen((m) {
        s.pendingJoins[m['username'] as String? ?? ''] = m;
        notifyListeners();
      }));
      s.subs.add(h.onClientCount.listen((n) {
        s.participantCount = n + 1; // +1 for the owner
        notifyListeners();
      }));

      await h.start();
      // Reload media persisted on disk (survives app restarts) so the host
      // keeps serving old photos/videos to peers.
      for (final id in await MediaStore.idsFor(newRoom.id)) {
        final bytes = await MediaStore.load(newRoom.id, id);
        if (bytes != null) {
          h.addStoredMedia(id, bytes);
          s.mediaCache[id] = bytes;
        }
      }
      h.ownerJoined = true;
      s.members[newRoom.username] = PeerInfo(
        username: newRoom.username,
        bio: _effectiveBio(newRoom),
        avatar: _effectiveAvatar(newRoom),
        joinedAt: DateTime.now(),
        color: 0,
      );
      await _persistMembers(s);
      s.connected = true;
      notifyListeners();
    } catch (e) {
      await _dropSession(s);
      rethrow;
    }
  }

  // ------------------------------------------------------------------ client

  /// Connects to a friend's room. If [newRoom.onion] is set (e.g. the user
  /// typed a raw `.onion` address, or it was saved) it is used directly;
  /// otherwise the onion is derived from the namecode + password.
  Future<void> startClient(Room newRoom) async {
    final namecode = newRoom.namecode.trim().toLowerCase();
    final onion = newRoom.onion.isNotEmpty
        ? newRoom.onion
        : await OnionIdentity.onionAddress(namecode, newRoom.password);
    newRoom.onion = onion;

    await TorEngine.instance.startForClient();

    final s = ChatSession(mode: SessionMode.client, room: newRoom);
    _sessions[newRoom.id] = s;
    _active = s;
    await _loadHistory(s);
    notifyListeners();

    debugPrint('[CLIENT] joining ${newRoom.namecode} → $onion:${AppConfig.onionPort} via SOCKS 127.0.0.1:${AppConfig.socksPort}');

    final c = ChatClient(
      socksHost: '127.0.0.1',
      socksPort: AppConfig.socksPort,
      targetHost: onion,
      targetPort: AppConfig.onionPort,
    );
    s.client = c;
    s.subs.add(c.onPrompt.listen((_) {
      c.sendUsername(
        newRoom.username,
        bio: _effectiveBio(newRoom),
        avatar: _effectiveAvatar(newRoom),
        avatarData: _avatarDataFor(_effectiveAvatar(newRoom)),
      );
    }));
    s.subs.add(c.onReady.listen((msg) async {
      s.connected = true;
      s.pendingApproval = false;
      s.error = null;
      // The host may replay its authoritative history (for previously-known
      // users), which reflects edits/deletions made while we were offline.
      if (msg['history'] is List) {
        final history = (msg['history'] as List)
            .map((e) {
              final m = ChatMessage.fromJson(e as Map<String, dynamic>);
              return m.mine ? m : m.copyWith(mine: m.username == newRoom.username);
            })
            .toList();
        s.messages
          ..clear()
          ..addAll(history);
        final store = _store ??= await RoomStore.load();
        await store.replaceMessages(s.room.id, history);
      }
      // Record ourselves as a member (joined right now).
      s.members[newRoom.username] = PeerInfo(
        username: newRoom.username,
        bio: _effectiveBio(newRoom),
        avatar: _effectiveAvatar(newRoom),
        joinedAt: DateTime.now(),
        color: 0,
      );
      final roster = msg['members'];
      if (roster is List) {
        for (final m in roster) {
          if (m is Map<String, dynamic>) await _applyMember(s, m);
        }
      }
      await _persistMembers(s);
      notifyListeners();
    }));
    s.subs.add(c.onPending.listen((_) {
      s.pendingApproval = true;
      s.error = null;
      notifyListeners();
    }));
    s.subs.add(c.onDenied.listen((_) {
      s.error = 'The host denied your entry to this room.';
      s.connected = false;
      s.pendingApproval = false;
      notifyListeners();
      final wasActive = _active == s;
      final name = s.room.namecode;
      _dropSession(s);
      if (wasActive) {
        _pendingDisconnect = 'You were denied entry to $name.';
        _onServerDisconnect.add(null);
      }
    }));
    s.subs.add(c.onMember.listen((m) => _applyMember(s, m)));
    s.subs.add(c.onProfile.listen((m) => _applyProfileUpdate(s, m)));
    s.subs.add(c.onEdit.listen((m) => _onMessageEdited(s, m)));
    s.subs.add(c.onDelete.listen((id) => _onMessageDeleted(s, id)));
    s.subs.add(c.onDeleteAllMedia.listen((_) => _onDeleteAllMedia(s)));
    s.subs.add(c.onDeleteAllMessages.listen((_) => _onDeleteAllMessages(s)));
    s.subs.add(c.onAuthFailed.listen((_) {
      s.error = 'Wrong password for this room.';
      s.connected = false;
      notifyListeners();
    }));
    s.subs.add(c.onClose.listen((_) {
      s.connected = false;
      notifyListeners();
      if (s.mode == SessionMode.client) {
        final wasActive = _active == s;
        final name = s.room.namecode;
        _dropSession(s);
        if (wasActive) {
          _pendingDisconnect = 'You have been disconnected.\n$name is now offline';
          _onServerDisconnect.add(null);
        }
      }
    }));
    s.subs.add(c.onError.listen((Object e) {
      s.error = 'Connection error: $e';
      s.connected = false;
      notifyListeners();
    }));
    s.subs.add(c.messages.listen((msg) => _onMessage(s, msg)));

    try {
      await c.connect(password: newRoom.password);
    } catch (e) {
      // The session may already be gone (user left while we retried).
      if (_sessions[newRoom.id] != s) return;
      s.error = 'Could not connect to ${newRoom.namecode}.';
      s.connected = false;
      notifyListeners();
      final wasActive = _active == s;
      _dropSession(s);
      if (wasActive) {
        _pendingDisconnect =
            'Could not connect to ${newRoom.namecode}.\nIt may be offline, or the namecode/password may be wrong.';
        _onServerDisconnect.add(null);
      }
    }
  }

  // ------------------------------------------------------------------ common

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final s = _active;
    if (s == null) return;
    if (s.mode == SessionMode.host) {
      s.host?.sendMessage(trimmed);
    } else if (s.mode == SessionMode.client && s.connected) {
      s.client?.sendMessage(trimmed);
    }
  }

  /// Shares [bytes] (a photo or video) with the room. The host stores the
  /// payload and everyone pulls it over Tor HTTP by [mediaId]; only metadata
  /// travels on the WebSocket.
  Future<void> sendMedia(
    Uint8List bytes, {
    required String mediaType,
    String? name,
    String? mime,
  }) async {
    final s = _active;
    if (s == null) return;
    if (s.mode == SessionMode.host) {
      s.host?.storeAndSendMedia(
        bytes,
        mediaType: mediaType,
        name: name,
        mime: mime,
      );
    } else if (s.mode == SessionMode.client && s.connected) {
      final id = await s.client!.uploadMedia(
        bytes,
        mediaType: mediaType,
        name: name,
        mime: mime,
      );
      s.mediaCache[id] = bytes;
      s.client!.sendMedia(
        mediaId: id,
        mediaType: mediaType,
        name: name,
        size: bytes.length,
        mime: mime,
      );
    }
  }

  /// Lazily fetches a shared media payload. Hosts read local memory; clients
  /// pull over Tor HTTP. A per-room disk cache means old media keeps working
  /// even after app restarts or a host going offline. Result is cached in
  /// memory per session too.
  Future<Uint8List> fetchMedia(ChatMessage msg) async {
    final s = _active;
    if (s == null || !msg.isMedia || msg.mediaId == null) {
      throw StateError('No media to fetch');
    }
    final id = msg.mediaId!;
    final cached = s.mediaCache[id];
    if (cached != null) return cached;

    final disk = await MediaStore.load(s.room.id, id);
    if (disk != null) {
      s.mediaCache[id] = disk;
      return disk;
    }

    final bytes = s.mode == SessionMode.host
        ? s.host!.mediaBytes(id)
        : await s.client!.fetchMedia(id);
    if (bytes == null) throw StateError('Media unavailable');
    s.mediaCache[id] = bytes;
    try {
      await MediaStore.save(s.room.id, id, bytes);
    } catch (_) {}
    return bytes;
  }

  /// Edits [messageId] to [newText] for everyone in the room. No "edited"
  /// marker is shown — the change is silent, like Telegram but anonymous.
  void editMessage(String messageId, String newText) {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    final s = _active;
    if (s == null) return;
    if (s.mode == SessionMode.host) {
      s.host?.editMessage(messageId, trimmed);
    } else if (s.mode == SessionMode.client && s.connected) {
      s.client?.sendEdit(messageId, trimmed);
    }
  }

  /// Deletes [messageId] for everyone in the room, as if it never existed.
  void deleteMessage(String messageId) {
    final s = _active;
    if (s == null) return;
    if (s.mode == SessionMode.host) {
      s.host?.deleteMessage(messageId);
    } else if (s.mode == SessionMode.client && s.connected) {
      s.client?.sendDelete(messageId);
    }
  }

  /// Kicks every connected client out while the room keeps running (host only).
  void disconnectEveryone() {
    final s = _active;
    if (s == null || s.mode != SessionMode.host) return;
    s.host?.disconnectEveryone();
  }

  /// Wipes every photo/video in the room for everyone (host-only room control).
  void deleteAllMedia() {
    final s = _active;
    if (s == null || s.mode != SessionMode.host) return;
    s.host?.deleteAllMedia();
  }

  /// Wipes every message in the room for everyone (host-only room control).
  void deleteAllMessages() {
    final s = _active;
    if (s == null || s.mode != SessionMode.host) return;
    s.host?.deleteAllMessages();
  }

  /// Applies the host's "delete all media": media messages, the in-memory
  /// cache and the on-disk media folder for this room are all cleared.
  Future<void> _onDeleteAllMedia(ChatSession s) async {
    s.messages.removeWhere((m) => m.isMedia);
    s.mediaCache.clear();
    try {
      await MediaStore.deleteRoom(s.room.id);
    } catch (_) {}
    _persistAllMessages(s);
    _refreshLastMessage(s);
    notifyListeners();
  }

  /// Applies the host's "delete all messages": the entire chat is wiped.
  Future<void> _onDeleteAllMessages(ChatSession s) async {
    s.messages.clear();
    s.mediaCache.clear();
    try {
      await MediaStore.deleteRoom(s.room.id);
    } catch (_) {}
    _persistAllMessages(s);
    _refreshLastMessage(s);
    notifyListeners();
  }

  Future<void> _persistAllMessages(ChatSession s) async {
    final store = _store ??= await RoomStore.load();
    await store.replaceMessages(s.room.id, s.messages);
  }

  /// Approves a pending join request (host only).
  void approveJoin(String username) {
    final s = _active;
    if (s == null || s.mode != SessionMode.host) return;
    s.host?.approveClient(username);
    s.pendingJoins.remove(username);
    notifyListeners();
  }

  /// Denies a pending join request (host only).
  void denyJoin(String username) {
    final s = _active;
    if (s == null || s.mode != SessionMode.host) return;
    s.host?.denyClient(username);
    s.pendingJoins.remove(username);
    notifyListeners();
  }

  void _onMessageEdited(ChatSession s, ChatMessage updated) {
    final idx = s.messages.indexWhere((m) => m.id == updated.id);
    if (idx < 0) return;
    // Keep the existing entry's identity/mine/ts; only swap the text.
    s.messages[idx] = s.messages[idx].copyWith(text: updated.text);
    _persistEdit(s, s.messages[idx]);
    _refreshLastMessage(s);
    notifyListeners();
  }

  void _onMessageDeleted(ChatSession s, String messageId) {
    final before = s.messages.length;
    s.messages.removeWhere((m) => m.id == messageId);
    if (s.messages.length == before) return;
    _persistDelete(s, messageId);
    _refreshLastMessage(s);
    notifyListeners();
  }

  Future<void> _persistEdit(ChatSession s, ChatMessage updated) async {
    final store = _store ??= await RoomStore.load();
    await store.updateMessage(s.room.id, updated.id, updated);
  }

  Future<void> _persistDelete(ChatSession s, String messageId) async {
    final store = _store ??= await RoomStore.load();
    await store.removeMessage(s.room.id, messageId);
  }

  /// Keeps the home-screen preview in sync after edits/deletions.
  Future<void> _refreshLastMessage(ChatSession s) async {
    ChatMessage? last;
    for (var i = s.messages.length - 1; i >= 0; i--) {
      if (!s.messages[i].isSystem) {
        last = s.messages[i];
        break;
      }
    }
    final r = s.room;
    r.lastMessage = last == null ? '' : '${last.username}: ${_messageLabel(last)}';
    r.lastMessageAt = DateTime.now();
    final store = _store ??= await RoomStore.load();
    await store.saveRoom(r);
  }

  static String _messageLabel(ChatMessage m) {
    if (m.isMedia) return m.isVideo ? 'video' : 'photo';
    return m.text;
  }

  void _onMessage(ChatSession s, ChatMessage msg) {
    final isMine = s.mode == SessionMode.host
        ? msg.username == s.host?.ownerUsername
        : msg.username == s.room.username;
    final rendered = ChatMessage(
      type: msg.type,
      username: msg.username,
      text: msg.text,
      ts: msg.ts,
      id: msg.id,
      rawColor: msg.rawColor,
      mine: isMine,
      mediaType: msg.mediaType,
      mediaId: msg.mediaId,
      mediaName: msg.mediaName,
      mediaSize: msg.mediaSize,
      mediaMime: msg.mediaMime,
    );
    s.messages.add(rendered);

    if (!msg.isSystem) {
      if (!isMine) {
        _trackMember(s, msg);
        SoundService.instance.receive();
        final r = s.room;
        final watchingThisRoom = appInForeground && visibleRoomId == r.id;
        if (!watchingThisRoom) {
          NotificationService.instance.showMessage(
            roomId: r.id,
            roomName: r.namecode,
            username: msg.username.isEmpty ? 'Someone' : msg.username,
            text: _notificationText(msg),
          );
        }
      }
    }

    _persistMessage(s.room, rendered);
    notifyListeners();
  }

  static String _notificationText(ChatMessage msg) {
    if (msg.isMedia) {
      return msg.isVideo ? 'shared a video' : 'shared a photo';
    }
    return msg.text;
  }

  Future<void> _persistMessage(Room r, ChatMessage msg) async {
    final store = _store ??= await RoomStore.load();
    await store.addMessage(r.id, msg);
    if (!msg.isSystem) {
      r.lastMessage = '${msg.username}: ${_messageLabel(msg)}';
      r.lastMessageAt = DateTime.now();
      await store.saveRoom(r);
    }
  }

  Future<void> _loadHistory(ChatSession s) async {
    final store = _store ??= await RoomStore.load();
    s.messages.addAll(store.loadMessages(s.room.id));
    // Restore the previous session's roster.
    for (final p in store.loadMembers(s.room.id)) {
      s.members[p.username] = p;
    }
  }

  // ---------------------------------------------------------------- roster

  Future<void> _applyMember(ChatSession s, Map<String, dynamic> m) async {
    final username = (m['username'] as String? ?? '').trim();
    if (username.isEmpty) return;

    var avatar = m['avatar'] as String?;
    final avatarData = m['avatarData'] as String?;
    if (avatarData != null &&
        avatarData.isNotEmpty &&
        !AppAssets.isAsset(avatar)) {
      final saved = await AppAssets.savePeerAvatar(username, avatarData);
      if (saved != null) avatar = saved;
    }
    final bio = (m['bio'] as String? ?? '').trim();
    s.members[username] = PeerInfo(
      username: username,
      bio: bio.isEmpty ? null : bio,
      avatar: avatar,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(
        m['joinedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      color: m['color'] as int? ?? 0,
    );
    await _persistMembers(s);
    notifyListeners();
  }

  /// First time we see an unknown username, record when they joined (best
  /// effort — the message timestamp).
  void _trackMember(ChatSession s, ChatMessage msg) {
    final name = msg.username.trim();
    if (name.isEmpty || s.members.containsKey(name)) return;
    s.members[name] = PeerInfo(
      username: name,
      joinedAt: _parseMsgTime(msg.ts),
      color: int.tryParse(msg.rawColor ?? '') ?? 0,
    );
    _persistMembers(s);
  }

  static DateTime _parseMsgTime(String ts) {
    final iso = DateTime.tryParse(ts);
    if (iso != null) return iso;
    final parts = ts.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final min = int.tryParse(parts[1]) ?? 0;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, h, min);
    }
    return DateTime.now();
  }

  // ------------------------------------------------------------ persona

  /// Updates the active session's own persona (display name, picture, bio).
  /// Past messages from this device are rewritten to the new name so everyone
  /// (this device and peers) sees one consistent identity; the change is also
  /// propagated over the wire to the other side.
  Future<void> updatePersona({
    required String username,
    String? avatar,
    String? bio,
  }) async {
    final s = _active;
    if (s == null) return;
    final r = s.room;
    final oldName = r.username;
    final newName = username.trim();
    if (newName.isEmpty) return;

    r.username = newName;
    if (avatar != null) r.avatar = avatar;
    r.bio = bio == null || bio.trim().isEmpty ? null : bio.trim();

    // Move our own roster entry to the new name.
    final oldEntry = s.members.remove(oldName);
    s.members[newName] = PeerInfo(
      username: newName,
      bio: _effectiveBio(r),
      avatar: _effectiveAvatar(r),
      joinedAt: oldEntry?.joinedAt ?? DateTime.now(),
      color: 0,
    );

    // Rewrite our own past messages + persisted history.
    if (oldName != newName) {
      _rewriteUsername(s, oldName, newName);
    }

    final store = _store ??= await RoomStore.load();
    await store.saveRoom(r);
    await store.setRoomAvatar(r.id, r.avatar);
    await store.setRoomBio(r.id, r.bio);
    await _persistMembers(s);

    // Let the other side know so it can rename our past messages too.
    if (s.mode == SessionMode.host) {
      s.host?.updateOwnerProfile(
        oldUsername: oldName,
        username: newName,
        bio: _effectiveBio(r),
        avatar: _effectiveAvatar(r),
      );
    } else if (s.mode == SessionMode.client) {
      s.client?.sendProfile(
        oldUsername: oldName,
        username: newName,
        bio: _effectiveBio(r),
        avatar: _effectiveAvatar(r),
        avatarData: _avatarDataFor(_effectiveAvatar(r)),
      );
    }

    notifyListeners();
  }

  /// Applies a `profile` update received from a peer: renames their roster
  /// entry and rewrites their past messages (in memory + on disk).
  Future<void> _applyProfileUpdate(
      ChatSession s, Map<String, dynamic> m) async {
    final oldName = (m['oldUsername'] as String? ?? '').trim();
    final newName = (m['username'] as String? ?? '').trim();
    if (oldName.isEmpty || newName.isEmpty) return;

    final existing = s.members.remove(oldName);
    var avatar = m['avatar'] as String?;
    final avatarData = m['avatarData'] as String?;
    if (avatarData != null &&
        avatarData.isNotEmpty &&
        !AppAssets.isAsset(avatar)) {
      final saved = await AppAssets.savePeerAvatar(newName, avatarData);
      if (saved != null) avatar = saved;
    }
    s.members[newName] = PeerInfo(
      username: newName,
      bio: (m['bio'] as String? ?? '').trim().isEmpty
          ? null
          : (m['bio'] as String).trim(),
      avatar: avatar,
      joinedAt: existing?.joinedAt ??
          DateTime.fromMillisecondsSinceEpoch(
            m['joinedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
      color: m['color'] as int? ?? existing?.color ?? 0,
    );

    if (oldName != newName) _rewriteUsername(s, oldName, newName);

    final store = _store ??= await RoomStore.load();
    await store.renameMessages(s.room.id, oldName, newName);
    await store.saveMembers(s.room.id, s.members.values.toList());
    notifyListeners();
  }

  void _rewriteUsername(ChatSession s, String oldName, String newName) {
    for (var i = 0; i < s.messages.length; i++) {
      final m = s.messages[i];
      if (!m.isSystem && m.username == oldName) {
        s.messages[i] = m.copyWith(username: newName);
      }
    }
  }

  Future<void> _persistMembers(ChatSession s) async {
    final store = _store ??= await RoomStore.load();
    await store.saveMembers(s.room.id, s.members.values.toList());
  }

  String? _effectiveBio(Room r) {
    final b = r.bio?.trim() ?? '';
    if (b.isNotEmpty) return b;
    final global = ThemeController.instance.settings.bio?.trim() ?? '';
    return global.isEmpty ? null : global;
  }

  String? _effectiveAvatar(Room r) =>
      r.avatar ?? ThemeController.instance.settings.avatar;

  static String? _avatarDataFor(String? avatar) {
    if (avatar == null || AppAssets.isAsset(avatar)) return null;
    try {
      final f = File(avatar);
      if (!f.existsSync()) return null;
      return base64Encode(f.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- lifecycle

  int _nextHostPort() {
    final used = _sessions.values
        .where((s) => s.mode == SessionMode.host)
        .map((s) => s.hostPort)
        .toSet();
    var p = AppConfig.hostPort;
    while (used.contains(p)) {
      p++;
    }
    return p;
  }

  /// Leaves one room (host or client). Only that session is torn down; other
  /// live rooms keep running.
  Future<void> leave([Room? target]) async {
    final r = target ?? _active?.room;
    if (r == null) return;
    final s = _sessions[r.id];
    if (s == null) return;
    await _dropSession(s);
  }

  /// Erases the user's own presence everywhere before wiping this device:
  /// their own messages are deleted on every server — rooms they joined (the
  /// host removes them for everyone) and rooms they host (their messages go
  /// while everyone else's stay) — then all local data is wiped.
  Future<void> eraseAllData() async {
    final all = _sessions.values.toList();
    for (final s in all) {
      final ownIds = s.messages
          .where((m) => m.mine && !m.isSystem)
          .map((m) => m.id)
          .where((id) => id.isNotEmpty)
          .toList();
      if (ownIds.isEmpty) continue;
      if (s.mode == SessionMode.host) {
        final h = s.host;
        if (h == null) continue;
        for (final id in ownIds) {
          h.deleteMessage(id);
        }
      } else if (s.mode == SessionMode.client && s.connected) {
        final c = s.client;
        if (c == null) continue;
        for (final id in ownIds) {
          c.sendDelete(id);
        }
      }
    }
    // Give the deletions a moment to flush over the Tor sockets.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await leaveAll();

    // Wipe all local persistent data (rooms, messages, members, settings).
    final store = await RoomStore.load();
    await store.eraseAll();
    await ThemeController.instance.resetAll();
  }

  /// Tears down every session and stops Tor. Used by "Erase everything".
  Future<void> leaveAll() async {
    final all = _sessions.values.toList();
    for (final s in all) {
      s.disposeSession();
      try {
        await s.host?.stop();
      } catch (_) {}
      try {
        await s.client?.close();
      } catch (_) {}
      await MediaStore.deleteRoom(s.room.id);
    }
    _sessions.clear();
    _active = null;
    await TorEngine.instance.stop();
    notifyListeners();
  }

  Future<void> _dropSession(ChatSession s) async {
    final id = s.room.id;
    final wasActive = _active == s;
    _sessions.remove(id);
    if (wasActive) _active = null;
    s.disposeSession();
    try {
      await s.host?.stop();
    } catch (_) {}
    try {
      await s.client?.close();
    } catch (_) {}
    if (s.mode == SessionMode.host) {
      await TorEngine.instance.stopHosting(id);
    } else {
      await TorEngine.instance.stopClient();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _sessions.values) {
      s.disposeSession();
    }
    _sessions.clear();
    _onServerDisconnect.close();
    super.dispose();
  }
}
