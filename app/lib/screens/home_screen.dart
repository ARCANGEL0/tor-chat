import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/room.dart';
import '../services/room_store.dart';
import '../services/wallpaper_lib.dart';
import '../state/chat_theme.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../themes/theme_style.dart';
import '../widgets/app_logo.dart';
import '../widgets/chat_picture.dart';
import 'chat_screen.dart';
import 'connect_screen.dart';
import 'create_room_screen.dart';
import 'settings_screen.dart';
import 'theme_screen.dart';

/// Home: the list of saved rooms (WhatsApp-style) with an animated
/// create/connect action menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RoomStore? _store;
  List<Room> _rooms = [];
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await RoomStore.load();
    if (!mounted) return;
    setState(() {
      _store = store;
      _rooms = store.getRooms();
    });
  }

  Future<void> _refresh() async {
    final store = _store ??= await RoomStore.load();
    if (!mounted) return;
    setState(() {
      _rooms = store.getRooms();
    });
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
  }

  Future<void> _openRoom(Room room) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
    );
    _refresh();
    _showPendingWarning();
  }

  /// Shows a one-shot warning after the user was dropped from a room because
  /// its server went offline (see RoomController.onServerDisconnect).
  void _showPendingWarning() {
    final msg = RoomController.instance.takePendingDisconnect();
    if (msg == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cloud_off),
        title: const Text('Disconnected'),
        content: Text(msg),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClipOval(child: AppLogo(size: 26)),
            const SizedBox(width: 8),
            const Text('OnionChat'),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') _open(const SettingsScreen());
              if (v == 'theme') _open(const ThemeScreen());
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Theme'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) {
          final s = ThemeController.instance.settings;
          final content = _rooms.isEmpty
              ? const _EmptyState()
              : _RoomList(
                  rooms: _rooms,
                  onTap: _openRoom,
                  onChanged: _refresh,
                );
          final wallpaper = s.mainWallpaper;
          if (wallpaper == null || wallpaper.isEmpty) return content;
          return Stack(
            fit: StackFit.expand,
            children: [
              Wallpaper(wallpaper).background(context),
              // Light scrim so room names stay readable on busy images.
              const ColoredBox(color: Colors.black26),
              content,
            ],
          );
        },
      ),
      floatingActionButton: _ActionMenu(
        open: _menuOpen,
        onToggle: _toggleMenu,
        onCreate: () => _navigate(CreateRoomScreen()),
        onConnect: () => _navigate(ConnectScreen()),
      ),
    );
  }

  Future<void> _navigate(Widget screen) async {
    _toggleMenu();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    _refresh();
    _showPendingWarning();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    _refresh();
    _showPendingWarning();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 88, color: scheme.primary)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleY(begin: 1, end: 1.08)
                .scaleX(begin: 1, end: 0.96)
                .then()
                .scaleY(begin: 1.08, end: 1)
                .scaleX(begin: 0.96, end: 1)
                .swap(builder: (_, child) => child!)
                .shimmer(blendMode: BlendMode.srcATop)
                .animate()
                .fadeIn(duration: 600.ms),
            const SizedBox(height: 24),
            Text(
              'No rooms yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 500.ms)
                .slideY(begin: 0.3),
            const SizedBox(height: 12),
            Text(
              'Create a room to get an anonymous .onion address, or connect '
              'to a friend by namecode + password.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            )
                .animate()
                .fadeIn(delay: 350.ms, duration: 500.ms)
                .slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }
}

class _RoomList extends StatelessWidget {
  final List<Room> rooms;
  final void Function(Room) onTap;
  final VoidCallback onChanged;

  const _RoomList({
    required this.rooms,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rooms.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, i) {
        final room = rooms[i];
        final preview = room.lastMessage ?? (room.isOwner
            ? 'Hosting this room — tap to open'
            : 'Joined room');
        return Dismissible(
          key: ValueKey(room.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            final store = await RoomStore.load();
            await store.deleteRoom(room.id);
            onChanged();
            return true;
          },
          child: ListTile(
            onTap: () => onTap(room),
            leading: ChatPictureAvatar(
              picture: room.chatPicture,
              fallbackAvatar:
                  room.avatar ?? ThemeController.instance.settings.avatar,
              initial: room.name,
              size: 46,
              color: _avatarColor(context, room),
            ),
            title: Text(
              room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(room.lastMessageAt ?? room.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (room.isOwner)
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms);
  }

  Color _avatarColor(BuildContext context, Room room) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      const Color(0xFF7E57C2),
      const Color(0xFF00897B),
    ];
    var hash = 0;
    for (final c in room.name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    }
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Expandable speed-dial: Create Room / Connect.
class _ActionMenu extends StatefulWidget {
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onCreate;
  final VoidCallback onConnect;

  const _ActionMenu({
    required this.open,
    required this.onToggle,
    required this.onCreate,
    required this.onConnect,
  });

  @override
  State<_ActionMenu> createState() => _ActionMenuState();
}

class _ActionMenuState extends State<_ActionMenu> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = ChatTheme.of(context).style;

    if (style == ThemeStyle.matrix) return _buildMatrix();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.open) ...[
          _SpeedItem(
            label: 'Create Room',
            icon: Icons.add_chart,
            color: scheme.primary,
            onTap: widget.onCreate,
          )
              .animate()
              .fadeIn(duration: 160.ms)
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 220.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 12),
          _SpeedItem(
            label: 'Connect',
            icon: Icons.call_merge_rounded,
            color: scheme.tertiary,
            onTap: widget.onConnect,
          )
              .animate()
              .fadeIn(duration: 160.ms, delay: 60.ms)
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 220.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 12),
        ],
        AnimatedRotation(
          turns: widget.open ? 0.125 : 0,
          duration: const Duration(milliseconds: 220),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: FloatingActionButton(
              key: ValueKey(widget.open),
              onPressed: widget.onToggle,
              backgroundColor: widget.open ? Colors.redAccent : scheme.primary,
              shape: style.outlinedFabShape,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  widget.open ? Icons.close : Icons.chat_bubble,
                  key: ValueKey(widget.open),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatrix() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.open) ...[
          _MatrixMenuItem(label: 'CREATE ROOM', onTap: widget.onCreate),
          const SizedBox(height: 12),
          _MatrixMenuItem(
            label: 'CONNECT',
            onTap: widget.onConnect,
            delay: 80,
          ),
          const SizedBox(height: 16),
        ],
        _MatrixFab(open: widget.open, onToggle: widget.onToggle),
      ],
    );
  }
}

class _MatrixMenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final int delay;

  const _MatrixMenuItem({
    required this.label,
    required this.onTap,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF00FF41);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: neon,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 3,
              shadows: [
                Shadow(color: Color(0x9900FF41), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 2,
            height: 18,
            decoration: BoxDecoration(
              color: neon,
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(color: Color(0xAA00FF41), blurRadius: 8),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideX(
          begin: 0.9,
          end: 0,
          duration: 340.ms,
          delay: delay.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 220.ms, delay: delay.ms);
  }
}

class _MatrixFab extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;

  const _MatrixFab({required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF00FF41);
    const red = Color(0xFFFF3B30);
    final color = open ? red : neon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                open ? Icons.close : Icons.chat_bubble_outline_rounded,
                key: ValueKey(open),
                color: color,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: open ? 34 : 26,
          height: 2.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SpeedItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = ChatTheme.of(context).style;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: style.buttonShape.rippleRadius,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: color,
              shape: style.outlinedButtonShape,
              elevation: 4,
              child: InkWell(
                customBorder: style.outlinedButtonShape,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
