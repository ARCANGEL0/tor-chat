import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:flutter_animate/flutter_animate.dart';

import '../models/chat_message.dart';
import '../models/room.dart';
import '../services/room_store.dart';
import '../services/sound_service.dart';
import '../services/wallpaper_lib.dart';
import '../state/chat_theme.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../state/theme_style.dart';
import '../widgets/chat_picture.dart';
import '../widgets/app_toast.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/shape_box.dart';
import 'chat_settings_screen.dart';
import 'image_crop_screen.dart';
import 'peer_profile_screen.dart';
import 'profile_screen.dart';
import 'sticker_picker_screen.dart';
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
    
    // Show connecting toast for client rooms
    if (!c.isHost && !c.connected && !c.pendingApproval && c.error == null) {
      AppToast.show(context, 'Connecting to ${widget.room.name.isNotEmpty ? widget.room.name : widget.room.onion}…');
    }
    
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
      AppToast.show(context,
          'Up to $_maxAttachFiles files at once — sending the first $_maxAttachFiles.');
    }
    // Validate every file up front so an unsupported/oversized one aborts the
    // whole batch cleanly instead of half-sending.
    if (!mounted) return;
    final batch = <PlatformFile>[];
    for (final file in files) {
      final mime = _mediaMime((file.extension ?? '').toLowerCase());
      if (mime == null) {
        AppToast.show(context, 'Only photos and videos are supported.',
            style: AppToastStyle.error);
        return;
      }
      if (file.size > 64 * 1024 * 1024) {
        AppToast.show(context, 'File is too large (max 64 MB).',
            style: AppToastStyle.error);
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
            isSend: true,
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
            AppToast.show(context, 'Could not send ${file.name}: $e',
                style: AppToastStyle.error);
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
        title: Text(c.isHost ? 'Leave room?' : 'Leave room?'),
        content: Text(c.isHost
            ? 'This stops hosting and everyone in the room will be disconnected. '
                'Your message history stays saved.'
            : 'You will leave this chat. The room will be removed from your chat list. '
                'To rejoin, you will need the namecode and password, and the host must approve you again.'),
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

    await RoomController.instance.leaveAndRemove(widget.room);
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
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, _, _) =>
          _ProfileOverlay(room: widget.room, username: username),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        ),
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

  /// Centered "Are you sure you want to kick X?" card over a blurred backdrop.
  /// Only kicks (disconnect + remove from roster) if confirmed.
  static Future<void> confirmKick(BuildContext ctx, String username) async {
    final kicked = await showGeneralDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Kick $username',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (bctx, _, _) => Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: const ColoredBox(color: Colors.black38),
          ),
          Center(child: _KickCard(username: username)),
        ],
      ),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );
    if (kicked == true) {
      RoomController.instance.kickUser(username);
    }
  }

  void _openMyProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openStickers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerPickerScreen(
        onStickerSelected: _sendSticker,
      ),
    );
  }

  Future<void> _sendSticker(String packId, String stickerId, String imagePath) async {
    final c = RoomController.instance;
    if (!c.connected && !c.isHost) return;
    
    // Send as media message with type 'sticker'
    try {
      final bytes = await _resolveStickerBytes(imagePath);
      if (bytes != null) {
        await c.sendMedia(
          bytes,
          mediaType: 'image',
          name: 'sticker_$stickerId.webp',
          mime: 'image/webp',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to send sticker: $e', style: AppToastStyle.error);
      }
    }
  }

  Future<Uint8List?> _resolveStickerBytes(String imagePath) async {
    // Handle base64 encoded
    if (imagePath.startsWith('data:') || imagePath.length > 100 && !imagePath.contains('/')) {
      final base64 = imagePath.contains(',') ? imagePath.split(',').last : imagePath;
      return base64Decode(base64);
    }
    // Asset
    if (imagePath.startsWith('asset:')) {
      final data = await rootBundle.load(imagePath.substring(6));
      return data.buffer.asUint8List();
    }
    // File path
    if (imagePath.startsWith('/')) {
      return File(imagePath).readAsBytes();
    }
    return null;
  }

  void _copyMessage(ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    AppToast.show(context, 'Copied to clipboard');
  }  Future<void> _editMessage(ChatMessage msg) async {
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

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
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
              initial: widget.room.name,
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
                          widget.room.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.room.isOwner) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.dns, size: 15),
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
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final showConnectionOverlay =
                !c.isHost &&
                !c.connected &&
                !c.pendingApproval &&
                c.error == null;

            return Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    if (c.error != null) _ErrorBanner(text: c.error!),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Wallpaper(_effectiveWallpaper).background(context),
                          // Keep the last message above the floating composer.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 92),
                            child: ListenableBuilder(
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: MessageBubble(
                                        message: msg,
                                        myName: c.room?.username,
                                        myAvatar: c.room?.avatar ??
                                            ThemeController.instance.settings
                                                .avatar,
                                        theirAvatar:
                                            c.members[msg.username]?.avatar,
                                        onAvatarTap: (u) =>
                                            _openPeerProfile(u),
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Composer floats over the chat background.
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.isHost && c.pendingJoins.isNotEmpty)
                        _PendingJoins(
                          requests: c.pendingJoins,
                          onApprove: c.approveJoin,
                          onDeny: c.denyJoin,
                        ),
                      if (_sendingMedia) ...[
                        if (_sendingLabel != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
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
                      const SizedBox(height: 6),
                      _InputBar(
                        controller: _inputController,
                        canSend: _canSend,
                        onSend: _send,
                        onAttach: _attach,
                        onStickers: _openStickers,
                        enabled: c.connected || c.isHost,
                        sending: _sendingMedia,
                      ),
                    ],
                  ),
                ),
                if (showConnectionOverlay)
                  _ConnectionOverlay(
                    roomName: widget.room.name,
                    onionAddress: widget.room.onion,
                    isHost: c.isHost,
                  ),
              ],
            );
          },
        ),
      ),
    ));  // closes Scaffold + outer ListenableBuilder
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

