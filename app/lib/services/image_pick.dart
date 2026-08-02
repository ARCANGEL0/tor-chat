import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/image_crop_screen.dart';

/// Picks an image from the gallery, opens the in-app crop window ([circle] =
/// circular silhouette for avatars/chat pictures, free rectangle for
/// wallpapers), then copies the result into the app's documents directory and
/// returns its absolute path. Returns `null` if the user cancels.
Future<String?> pickAndCropImage(
  BuildContext context, {
  bool circle = true,
}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 4096,
    maxHeight: 4096,
  );
  if (picked == null || !context.mounted) return null;

  final bytes = await File(picked.path).readAsBytes();
  if (!context.mounted) return null;

  final cropped = await ImageCropScreen.crop(
    context,
    image: bytes,
    circle: circle,
    title: circle ? 'Crop picture' : 'Crop wallpaper',
  );
  if (cropped == null) return null; // canceled

  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/media');
  await folder.create(recursive: true);
  final ext = circle || picked.path.toLowerCase().endsWith('.png')
      ? 'png'
      : 'jpg';
  final dest = '${folder.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';
  await File(dest).writeAsBytes(cropped);
  return dest;
}
