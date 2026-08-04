import 'package:flutter/material.dart';

import '../models/peer_info.dart';
import '../models/room.dart';
import '../services/chat_protocol.dart';
import '../services/room_store.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/profile_avatar.dart';

/// A participant's profile card: name, profile picture, bio and when they
/// joined the chat. Rendered as a stylized card inside the blurred overlay
/// opened from the chat.
class PeerProfileScreen extends StatefulWidget {
  final Room room;
  final String username;

  const PeerProfileScreen({
    super.key,
    required this.room,
    required this.username,
  });

  @override
  State<PeerProfileScreen> createState() => _PeerProfileScreenState();
}

class _PeerProfileScreenState extends State<PeerProfileScreen> {
  PeerInfo? _peer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    PeerInfo? info = RoomController.instance.members[widget.username];
    if (info == null) {
      final store = await RoomStore.load();
      for (final p in store.loadMembers(widget.room.id)) {
        if (p.username == widget.username) {
          info = p;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() => _peer = info);
  }

  @override
  Widget build(BuildContext context) {
    final s = ThemeController.instance.settings;
    final peer = _peer;
    final username = widget.username;
    final color = peer?.color ?? 0;

    final bg =
        s.profileBackground != null
            ? Color(s.profileBackground!)
            : const Color(0xFF1A0F2E); // deep dark purple
    final textColor = s.profileText != null
        ? Color(s.profileText!)
        : const Color(0xFFFFFFFF);
    final muted = s.profileSecondaryText != null
        ? Color(s.profileSecondaryText!)
        : const Color(0xFFCBB8E8); // light purple
    final accent = s.profileAccent != null
        ? Color(s.profileAccent!)
        : const Color(0xFF7C3FED); // tor purple
    final profileFont = s.profileFont.trim().isEmpty ? null : s.profileFont;
    final fontSize = s.profileFontSize;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 26),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(bg, Colors.white, 0.06) ?? bg,
            Color.lerp(bg, Colors.black, 0.22) ?? bg,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
            child: ProfileAvatar(
              avatar: peer?.avatar,
              initial: username,
              size: 92,
              color: _senderColor(accent, color),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            username,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: profileFont,
              fontSize: fontSize + 6,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          if (peer?.bio != null && peer!.bio!.isNotEmpty)
            Text(
              peer.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: profileFont,
                fontSize: fontSize - 1,
                height: 1.45,
                color: muted,
              ),
            )
          else
            Text(
              'No bio yet.',
              style: TextStyle(
                fontFamily: profileFont,
                fontSize: fontSize - 1,
                fontStyle: FontStyle.italic,
                color: muted,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Container(
              height: 1,
              color: accent.withValues(alpha: 0.25),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.login, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                _joinedLabel(peer),
                style: TextStyle(
                  fontFamily: profileFont,
                  fontSize: fontSize - 2,
                  color: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _joinedLabel(PeerInfo? peer) {
    final joined = peer?.joinedAt;
    if (joined == null) {
      return 'Joined this chat recently';
    }
    final d = joined.toLocal();
    String date;
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      date = 'today';
    } else {
      date = '${_months[d.month - 1]} ${d.day}, ${d.year}';
    }
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Joined $date at $hh:$mm';
  }

  Color _senderColor(Color accent, int color) {
    if (color >= 0 && color < kUserColorPalette.length) {
      return Color(kUserColorPalette[color]);
    }
    return accent;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