class _ConnectionOverlay extends StatelessWidget {
  final String roomName;
  final String onionAddress;
  final bool isHost;

  const _ConnectionOverlay({
    required this.roomName,
    required this.onionAddress,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tc = ThemeController.instance;
    final style = ChatTheme.of(context).style;
    final accent = Color(tc.settings.accentColor);

    // Show chat name if available, otherwise show first part of onion address
    String displayName = roomName;
    if (displayName.isEmpty || displayName == onionAddress) {
      // Show abbreviated onion address
      if (onionAddress.length > 20) {
        displayName = '${onionAddress.substring(0, 20)}...';
      } else {
        displayName = onionAddress;
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // Prevent taps from passing through
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const ColoredBox(color: Colors.black26),
          ),
          // Connection card
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ShapeBox(
                  shape: style.cardShape,
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
                  borderColor: style.edgeColor ?? accent.withValues(alpha: 0.3),
                  borderWidth: style.borderWidth > 0 ? style.borderWidth : 1.5,
                  glowColor: style.glowColor,
                  glowBlur: style.glowBlur,
                  shadow: const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tor icon with pulse animation
                      _PulsingTorIcon(color: accent),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        'Connecting to $displayName',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        isHost
                            ? 'Starting Tor hidden service…'
                            : 'Establishing secure Tor connection…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      // Animated progress indicator
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status text
                      Text(
                        'This may take up to a minute…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.9, 0.9),
          curve: Curves.easeOutBack,
        );
  }
}

class _PulsingTorIcon extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingTorIcon({required this.color, this.size = 64});

  @override
  State<_PulsingTorIcon> createState() => _PulsingTorIconState();
}

class _PulsingTorIconState extends State<_PulsingTorIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withValues(alpha: 0.2),
                widget.color.withValues(alpha: 0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            size: widget.size * 0.5,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onStickers;
  final bool enabled;
  final bool sending;

  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.onAttach,
    required this.onStickers,
    required this.enabled,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tc = ThemeController.instance;
    final s = tc.settings;
    final style = ChatTheme.of(context).style;
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
    final buttonColor = s.inputButton != null ? Color(s.inputButton!) : scheme.primary;
    final attachColor =
        s.inputAttach != null ? Color(s.inputAttach!) : scheme.primary;
    final edge = style.edgeColor;
    final glow = style.glowColor;
    // The whole message area in one container. Textarea has no fill on purpose.
    return ShapeBox(
      shape: style.inputShape,
      color: barColor,
      borderColor: edge != null ? edge.withValues(alpha: 0.4) : null,
      borderWidth: style.borderWidth,
      glowColor: glow,
      glowBlur: style.glowBlur,
      shadow: const BoxShadow(
        color: Colors.black38,
        blurRadius: 18,
        offset: Offset(0, 6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: sending || !enabled ? null : onAttach,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: attachColor,
            tooltip: 'Share media',
            style: IconButton.styleFrom(shape: style.outlinedButtonShape),
          ),
          const SizedBox(width: 2),
          // Sticker button
          IconButton(
            onPressed: sending || !enabled ? null : onStickers,
            icon: const Icon(Icons.emoji_emotions_outlined),
            color: attachColor,
            tooltip: 'Stickers',
            style: IconButton.styleFrom(shape: style.outlinedButtonShape),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textCapitalization: TextCapitalization.sentences,
              enableSuggestions: false,
              autocorrect: false,
              maxLines: 5,
              minLines: 1,
              style: TextStyle(
                fontFamily: chatFont,
                fontSize: s.chatFontSize,
              ),
              decoration: InputDecoration(
                hintText: enabled ? 'Message' : 'Connecting to onion service…',
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedScale(
            scale: canSend ? 1 : 0.85,
            duration: const Duration(milliseconds: 150),
            child: ShapeBox(
              shape: style.buttonShape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(buttonColor, Colors.white, 0.14) ?? buttonColor,
                  Color.lerp(buttonColor, Colors.black, 0.18) ?? buttonColor,
                ],
              ),
              borderColor: edge != null ? edge.withValues(alpha: 0.6) : null,
              borderWidth: style.borderWidth,
              glowColor: style.glowColor ?? buttonColor.withValues(alpha: 0.35),
              glowBlur: style.glowBlur > 0 ? style.glowBlur : 10,
              child: InkWell(
                customBorder: style.outlinedButtonShape,
                onTap: canSend && !sending ? onSend : null,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: Colors.white.withValues(
                      alpha: canSend ? 1 : 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Join requests waiting for the host's approval, shown as notification-style
/// cards above the input bar. Colors follow the app theme (not grey).
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
    final s = ThemeController.instance.settings;
    final bg = s.inputBar != null ? Color(s.inputBar!) : const Color(0xFF1A0F2E);
    return Container(
      color: bg.withValues(alpha: 0.97),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in requests)
            _PendingJoinCard(
              key: ValueKey(r['username']),
              request: r,
              onApprove: onApprove,
              onDeny: onDeny,
            ),
        ],
      ),
    );
  }
}

class _PendingJoinCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onDeny;

  const _PendingJoinCard({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  State<_PendingJoinCard> createState() => _PendingJoinCardState();
}

class _PendingJoinCardState extends State<_PendingJoinCard> {
  bool _entered = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  void _resolve(bool approve) {
    if (_leaving) return;
    setState(() => _leaving = true);
    // Let the exit animation finish before the request is removed.
    Future.delayed(const Duration(milliseconds: 260), () {
      final username = widget.request['username'] as String? ?? 'Someone';
      if (approve) {
        widget.onApprove(username);
      } else {
        widget.onDeny(username);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ThemeController.instance.settings;
    final username = widget.request['username'] as String? ?? 'Someone';
    final cardBg = s.chatHeader != null
        ? Color(s.chatHeader!)
        : const Color(0xFF1A0F2E); // dark purple
    final accent = Color(s.accentColor);
    final textColor = s.mainText != null
        ? Color(s.mainText!)
        : const Color(0xFFFFFFFF);
    final muted = s.secondaryText != null
        ? Color(s.secondaryText!)
        : const Color(0xFFCBB8E8);
    final innerColor = Color.lerp(cardBg, Colors.white, 0.08) ?? cardBg;
    final visible = _entered && !_leaving;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0.6, 0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedScale(
            scale: visible ? 1 : 0.92,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: ShapeBox(
              shape: ChatTheme.of(context).style.cardShape,
              color: innerColor,
              borderColor: ChatTheme.of(context).style.edgeColor ??
                  accent.withValues(alpha: 0.45),
              borderWidth: ChatTheme.of(context).style.borderWidth > 0
                  ? ChatTheme.of(context).style.borderWidth
                  : 1,
              glowColor: ChatTheme.of(context).style.glowColor,
              glowBlur: ChatTheme.of(context).style.glowBlur,
              shadow: const BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  ProfileAvatar(
                    avatar: widget.request['avatar'] as String?,
                    initial: username,
                    size: 34,
                    color: accent,
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'wants to join in.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Deny',
                    onPressed: () => _resolve(false),
                    icon: Icon(Icons.close, color: scheme.error),
                  ),
                  IconButton(
                    tooltip: 'Approve',
                    onPressed: () => _resolve(true),
                    icon: Icon(Icons.check_circle, color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blurred full-screen overlay holding a peer's profile card. Tapping
/// anywhere outside the card closes it.
class _ProfileOverlay extends StatelessWidget {
  final Room room;
  final String username;

  const _ProfileOverlay({required this.room, required this.username});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: const ColoredBox(color: Colors.black38),
          ),
          SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: PeerProfileScreen(room: room, username: username),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny neon/grey presence label (ONLINE/OFFLINE) next to a member's name.
class _StatusPill extends StatelessWidget {  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}
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
        : onColor(bgColor); // white-ish on the default dark panel
    final iconColor = s.membersIcon != null
        ? Color(s.membersIcon!)
        : onColor(bgColor);
    final dimmed = textColor.withValues(alpha: 0.7);
    final onlineSet = c.onlineUsers;
    final onlineColor =
        s.onlineText != null ? Color(s.onlineText!) : const Color(0xFF39FF14);
    final offlineColor =
        s.offlineText != null ? Color(s.offlineText!) : const Color(0xFF9E9E9E);
    final hasWallpaper = s.membersWallpaper != null &&
        s.membersWallpaper!.isNotEmpty;

    final cardShape = ChatTheme.of(context).style.cardShape;
    // Drawer only shapes its left edge; the right is against the screen.
    final panelShape = cardShape.isBeveled
        ? cardShape
        : SurfaceShape.rounded(
            BorderRadius.only(
              topLeft: cardShape.rounded.topLeft,
              bottomLeft: cardShape.rounded.bottomLeft,
            ),
          );
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
              final members = c.members.values.toList()..sort((a, b) {
                  final ao = onlineSet.contains(a.username.toLowerCase());
                  final bo = onlineSet.contains(b.username.toLowerCase());
                  if (ao != bo) return ao ? -1 : 1;
                  return a.username.compareTo(b.username);
                });
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
                  final isOnline = onlineSet.contains(m.username.toLowerCase());
                  final canKick = c.isHost && !isHost;
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
                          const Text('👑', style: TextStyle(fontSize: 13)),
                        ],
                        const SizedBox(width: 8),
                        _StatusPill(
                          text: isOnline ? 'ONLINE' : 'OFFLINE',
                          color: isOnline ? onlineColor : offlineColor,
                        ),
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
                    trailing: canKick
                        ? IconButton(
                            tooltip: 'Kick ${m.username}',
                            icon: Icon(
                              Icons.person_remove_alt_1_outlined,
                              color: iconColor.withValues(alpha: 0.85),
                            ),
                            onPressed: () =>
                                _ChatScreenState.confirmKick(context, m.username),
                          )
                        : null,
                    onTap: () => onMemberTap(m.username),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return ShapeBox(
      shape: panelShape,
      color: bgColor,
      borderColor: ChatTheme.of(context).style.edgeColor?.withValues(alpha: 0.35),
      borderWidth: ChatTheme.of(context).style.borderWidth,
      glowColor: ChatTheme.of(context).style.glowColor,
      glowBlur: ChatTheme.of(context).style.glowBlur,
      shadow: const BoxShadow(
        color: Colors.black54,
        blurRadius: 24,
        offset: Offset(-8, 0),
      ),
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

/// Centered kick-confirmation card shown over a blurred backdrop.
class _KickCard extends StatelessWidget {
  final String username;

  const _KickCard({required this.username});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    final s = tc.settings;
    final style = ChatTheme.of(context).style;
    final bg = s.kickBackground != null
        ? Color(s.kickBackground!)
        : const Color(0xFF2A1F4D);
    final border = s.kickBorder != null
        ? Color(s.kickBorder!)
        : const Color(0xFF8B5CF6);
    final titleColor = s.kickTitle != null
        ? Color(s.kickTitle!)
        : const Color(0xFFE8DDF4);
    final bodyColor = s.kickBody != null
        ? Color(s.kickBody!)
        : const Color(0xFFBDB4D6);
    final iconColor = s.kickIcon != null
        ? Color(s.kickIcon!)
        : const Color(0xFFE23A5E);
    final buttonColor = s.kickButton != null
        ? Color(s.kickButton!)
        : const Color(0xFFE23A5E);
    final buttonTextColor = s.kickButtonText != null
        ? Color(s.kickButtonText!)
        : Colors.white;
    final cancelColor = s.kickCancel != null
        ? Color(s.kickCancel!)
        : const Color(0xFFCBB8E8);
    final font = s.kickFont.trim();
    final size = s.kickFontSize;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ShapeBox(
        shape: style.cardShape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg, Color.lerp(bg, const Color(0xFF000000), 0.18)!],
        ),
        borderColor: style.edgeColor ?? border.withValues(alpha: 0.45),
        borderWidth: style.borderWidth > 0 ? style.borderWidth : 1.2,
        glowColor: style.glowColor,
        glowBlur: style.glowBlur,
        shadow: const BoxShadow(
          color: Colors.black54,
          blurRadius: 26,
          offset: Offset(0, 10),
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_remove_alt_1_outlined, size: 36, color: iconColor),
            const SizedBox(height: 12),
            Text(
              'Kick $username?',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: titleColor,
                fontFamily: font.isEmpty ? null : font,
                fontSize: size,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'They will be disconnected from this room and removed from '
              'the member list.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: bodyColor,
                fontFamily: font.isEmpty ? null : font,
                fontSize: size * 0.92,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: cancelColor,
                      textStyle: TextStyle(
                        fontFamily: font.isEmpty ? null : font,
                        fontSize: size,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: buttonTextColor,
                      textStyle: TextStyle(
                        fontFamily: font.isEmpty ? null : font,
                        fontSize: size,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Kick'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
