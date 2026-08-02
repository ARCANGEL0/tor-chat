/// A saved chat room. Rooms are either hosted by this device (`isOwner`) or
/// remote rooms the user joined with a namecode + password.
class Room {
  final String id;
  String namecode;
  String onion;
  String password;
  bool isOwner;
  String username;
  DateTime createdAt;
  String? lastMessage;
  DateTime? lastMessageAt;

  /// Per-chat wallpaper: `null` (default), `asset:<name>` or a file path.
  String? wallpaper;

  /// This room's profile picture (persona). `null` = use the global default.
  String? avatar;

  /// The picture for this chat/room (`asset:chats:<n>` or a file path).
  /// `null` = use a bundled default.
  String? chatPicture;

  /// This room's bio (persona). `null`/empty = use the global default bio.
  String? bio;

  Room({
    required this.id,
    required this.namecode,
    required this.onion,
    required this.password,
    required this.isOwner,
    required this.username,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.wallpaper,
    this.avatar,
    this.chatPicture,
    this.bio,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'namecode': namecode,
        'onion': onion,
        'password': password,
        'isOwner': isOwner,
        'username': username,
        'createdAt': createdAt.toIso8601String(),
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'wallpaper': wallpaper,
        'avatar': avatar,
        'chatPicture': chatPicture,
        'bio': bio,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        namecode: json['namecode'] as String,
        onion: json['onion'] as String,
        password: json['password'] as String,
        isOwner: json['isOwner'] as bool? ?? false,
        username: json['username'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.tryParse(json['lastMessageAt'] as String)
            : null,
        wallpaper: json['wallpaper'] as String?,
        avatar: json['avatar'] as String?,
        chatPicture: json['chatPicture'] as String?,
        bio: json['bio'] as String?,
      );
}
