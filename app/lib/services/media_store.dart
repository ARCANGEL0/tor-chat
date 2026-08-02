import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Persists shared-media payloads in the app's private storage so history
/// keeps its images/videos after an app restart. Bytes stay on-device — this
/// is only a local cache of what the host served over Tor, never a server.
class MediaStore {
  static Future<Directory> _dir(String roomId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/media/${_sanitize(roomId)}');
    await dir.create(recursive: true);
    return dir;
  }

  static String _sanitize(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'room' : cleaned;
  }

  static Future<void> save(
    String roomId,
    String mediaId,
    Uint8List bytes,
  ) async {
    final dir = await _dir(roomId);
    await File('${dir.path}/${_sanitize(mediaId)}').writeAsBytes(
      bytes,
      flush: true,
    );
  }

  static Future<Uint8List?> load(String roomId, String mediaId) async {
    final dir = await _dir(roomId);
    final f = File('${dir.path}/${_sanitize(mediaId)}');
    if (!f.existsSync()) return null;
    return f.readAsBytes();
  }

  /// All media ids stored for a room (used to reload the host's in-memory
  /// store after a restart so it can keep serving old files to peers).
  static Future<List<String>> idsFor(String roomId) async {
    final dir = await _dir(roomId);
    final entries = dir.listSync();
    return entries.whereType<File>().map((e) => e.uri.pathSegments.last).toList();
  }

  static Future<void> deleteRoom(String roomId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/media/${_sanitize(roomId)}');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
