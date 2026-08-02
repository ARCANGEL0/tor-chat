import 'package:flutter/material.dart';

import '../services/app_assets.dart';

/// Circular avatar that shows a profile picture when available, otherwise a
/// colored circle with the user's initial (used for remote users whose picture
/// isn't known over the protocol).
class ProfileAvatar extends StatelessWidget {
  final String? avatar;
  final String initial;
  final double size;
  final Color? color;

  const ProfileAvatar({
    super.key,
    required this.avatar,
    required this.initial,
    this.size = 34,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primary;
    final initial = this.initial.trim();
    final hasImage = avatar != null && avatar!.isNotEmpty;

    Widget child;
    if (hasImage) {
      child = ClipOval(
        child: Image(
          image: AppAssets.avatarProvider(avatar),
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
