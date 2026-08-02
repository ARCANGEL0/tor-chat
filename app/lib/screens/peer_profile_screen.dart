import 'package:flutter/material.dart';

import '../models/peer_info.dart';
import '../models/room.dart';
import '../services/chat_protocol.dart';
import '../services/room_store.dart';
import '../state/room_controller.dart';
import '../widgets/profile_avatar.dart';

/// A participant's profile card: name, profile picture, bio and when they
/// joined the chat. Opened by tapping someone's avatar in a conversation.
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
    final scheme = Theme.of(context).colorScheme;
    final peer = _peer;
    final username = widget.username;
    final color = peer?.color ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ProfileAvatar(
                      avatar: peer?.avatar,
                      initial: username,
                      size: 96,
                      color: _senderColor(scheme, color),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      username,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (peer?.bio != null && peer!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        peer.bio!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        'No bio yet.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _joinedLabel(peer),
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Color _senderColor(ColorScheme scheme, int color) {
    if (color >= 0 && color < kUserColorPalette.length) {
      return Color(kUserColorPalette[color]);
    }
    return scheme.tertiary;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
