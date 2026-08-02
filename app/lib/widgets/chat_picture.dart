import 'package:flutter/material.dart';

import '../services/app_assets.dart';

/// Circular chat/room picture. Shows the room's own picture (`asset:chats:<n>`
/// or an uploaded file), falling back to [fallbackAvatar] (e.g. the persona
/// picture) when unset.
class ChatPictureAvatar extends StatelessWidget {
  final String? picture;
  final String? fallbackAvatar;
  final String initial;
  final double size;
  final Color? color;

  const ChatPictureAvatar({
    super.key,
    required this.picture,
    this.fallbackAvatar,
    required this.initial,
    this.size = 34,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primary;
    final initial = this.initial.trim();
    final ImageProvider? provider = picture != null && picture!.isNotEmpty
        ? AppAssets.chatPictureProvider(
            picture!,
            AppAssets.avatarProvider(fallbackAvatar),
          )
        : null;

    Widget child;
    if (provider != null) {
      child = ClipOval(
        child: Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallback(bg, initial),
        ),
      );
    } else {
      child = _fallback(bg, initial);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.3), blurRadius: 5)],
      ),
      child: child,
    );
  }

  Widget _fallback(Color bg, String initial) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg, Color.lerp(bg, Colors.black, 0.3)!],
        ),
      ),
      child: Text(
        initial.isEmpty ? '?' : initial.characters.first.toUpperCase(),
        style: TextStyle(
          color: bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
