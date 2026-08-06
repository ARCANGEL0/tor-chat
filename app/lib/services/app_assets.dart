import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Bundled asset names and resolution helpers.
///
/// Wallpaper values: `null` = default color, `asset:<name>` = bundled
/// wallpaper, otherwise an absolute file path to a custom image.
///
/// Avatar values: `null`/`default` = bundled default pfp, `asset:<name>` =
/// bundled pfp, otherwise an absolute file path to a custom image.
class AppAssets {
  AppAssets._();

  static const String icon = 'assets/icon.png';
  static const String wiredLogo = 'assets/misc/wired.png';
  static const String pfpDefault = 'assets/pfp/1.png';

  static const List<String> wallpapers = [
    '1', '2', '3', '4', '5', '6', '7', '8',
  ];

  /// Bundled default chat pictures (assigned at random when a room is created
  /// without a custom uploaded picture).
  static const List<String> chatPictures = [
    '1', '2', '3', '4', '5',
  ];

  /// Bundled profile pictures, numbered without names (1.png, 2.png, ...).
  static final List<String> pfp = List.generate(14, (i) => '${i + 1}');

  /// True when [value] refers to one of the bundled pictures.
  static bool isBundledPfp(String? value) {
    if (!isAsset(value)) return false;
    final n = int.tryParse(value!.substring('asset:'.length));
    return n != null && n >= 1 && n <= pfp.length;
  }

  /// A random default chat picture (`asset:chats:<n>`).
  static String randomChatPicture() =>
      'asset:chats:${chatPictures[Random().nextInt(chatPictures.length)]}';

  /// True when [value] is one of the bundled chat pictures.
  static bool isBundledChatPicture(String? value) {
    if (value == null || !value.startsWith('asset:chats:')) return false;
    final n = int.tryParse(value.substring('asset:chats:'.length));
    return n != null && n >= 1 && n <= chatPictures.length;
  }

  static bool isAsset(String? value) => value != null && value.startsWith('asset:');

  /// Resolves a stored wallpaper value to an image provider (assumes it isn't
  /// the default color).
  static ImageProvider wallpaperProvider(String value) {
    if (isAsset(value)) {
      return AssetImage('assets/wallpapers/${value.substring('asset:'.length)}.jpg');
    }
    return FileImage(File(value));
  }

  /// Resolves a stored avatar value to an image provider (never null).
  static ImageProvider avatarProvider(String? value) {
    if (value != null && value.isNotEmpty && !isAsset(value)) {
      return FileImage(File(value));
    }
    final name = value != null && isBundledPfp(value)
        ? value.substring('asset:'.length)
        : '1';
    return AssetImage('assets/pfp/$name.png');
  }

  /// Resolves a stored chat-picture value (`asset:chats:<n>` or a file path)
  /// to an image provider. Falls back to the given [fallback] provider.
  static ImageProvider chatPictureProvider(String value, ImageProvider fallback) {
    if (isBundledChatPicture(value)) {
      final n = value.substring('asset:chats:'.length);
      return AssetImage('assets/chats/default$n.jpg');
    }
    if (!isAsset(value)) {
      final f = File(value);
      if (f.existsSync()) return FileImage(f);
    }
    return fallback;
  }

  /// Saves a peer's transmitted profile picture (base64 jpg) to the documents
  /// media folder. Returns the file path, or `null` on failure.
  static Future<String?> savePeerAvatar(
      String username, String base64Data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/media');
      await folder.create(recursive: true);
      final safe = username.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${folder.path}/peer_$safe.jpg');
      await file.writeAsBytes(base64Decode(base64Data));
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
