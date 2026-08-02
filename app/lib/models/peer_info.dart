/// A participant in a chat room, as seen from this device: their persona
/// (name, bio, profile picture) and when they joined the room.
class PeerInfo {
  final String username;
  final String? bio;

  /// `null`/`asset:<name>`/file path — same format as avatars elsewhere.
  final String? avatar;
  final DateTime joinedAt;

  /// Palette index used for the sender's name color (0 = host/owner).
  final int color;

  const PeerInfo({
    required this.username,
    this.bio,
    this.avatar,
    required this.joinedAt,
    this.color = 0,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'bio': bio,
        'avatar': avatar,
        'joinedAt': joinedAt.toIso8601String(),
        'color': color,
      };

  factory PeerInfo.fromJson(Map<String, dynamic> json) => PeerInfo(
        username: json['username'] as String? ?? '',
        bio: json['bio'] as String?,
        avatar: json['avatar'] as String?,
        joinedAt:
            DateTime.tryParse(json['joinedAt'] as String? ?? '') ?? DateTime.now(),
        color: json['color'] as int? ?? 0,
      );
}
