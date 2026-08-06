import 'package:flutter/material.dart';

import '../services/app_assets.dart';
import '../state/theme_controller.dart';
import '../themes/theme_style.dart';

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
    final isLain =
        ThemeStyle.fromId(ThemeController.instance.settings.themeStyle) ==
            ThemeStyle.lain;
    final radius = BorderRadius.circular(size * 0.22);
    final shape = isLain ? BoxShape.rectangle : BoxShape.circle;

    Widget child;
    if (hasImage) {
      final image = Image(
        image: AppAssets.avatarProvider(avatar),
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _fallback(bg, initial, shape, radius),
      );
      child = isLain
          ? ClipRRect(borderRadius: radius, child: image)
          : ClipOval(child: image);
    } else {
      child = _fallback(bg, initial, shape, radius);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: isLain ? radius : null,
        boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.3), blurRadius: 5)],
      ),
      child: child,
    );
  }

  Widget _fallback(
      Color bg, String initial, BoxShape shape, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? radius : null,
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