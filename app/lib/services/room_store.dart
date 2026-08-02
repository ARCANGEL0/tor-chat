import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/peer_info.dart';
import '../models/room.dart';

/// Persistent storage for saved rooms (and the user's display name) using
/// shared_preferences.
class RoomStore {
  static const _roomsKey = 'rooms';
  static const _usernameKey = 'username';
  static const _bioKey = 'bio';

  /// Maximum messages kept per room, so storage stays small.
  static const _maxMessagesPerRoom = 1000;

  final SharedPreferences _prefs;
  RoomStore._(this._prefs);

  static Future<RoomStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RoomStore._(prefs);
  }

  String? get username => _prefs.getString(_usernameKey);

  String? get bio => _prefs.getString(_bioKey);

  Future<void> setUsername(String name) async {
    await _prefs.setString(_usernameKey, name);
  }

  Future<void> setBio(String value) async {
    await _prefs.setString(_bioKey, value);
  }

  List<Room> getRooms() {
    final raw = _prefs.getString(_roomsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Room.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
            .compareTo(a.lastMessageAt ?? a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Room? getRoom(String id) {
    for (final r in getRooms()) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> saveRoom(Room room) async {
    final rooms = getRooms();
    rooms.removeWhere((r) => r.id == room.id);
    rooms.add(room);
    await _persist(rooms);
  }

  Future<void> deleteRoom(String id) async {
    final rooms = getRooms();
    rooms.removeWhere((r) => r.id == id);
    await _persist(rooms);
  }

  /// Updates the per-chat wallpaper for a room. `null` falls back to the
  /// global wallpaper.
  Future<void> setRoomWallpaper(String roomId, String? wallpaper) async {
    final rooms = getRooms();
    for (final r in rooms) {
      if (r.id == roomId) r.wallpaper = wallpaper;
    }
    await _persist(rooms);
  }

  /// Updates the per-room profile picture. `null` falls back to the global one.
  Future<void> setRoomAvatar(String roomId, String? avatar) async {
    final rooms = getRooms();
    for (final r in rooms) {
      if (r.id == roomId) r.avatar = avatar;
    }
    await _persist(rooms);
  }

  /// Updates the per-room bio. `null` falls back to the global one.
  Future<void> setRoomBio(String roomId, String? bio) async {
    final rooms = getRooms();
    for (final r in rooms) {
      if (r.id == roomId) r.bio = bio;
    }
    await _persist(rooms);
  }

  /// Updates the picture for a chat/room. `null` falls back to a bundled
  /// default.
  Future<void> setRoomChatPicture(String roomId, String? picture) async {
    final rooms = getRooms();
    for (final r in rooms) {
      if (r.id == roomId) r.chatPicture = picture;
    }
    await _persist(rooms);
  }

  Future<void> updateLastMessage(
      String roomId, String preview, DateTime at) async {
    final rooms = getRooms();
    for (final r in rooms) {
      if (r.id == roomId) {
        r.lastMessage = preview;
        r.lastMessageAt = at;
      }
    }
    await _persist(rooms);
  }

  Future<void> _persist(List<Room> rooms) async {
    final raw = jsonEncode(rooms.map((r) => r.toJson()).toList());
    await _prefs.setString(_roomsKey, raw);
  }

  // ------------------------------------------------------------ message history

  String _messagesKey(String roomId) => 'messages_$roomId';

  /// The persisted message history for a room (oldest first).
  List<ChatMessage> loadMessages(String roomId) {
    final raw = _prefs.getString(_messagesKey(roomId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Appends [message] to the room's history, keeping only the most recent
  /// [_maxMessagesPerRoom] messages.
  Future<void> addMessage(String roomId, ChatMessage message) async {
    final history = loadMessages(roomId);
    history.add(message);
    if (history.length > _maxMessagesPerRoom) {
      history.removeRange(0, history.length - _maxMessagesPerRoom);
    }
    await _prefs.setString(
      _messagesKey(roomId),
      jsonEncode(history.map((m) => m.toJson()).toList()),
    );
  }

  /// Renames [oldUsername] to [newUsername] in the room's persisted message
  /// history (used when a participant changes their display name mid-chat).
  Future<void> renameMessages(
      String roomId, String oldUsername, String newUsername) async {
    if (oldUsername == newUsername) return;
    final history = loadMessages(roomId);
    var changed = false;
    final updated = history.map((m) {
      if (!m.isSystem && m.username == oldUsername) {
        changed = true;
        return m.copyWith(username: newUsername);
      }
      return m;
    }).toList();
    if (changed) {
      await _prefs.setString(
        _messagesKey(roomId),
        jsonEncode(updated.map((m) => m.toJson()).toList()),
      );
    }
  }

  /// Replaces [messageId] with [updated] in the room's history (used by edits).
  Future<void> updateMessage(
      String roomId, String messageId, ChatMessage updated) async {
    final history = loadMessages(roomId);
    var changed = false;
    final out = history.map((m) {
      if (m.id == messageId) {
        changed = true;
        return updated;
      }
      return m;
    }).toList();
    if (changed) {
      await _prefs.setString(
        _messagesKey(roomId),
        jsonEncode(out.map((m) => m.toJson()).toList()),
      );
    }
  }

  /// Removes [messageId] from the room's history (used by deletes).
  Future<void> removeMessage(String roomId, String messageId) async {
    final history = loadMessages(roomId);
    final before = history.length;
    history.removeWhere((m) => m.id == messageId);
    if (history.length != before) {
      await _prefs.setString(
        _messagesKey(roomId),
        jsonEncode(history.map((m) => m.toJson()).toList()),
      );
    }
  }

  /// Replaces the room's entire history (used when the host replays its
  /// authoritative list on rejoin).
  Future<void> replaceMessages(String roomId, List<ChatMessage> messages) async {
    final trimmed = messages.length > _maxMessagesPerRoom
        ? messages.sublist(messages.length - _maxMessagesPerRoom)
        : messages;
    await _prefs.setString(
      _messagesKey(roomId),
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  // ------------------------------------------------------------- roster/members

  String _membersKey(String roomId) => 'members_$roomId';

  /// The known participants of a room (from the last session).
  List<PeerInfo> loadMembers(String roomId) {
    final raw = _prefs.getString(_membersKey(roomId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PeerInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMembers(String roomId, List<PeerInfo> members) async {
    await _prefs.setString(
      _membersKey(roomId),
      jsonEncode(members.map((m) => m.toJson()).toList()),
    );
  }

  // ------------------------------------------------------------------- wipe-all

  /// Deletes every saved room, message, member and profile field.
  Future<void> eraseAll() async {
    await _prefs.clear();
  }
}
