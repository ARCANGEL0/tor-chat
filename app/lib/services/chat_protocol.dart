import 'dart:convert';

/// Wire protocol used between OnionChat peers. Mirrors the desktop `chat.js`
/// messages so mobile clients can talk to desktop hosts and vice versa.
class ChatProtocol {
  static const kAuth = 'auth';
  static const kPrompt = 'prompt';
  static const kUsername = 'username';
  static const kReady = 'ready';
  static const kAuthFailed = 'auth_failed';
  static const kMessage = 'message';
  static const kSystem = 'system';
  static const kMember = 'member';

  /// A shared photo/video. The bytes live on the host; this message only
  /// carries metadata (id + type), so the payload never touches the WebSocket.
  static const kMedia = 'media';

  /// A participant changed their persona (name, bio or picture) mid-chat.
  /// Carries `oldUsername` plus the member fields, so everyone can rename that
  /// user's past messages too.
  static const kProfile = 'profile';

  /// A message was edited. Carries `messageId` + new `text`. No "edited" badge
  /// is shown anywhere — the change is silent and anonymous.
  static const kEdit = 'edit';

  /// A message was deleted. Carries `messageId` only; recipients remove it as
  /// if it never existed.
  static const kDelete = 'delete';

  /// Host tells a connecting client its entry is awaiting approval.
  static const kPending = 'pending';

  /// Host rejected a joining client.
  static const kDenied = 'denied';

  /// Host wiped every photo/video in the room (everyone deletes media
  /// messages, their local media caches and the host's stored bytes).
  static const kDeleteAllMedia = 'delete_all_media';

  /// Host wiped every message in the room (everyone clears the whole chat).
  static const kDeleteAllMessages = 'delete_all_messages';

  static String encodeAuth(String? password) =>
      jsonEncode({'type': kAuth, 'password': password});

  static String encodeUsername(
    String username, {
    String? bio,
    String? avatar,
    String? avatarData,
  }) =>
      jsonEncode({
        'type': kUsername,
        'username': username,
        'bio': ?bio,
        'avatar': ?avatar,
        'avatarData': ?avatarData,
      });

  static String encodeMessage(String text, {String? id}) =>
      jsonEncode({'type': kMessage, 'text': text, 'id': ?id});

  /// Builds a media message. [mediaType] is 'image' or 'video'; the payload
  /// itself is fetched over HTTP from the host via [mediaId].
  static String encodeMedia({
    required String mediaId,
    required String mediaType,
    String? name,
    int? size,
    String? mime,
    String? id,
  }) =>
      jsonEncode({
        'type': kMedia,
        'mediaId': mediaId,
        'mediaType': mediaType,
        if (name != null && name.isNotEmpty) 'mediaName': name,
        'mediaSize': ?size,
        if (mime != null && mime.isNotEmpty) 'mediaMime': mime,
        'id': ?id,
      });

  static String encodeEdit({
    required String messageId,
    required String text,
  }) =>
      jsonEncode({
        'type': kEdit,
        'messageId': messageId,
        'text': text,
      });

  static String encodeDelete({required String messageId}) =>
      jsonEncode({'type': kDelete, 'messageId': messageId});

  /// Builds a member-entry map (roster) for [kReady] and [kMember] messages.
  static Map<String, dynamic> memberJson({
    required String username,
    required int color,
    String? bio,
    String? avatar,
    String? avatarData,
    required int joinedAt,
  }) =>
      {
        'username': username,
        'color': color,
        'bio': ?bio,
        'avatar': ?avatar,
        'avatarData': ?avatarData,
        'joinedAt': joinedAt,
      };
}

/// Picks a pleasant hue for a user, cycling through a fixed palette so
/// different participants are visually distinct.
const List<int> kUserColorPalette = [
  0xFF26C6DA, // cyan
  0xFFFFB74D, // orange
  0xFFBA68C8, // purple
  0xFF81C784, // green
  0xFFF06292, // pink
  0xFF90A4AE, // blue-grey
  0xFFFFD54F, // amber
  0xFF4FC3F7, // light-blue
];
