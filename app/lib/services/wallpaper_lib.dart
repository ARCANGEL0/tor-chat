import 'dart:io';

import 'package:flutter/material.dart';

import '../state/theme_controller.dart';
import 'app_assets.dart';

/// Represents a chat background.
///
/// Stored value formats:
///  - `null`        -> default: the chat background color (accent by default)
///  - `asset:<name>` -> a bundled wallpaper (see [AppAssets.wallpapers])
///  - anything else -> absolute path to a custom (cropped) image
class Wallpaper {
  final String? value;

  const Wallpaper(this.value);

  bool get isImage => value != null && value!.isNotEmpty && !AppAssets.isAsset(value);

  bool get isBundled => AppAssets.isAsset(value);

  /// The widget to paint behind a chat.
  Widget background(BuildContext context) {
    if (isBundled) {
      return Image.asset(
        'assets/wallpapers/${value!.substring('asset:'.length)}.jpg',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
      );
    }
    if (isImage) {
      final file = File(value!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
        );
      }
    }
    // Default: a solid color — the chat background override, or the accent.
    final tc = ThemeController.instance;
    final color = tc.settings.chatBackground != null
        ? Color(tc.settings.chatBackground!)
        : Color(tc.settings.accentColor);
    return ColoredBox(color: color);
  }
}
