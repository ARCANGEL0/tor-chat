import 'dart:math';
import 'dart:typed_data';

/// A single chat line, either a user [ChatMessage.type] == 'message', a
/// system notice ('system'), or media ('media' — image or video shared through
/// the host).
class ChatMessage {
  final String type;
  final String username;
  final String text;
  final String ts;
  final bool mine;
  final String? rawColor;

  /// Stable identity used by edit/delete so every device can target the same
  /// message. New messages get a unique id; legacy persisted ones derive a
  /// deterministic one so edits/deletes still line up across devices.
  final String id;

  /// Media metadata (only when [type] == 'media').
  final String? mediaType; // 'image' | 'video'
  final String? mediaId;
  final String? mediaName;
  final int? mediaSize;
  final String? mediaMime;

  const ChatMessage({
    required this.type,
    required this.username,
    required this.text,
    required this.ts,
    this.id = '',
    this.mine = false,
    this.rawColor,
    this.mediaType,
    this.mediaId,
    this.mediaName,
    this.mediaSize,
    this.mediaMime,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {bool mine = false}) {
    final color = json['color'];
    return ChatMessage(
      type: json['type'] as String? ?? 'message',
      username: json['username'] as String? ?? '',
      text: json['text'] as String? ?? '',
      ts: json['ts'] as String? ?? '',
      id: json['id'] as String? ?? _legacyId(json),
      rawColor: color is String ? color : (color?.toString()),
      mine: json['mine'] as bool? ?? mine,
      mediaType: json['mediaType'] as String?,
      mediaId: json['mediaId'] as String?,
      mediaName: json['mediaName'] as String?,
      mediaSize: (json['mediaSize'] as num?)?.toInt(),
      mediaMime: json['mediaMime'] as String?,
    );
  }

  /// Deterministic id for history written before ids existed.
  static String _legacyId(Map<String, dynamic> json) =>
      'legacy-${json['ts']}-${json['username']}-${json['text']}';

  static String newId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';

  bool get isSystem => type == 'system';

  bool get isMedia => type == 'media';

  bool get isImage => isMedia && mediaType == 'image';

  bool get isVideo => isMedia && mediaType == 'video';

  ChatMessage copyWith({String? username, String? text, bool? mine}) =>
      ChatMessage(
        type: type,
        username: username ?? this.username,
        text: text ?? this.text,
        ts: ts,
        id: id,
        mine: mine ?? this.mine,
        rawColor: rawColor,
        mediaType: mediaType,
        mediaId: mediaId,
        mediaName: mediaName,
        mediaSize: mediaSize,
        mediaMime: mediaMime,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'username': username,
        'text': text,
        'ts': ts,
        'id': id,
        'color': rawColor,
        'mine': mine,
        if (mediaType != null) 'mediaType': mediaType,
        if (mediaId != null) 'mediaId': mediaId,
        if (mediaName != null) 'mediaName': mediaName,
        if (mediaSize != null) 'mediaSize': mediaSize,
        if (mediaMime != null) 'mediaMime': mediaMime,
      };

  @override
  String toString() => '$username: $text';
}

/// A user color sent by a host, which may be an ANSI escape code (from the
/// desktop node app) or an index into a palette.
class UserColor {
  final int? paletteIndex;

  const UserColor._(this.paletteIndex);

  static UserColor fromRaw(String? raw, int fallback) {
    if (raw == null) return UserColor._(fallback);
    final idx = int.tryParse(raw);
    if (idx != null) return UserColor._(idx);
    return UserColor._(fallback);
  }
}

/// Low-level byte helpers shared by the SOCKS + WebSocket handshakes.
class Bytes {
  static int readUint8(Uint8List b, int off) => b[off] & 0xff;

  static int readUint16(Uint8List b, int off) =>
      ((b[off] & 0xff) << 8) | (b[off + 1] & 0xff);
}
