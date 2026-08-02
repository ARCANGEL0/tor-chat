import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/chat_message.dart';
import '../services/chat_protocol.dart';
import '../state/chat_theme.dart';
import '../state/theme_controller.dart';
import 'media_content.dart';
import 'profile_avatar.dart';

/// A single chat line: system notices, sent messages (right) and received
/// messages (left). Each message shows an avatar, the sender's username and a
/// timestamp in a small header above the text, like a modern messenger.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String? myAvatar;

  /// The current display name of the local user. Own messages show this
  /// (live-updating when the persona changes) instead of a fixed "You".
  final String? myName;

  /// Avatar of the sender for received messages (from the roster when known).
  final String? theirAvatar;

  /// Called when the sender's avatar (left side) is tapped.
  final ValueChanged<String>? onAvatarTap;

  /// Called when your own avatar (right side) is tapped.
  final VoidCallback? onMyAvatarTap;

  /// Long-press menu actions (handled by the screen).
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.myAvatar,
    this.myName,
    this.theirAvatar,
    this.onAvatarTap,
    this.onMyAvatarTap,
    this.onCopy,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _SystemNotice(text: message.text);

    final scheme = Theme.of(context).colorScheme;
    final chat = ChatTheme.of(context);
    final mine = message.mine;
    final bubbleColor = mine ? chat.myBubble : chat.theirBubble;
    final bubbleText = mine ? chat.myBubbleText : chat.theirBubbleText;
    final senderColor = mine ? chat.myBubble : _senderColor(scheme);
    final tc = ThemeController.instance;
    final chatFont = tc.settings.chatFont.trim();
    final chatFontSize = tc.settings.chatFontSize;
    final chatTextColor = tc.settings.chatTextColor != null
        ? Color(tc.settings.chatTextColor!)
        : null;
    final showTs = message.ts.isNotEmpty;
    final mineName = myName == null || myName!.trim().isEmpty
        ? 'You'
        : myName!.trim();
    final name = mine ? mineName : message.username;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.fromLTRB(13, 6, 13, 9),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: mine ? bubbleText : senderColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (showTs) ...[
                const SizedBox(width: 6),
                Text(
                  message.ts,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: mine
                        ? bubbleText.withValues(alpha: 0.75)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          if (message.isMedia)
            MediaContent(message: message)
          else
            Text(
              message.text,
              style: TextStyle(
                fontSize: chatFontSize,
                height: 1.3,
                color: chatTextColor ?? bubbleText,
                fontFamily: chatFont.isEmpty ? null : chatFont,
              ),
            ),
        ],
      ),
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!mine) ...[
          InkWell(
            onTap: onAvatarTap == null
                ? null
                : () => onAvatarTap!(message.username),
            customBorder: const CircleBorder(),
            child: ProfileAvatar(
              avatar: theirAvatar,
              initial: _initialOf(message.username),
              size: 34,
              color: senderColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: bubble),
        if (mine) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onMyAvatarTap,
            customBorder: const CircleBorder(),
            child: ProfileAvatar(
              avatar: myAvatar,
              initial: 'You',
              size: 34,
              color: senderColor,
            ),
          ),
        ],
      ],
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: _hasMenu ? () => _showMenu(context) : null,
        child: row,
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(
          begin: mine ? 0.5 : -0.5,
          end: 0,
          duration: 220.ms,
          curve: Curves.easeOut,
        );
  }

  bool get _hasMenu => onCopy != null || onEdit != null || onDelete != null;

  void _showMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.mine;
    final isText = !message.isMedia;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isText && onCopy != null)
              ListTile(
                leading: Icon(Icons.copy_rounded, color: scheme.primary),
                title: const Text('Copy message'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  onCopy!();
                },
              ),
            if (isText && mine && onEdit != null)
              ListTile(
                leading: Icon(Icons.edit_outlined, color: scheme.primary),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  onEdit!();
                },
              ),
            if (mine && onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text(
                  'Delete message',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _initialOf(String username) {
    final s = username.trim();
    if (s.isEmpty) return '?';
    return s.characters.first.toUpperCase();
  }

  Color _senderColor(ColorScheme scheme) {
    final idx = int.tryParse(message.rawColor ?? '');
    if (idx != null && idx >= 0 && idx < kUserColorPalette.length) {
      return Color(kUserColorPalette[idx]);
    }
    return scheme.tertiary;
  }
}

class _SystemNotice extends StatelessWidget {
  final String text;

  const _SystemNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
