import 'package:flutter/material.dart';

import '../models/room.dart';
import '../services/app_assets.dart';
import '../services/image_pick.dart';
import '../services/room_store.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/chat_picture.dart';
import '../widgets/persona_editor.dart';
import 'wallpaper_picker_screen.dart';

/// Per-chat settings: the persona (display name, picture, bio) used in THIS
/// room, and this room's own wallpaper. Saving updates the running session
/// immediately (including past messages) and propagates to peers.
class ChatSettingsScreen extends StatefulWidget {
  final Room room;

  const ChatSettingsScreen({super.key, required this.room});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatar;
  late String? _chatPicture = widget.room.chatPicture;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = RoomController.instance.room ?? widget.room;
    final tc = ThemeController.instance;
    if (!mounted) return;
    _nameController.text = r.username;
    _bioController.text = r.bio ?? tc.settings.bio ?? '';
    _avatar = r.avatar ?? tc.settings.avatar;
    _chatPicture = r.chatPicture;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final r = RoomController.instance.room ?? widget.room;
    await RoomController.instance.updatePersona(
      username: _nameController.text,
      avatar: _avatar,
      bio: _bioController.text,
    );
    if (_chatPicture != null) {
      r.chatPicture = _chatPicture;
      RoomController.instance.room?.chatPicture = _chatPicture;
      final store = await RoomStore.load();
      await store.setRoomChatPicture(r.id, _chatPicture);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _uploadChatPicture() async {
    try {
      final path = await pickAndCropImage(context, circle: true);
      if (path == null || !mounted) return;
      setState(() => _chatPicture = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load that picture: $e')),
      );
    }
  }

  void _randomizeChatPicture() {
    setState(() => _chatPicture = AppAssets.randomChatPicture());
  }

  Future<void> _changeWallpaper() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => WallpaperPickerScreen(current: widget.room.wallpaper),
      ),
    );
    if (result == null || !mounted) return; // canceled
    final wallpaper = result == WallpaperPickerScreen.kDefault ? null : result;
    widget.room.wallpaper = wallpaper;
    RoomController.instance.room?.wallpaper = wallpaper;
    final store = await RoomStore.load();
    await store.setRoomWallpaper(widget.room.id, wallpaper);
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------- host room controls

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _confirmDisconnectEveryone() async {
    final ok = await _confirm(
      title: 'Disconnect everyone?',
      message: 'Everyone in the room will be disconnected. Your room keeps '
          'running and your message history stays saved.',
      action: 'Disconnect',
    );
    if (ok != true || !mounted) return;
    RoomController.instance.disconnectEveryone();
    _toast('Everyone was disconnected');
  }

  Future<void> _confirmDeleteAllMedia() async {
    final ok = await _confirm(
      title: 'Delete all media?',
      message: 'This removes every photo and video for everyone in the room, '
          'including from hosts\u2019 storage. This cannot be undone.',
      action: 'Delete media',
    );
    if (ok != true || !mounted) return;
    RoomController.instance.deleteAllMedia();
    _toast('All media was deleted');
  }

  Future<void> _confirmDeleteAllMessages() async {
    final ok = await _confirm(
      title: 'Delete all messages?',
      message: 'This erases the entire conversation for everyone in the room. '
          'This cannot be undone.',
      action: 'Delete messages',
    );
    if (ok != true || !mounted) return;
    RoomController.instance.deleteAllMessages();
    _toast('All messages were deleted');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat settings'),
        actions: [
          TextButton.icon(
            onPressed: _loaded ? _save : null,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const _Header('Profile in this chat'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PersonaEditor(
                      nameController: _nameController,
                      bioController: _bioController,
                      avatar: _avatar,
                      onAvatarChanged: (v) => setState(() => _avatar = v),
                      avatarLabel: widget.room.namecode,
                      hint: 'Pick a username for this chat…',
                      bioHint: 'Tell people a bit about yourself…',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Changes apply to this room only and update your past '
                      'messages here and on your friends\u2019 devices.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Divider(),
                  const _Header('Chat picture'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          ChatPictureAvatar(
                            picture: _chatPicture,
                            fallbackAvatar: _avatar,
                            initial: widget.room.namecode,
                            size: 48,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'The picture shown for this chat.',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Upload picture',
                            icon: const Icon(Icons.photo_library_outlined),
                            onPressed: _uploadChatPicture,
                          ),
                          IconButton(
                            tooltip: 'Random picture',
                            icon: const Icon(Icons.casino),
                            onPressed: _randomizeChatPicture,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  const _Header('Chat wallpaper'),
                  ListTile(
                    leading: const Icon(Icons.wallpaper),
                    title: const Text('Chat wallpaper'),
                    subtitle: Text(
                      widget.room.wallpaper == null
                          ? 'Use the wallpaper set in Settings'
                          : 'This chat uses its own wallpaper',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changeWallpaper,
                  ),
                  if (widget.room.isOwner) ...[
                    const Divider(),
                    const _Header('Room controls'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        'These actions apply to everyone in this room.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_off_outlined),
                      title: const Text('Disconnect everyone'),
                      subtitle:
                          const Text('Kick everyone out, keep hosting'),
                      onTap: _confirmDisconnectEveryone,
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_sweep_outlined,
                          color: scheme.error),
                      title: Text(
                        'Delete all media in this room',
                        style: TextStyle(color: scheme.error),
                      ),
                      subtitle:
                          const Text('Remove every photo and video for everyone'),
                      onTap: _confirmDeleteAllMedia,
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_forever_outlined,
                          color: scheme.error),
                      title: Text(
                        'Delete all messages',
                        style: TextStyle(color: scheme.error),
                      ),
                      subtitle:
                          const Text('Erase the whole conversation for everyone'),
                      onTap: _confirmDeleteAllMessages,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
