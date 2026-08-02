import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/chat_message.dart';
import '../models/room.dart';
import '../services/room_store.dart';
import '../services/sound_service.dart';
import '../services/wallpaper_lib.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/chat_picture.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/profile_avatar.dart';
import 'chat_settings_screen.dart';
import 'image_crop_screen.dart';
import 'peer_profile_screen.dart';
import 'profile_screen.dart';
import 'wallpaper_picker_screen.dart';

/// WhatsApp-style conversation screen. In host mode the owner sees everyone
/// who joined; in client mode the app connects to the owner's room via Tor.
class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<void>? _disconnectSub;
  bool _canSend = false;
  bool _sendingMedia = false;

  /// "Sending 2 of 5…" while a multi-file batch uploads.
  String? _sendingLabel;
  late String? _wallpaper = widget.room.wallpaper;

  @override
  void initState() {
    super.initState();
    RoomController.visibleRoomId = widget.room.id;
    final c = RoomController.instance;
    if (c.room?.id != widget.room.id) {
      _resumeSession();
    }
    // If the server goes offline, return to the home screen (a warning is
    // shown there via RoomController.pendingDisconnect).
    _disconnectSub = c.onServerDisconnect.listen((_) {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
    _inputController.addListener(() {
      final can = _inputController.text.trim().isNotEmpty;
      if (can != _canSend && mounted) {
        setState(() => _canSend = can);
      }
    });
  }

  /// Attach to (or resume) this room's session. If it's still alive from a
  /// previous visit it is simply focused; otherwise a fresh host/client
  /// session is started. Other rooms keep running untouched.
  Future<void> _resumeSession() async {
    final c = RoomController.instance;
    await c.openRoom(widget.room);
    final store = await RoomStore.load();
    await store.saveRoom(widget.room);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (RoomController.visibleRoomId == widget.room.id) {
      RoomController.visibleRoomId = null;
    }
    _disconnectSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    RoomController.instance.send(text);
    SoundService.instance.send();
    _inputController.clear();
    _scrollToBottom(animated: true);
  }

  static const _maxAttachFiles = 10;

  Future<void> _attach() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    var files = result.files;
    if (files.length > _maxAttachFiles) {
      files = files.sublist(0, _maxAttachFiles);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Up to $_maxAttachFiles files at once — sending the first $_maxAttachFiles.'),
        ),
      );
    }
    // Validate every file up front so an unsupported/oversized one aborts the
    // whole batch cleanly instead of half-sending.
    if (!mounted) return;
    final batch = <PlatformFile>[];
    for (final file in files) {
      final mime = _mediaMime((file.extension ?? '').toLowerCase());
      if (mime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only photos and videos are supported.')),
        );
        return;
      }
      if (file.size > 64 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is too large (max 64 MB).')),
        );
        return;
      }
      batch.add(file);
    }
    if (!mounted || batch.isEmpty) return;

    setState(() {
      _sendingMedia = true;
      _sendingLabel = batch.length > 1 ? 'Sending 1 of ${batch.length}…' : null;
    });
    try {
      for (var i = 0; i < batch.length; i++) {
        final file = batch[i];
        final path = file.path;
        if (path == null) continue;
        final mime = _mediaMime((file.extension ?? '').toLowerCase())!;
        final bytes = await File(path).readAsBytes();
        if (!mounted) return;
        var sendBytes = bytes;
        if (mime.startsWith('image/')) {
          final cropped = await ImageCropScreen.crop(
            context,
            image: bytes,
            circle: false,
            title: 'Edit image',
          );
          if (cropped == null) continue; // user canceled this one
          sendBytes = cropped;
        }
        if (batch.length > 1 && mounted) {
          setState(() => _sendingLabel = 'Sending ${i + 1} of ${batch.length}…');
        }
        try {
          await _sendMediaBytes(
            sendBytes,
            mediaType: mime.startsWith('image/') ? 'image' : 'video',
            name: file.name,
            mime: mime,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not send ${file.name}: $e')),
            );
          }
          break; // a failed upload usually means the next will fail too
        }
      }
      if (mounted) _scrollToBottom(animated: true);
    } finally {
      if (mounted) {
        setState(() {
          _sendingMedia = false;
          _sendingLabel = null;
        });
      }
    }
  }

  static String? _mediaMime(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'bmp' => 'image/bmp',
        'heic' || 'heif' => 'image/heic',
        'mp4' => 'video/mp4',
        'webm' => 'video/webm',
        'mkv' => 'video/x-matroska',
        'mov' => 'video/quicktime',
        '3gp' => 'video/3gpp',
        'avi' => 'video/x-msvideo',
        _ => null,
      };

  Future<void> _sendMediaBytes(
    Uint8List bytes, {
    required String mediaType,
    required String name,
    required String mime,
  }) async {
    final c = RoomController.instance;
    final canSend = c.isHost || (c.client?.isConnected ?? false);
    if (!canSend) return;
    await c.sendMedia(
      bytes,
      mediaType: mediaType,
      name: name,
      mime: mime,
    );
    SoundService.instance.send();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  /// Explicitly leave the room: stops hosting (disconnecting everyone) or the
  /// client session, stops Tor, and returns home. The back button does NOT do
  /// this — it only closes the screen while the room keeps running.
  Future<void> _leave() async {
    final c = RoomController.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.isHost ? 'Leave room?' : 'Disconnect?'),
        content: Text(c.isHost
            ? 'This stops hosting and everyone in the room will be disconnected. '
                'Your message history stays saved.'
            : 'You will leave this chat. Your message history stays saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await RoomController.instance.leave(widget.room);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goBack() {
    // Keep the session (and hosting) alive in the background.
    Navigator.of(context).pop();
  }

  void _showInvite() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => InviteSheet(room: widget.room),
    );
  }

  String? get _effectiveWallpaper =>
      _wallpaper ?? ThemeController.instance.settings.globalWallpaper;

  Future<void> _openChatSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatSettingsScreen(room: widget.room)),
    );
    // The settings screen may have changed the per-chat wallpaper on the same
    // Room object; reflect it here.
    if (mounted) setState(() => _wallpaper = widget.room.wallpaper);
  }

  Future<void> _changeWallpaper() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => WallpaperPickerScreen(current: _wallpaper),
      ),
    );
    if (result == null) return; // canceled
    final wallpaper = result == WallpaperPickerScreen.kDefault ? null : result;
    setState(() => _wallpaper = wallpaper);
    // Keep every copy of the room in sync so later saveRoom() calls don't
    // overwrite this with a stale wallpaper value.
    widget.room.wallpaper = wallpaper;
    RoomController.instance.room?.wallpaper = wallpaper;
    final store = await RoomStore.load();
    await store.setRoomWallpaper(widget.room.id, wallpaper);
  }

  void _openPeerProfile(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PeerProfileScreen(room: widget.room, username: username),
      ),
    );
  }

  /// Opens a slide-in panel from the right listing everyone in the room.
  void _showMembers() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Members',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.82,
              child: _MembersPanel(
                onMemberTap: (username) {
                  Navigator.of(ctx).pop();
                  _openMemberProfile(username);
                },
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  void _openMemberProfile(String username) {
    final c = RoomController.instance;
    if (username == c.room?.username) {
      _openMyProfile();
      return;
    }
    _openPeerProfile(username);
  }

  void _openMyProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _copyMessage(ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final controller = TextEditingController(text: msg.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    RoomController.instance.editMessage(msg.id, result);
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'This removes the message for everyone in the room.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    RoomController.instance.deleteMessage(msg.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = RoomController.instance;
    final scheme = Theme.of(context).colorScheme;
    final tc = ThemeController.instance;
    final chatHeader = tc.settings.chatHeader;
    final appBarBackground =
        chatHeader != null ? Color(chatHeader) : null;
    final chatHeaderText =
        tc.settings.chatHeaderText != null
            ? Color(tc.settings.chatHeaderText!)
            : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackground,
        foregroundColor: chatHeaderText ??
            (appBarBackground != null ? onColor(appBarBackground) : null),
        leading: BackButton(onPressed: _goBack),
        title: Row(
          children: [
            ChatPictureAvatar(
              picture: widget.room.chatPicture,
              fallbackAvatar: widget.room.avatar ??
                  ThemeController.instance.settings.avatar,
              initial: widget.room.namecode,
              size: 34,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.room.namecode,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.room.isOwner) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.shield, size: 14),
                      ],
                    ],
                  ),
                  Text(
                    _subtitle(c, scheme),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.room.isOwner)
            IconButton(
              tooltip: 'Invite',
              icon: const Icon(Icons.add),
              onPressed: _showInvite,
            ),
          IconButton(
            tooltip: 'Members',
            icon: const Icon(Icons.people_outline),
            onPressed: _showMembers,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'wallpaper') _changeWallpaper();
              if (v == 'chatSettings') _openChatSettings();
              if (v == 'leave') _leave();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'wallpaper',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.wallpaper),
                  title: Text('Change chat wallpaper'),
                ),
              ),
              if (widget.room.isOwner)
                const PopupMenuItem(
                  value: 'chatSettings',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Chat settings'),
                  ),
                ),
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Leave room'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (c.error != null) _ErrorBanner(text: c.error!),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Wallpaper(_effectiveWallpaper).background(context),
                  ListenableBuilder(
                    listenable: c,
                    builder: (context, _) {
                      _scrollToBottom();
                      if (c.messages.isEmpty) {
                        return _WelcomeBubble(
                          isHost: c.isHost,
                          connected: c.connected,
                          pendingApproval: c.pendingApproval,
                        );
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        itemCount: c.messages.length,
                        itemBuilder: (context, i) {
                          final msg = c.messages[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: MessageBubble(
                              message: msg,
                              myName: c.room?.username,
                              myAvatar: c.room?.avatar ??
                                  ThemeController.instance.settings.avatar,
                              theirAvatar: c.members[msg.username]?.avatar,
                              onAvatarTap: (u) => _openPeerProfile(u),
                              onMyAvatarTap: _openMyProfile,
                              onCopy: () => _copyMessage(msg),
                              onEdit: () => _editMessage(msg),
                              onDelete: () => _deleteMessage(msg),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            if (c.isHost && c.pendingJoins.isNotEmpty)
              _PendingJoins(
                requests: c.pendingJoins,
                onApprove: c.approveJoin,
                onDeny: c.denyJoin,
              ),
            if (_sendingMedia) ...[
              if (_sendingLabel != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _sendingLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              const LinearProgressIndicator(minHeight: 2),
            ],
            _InputBar(
              controller: _inputController,
              canSend: _canSend,
              onSend: _send,
              onAttach: _attach,
              enabled: c.connected || c.isHost,
              sending: _sendingMedia,
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(RoomController c, ColorScheme scheme) {
    if (c.isHost) {
      return '${c.participantCount} in room · hosting on Tor';
    }
    if (c.pendingApproval) {
      return 'Awaiting host approval…';
    }
    return c.connected
        ? 'Connected via Tor'
        : 'Connecting to onion service…';
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.4);
  }
}

class _WelcomeBubble extends StatelessWidget {
  final bool isHost;
  final bool connected;
  final bool pendingApproval;
  const _WelcomeBubble({
    required this.isHost,
    required this.connected,
    this.pendingApproval = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = isHost
        ? 'You are hosting this room anonymously on Tor.'
        : pendingApproval
            ? 'Awaiting for someone to approve your entry.'
            : connected
                ? 'Connected. Say hello!'
                : 'Connecting to onion service…';
    final icon = isHost
        ? Icons.wifi_tethering
        : pendingApproval
            ? Icons.hourglass_bottom
            : Icons.lock_open;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: scheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool enabled;
  final bool sending;

  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.onAttach,
    required this.enabled,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tc = ThemeController.instance;
    final s = tc.settings;
    final chatFont =
        s.chatFont.trim().isEmpty ? null : s.chatFont;
    // Defaults are purple-tinted so the footer matches the app theme instead
    // of plain grey; each can be overridden in Theme → Message area.
    final barColor = s.inputBar != null
        ? Color(s.inputBar!)
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.35),
            scheme.surfaceContainer,
          );
    final textareaColor = s.inputTextarea != null
        ? Color(s.inputTextarea!)
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.20),
            scheme.surfaceContainerHigh,
          );
    final buttonColor = s.inputButton != null ? Color(s.inputButton!) : scheme.primary;
    final attachColor =
        s.inputAttach != null ? Color(s.inputAttach!) : scheme.primary;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: sending || !enabled ? null : onAttach,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: attachColor,
            tooltip: 'Share media',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 5,
              minLines: 1,
              style: TextStyle(
                fontFamily: chatFont,
                fontSize: s.chatFontSize,
              ),
              decoration: InputDecoration(
                hintText: enabled ? 'Message' : 'Connecting to onion service…',
                filled: true,
                fillColor: textareaColor,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedScale(
            scale: canSend ? 1 : 0.85,
            duration: const Duration(milliseconds: 150),
            child: IconButton.filled(
              onPressed: canSend && !sending ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: buttonColor,
                disabledBackgroundColor: scheme.surfaceContainerHighest,
              ),
              icon: const Icon(Icons.send_rounded),
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }
}

/// Join requests waiting for the host's approval, shown as notification-style
/// cards above the input bar.
class _PendingJoins extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onDeny;

  const _PendingJoins({
    required this.requests,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in requests) _PendingJoinCard(request: r, onApprove: onApprove, onDeny: onDeny),
        ],
      ),
    );
  }
}

class _PendingJoinCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onDeny;

  const _PendingJoinCard({
    required this.request,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final username = request['username'] as String? ?? 'Someone';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ProfileAvatar(
              avatar: request['avatar'] as String?,
              initial: username,
              size: 34,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'wants to join in.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Deny',
              onPressed: () => onDeny(username),
              icon: Icon(Icons.close, color: scheme.error),
            ),
            IconButton(
              tooltip: 'Approve',
              onPressed: () => onApprove(username),
              icon: Icon(Icons.check_circle, color: Colors.green.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide-in right panel listing everyone currently in the room.
class _MembersPanel extends StatelessWidget {
  final ValueChanged<String> onMemberTap;

  const _MembersPanel({required this.onMemberTap});

  @override
  Widget build(BuildContext context) {
    final c = RoomController.instance;
    final scheme = Theme.of(context).colorScheme;
    final s = ThemeController.instance.settings;
    final bgColor = s.membersBackground != null
        ? Color(s.membersBackground!)
        : const Color(0xFFD1BCFD); // rgb(209, 188, 253) — light lavender
    final textColor =
        s.membersText != null ? Color(s.membersText!) : onColor(bgColor);
    final headerColor = s.membersHeader != null
        ? Color(s.membersHeader!)
        : const Color(0xFF4A148C); // deep purple, readable on lavender
    final iconColor = s.membersIcon != null
        ? Color(s.membersIcon!)
        : const Color(0xFF4A148C);
    final dimmed = textColor.withValues(alpha: 0.7);
    final hasWallpaper = s.membersWallpaper != null &&
        s.membersWallpaper!.isNotEmpty;

    final radius =
        const BorderRadius.horizontal(left: Radius.circular(20));
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Icon(Icons.people_outline, color: iconColor),
              const SizedBox(width: 8),
              Text(
                'Members (${c.members.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: headerColor),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: headerColor.withValues(alpha: 0.2)),
        Expanded(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final members = c.members.values.toList()
                ..sort((a, b) => a.username.compareTo(b.username));
              if (members.isEmpty) {
                return Center(
                  child: Text('No members yet.', style: TextStyle(color: dimmed)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: members.length,
                itemBuilder: (context, i) {
                  final m = members[i];
                  final isHost = c.isHost && m.username == c.room?.username;
                  return ListTile(
                    leading: ProfileAvatar(
                      avatar: m.avatar,
                      initial: m.username,
                      size: 38,
                      color: scheme.primary,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.username,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (isHost) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.shield, size: 14, color: iconColor),
                        ],
                      ],
                    ),
                    subtitle: m.bio == null || m.bio!.isEmpty
                        ? null
                        : Text(
                            m.bio!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: dimmed),
                          ),
                    onTap: () => onMemberTap(m.username),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasWallpaper)
            Wallpaper(s.membersWallpaper).background(context)
          else
            ColoredBox(color: bgColor),
          if (hasWallpaper)
            ColoredBox(color: bgColor.withValues(alpha: 0.88)),
          content,
        ],
      ),
    );
  }
}
