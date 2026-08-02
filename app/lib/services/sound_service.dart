import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../state/theme_controller.dart';

/// Plays short bundled sound effects (UI clicks, message send/receive).
/// Each call is gated by the corresponding setting in [ThemeController].
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  DateTime _lastClick = DateTime.fromMillisecondsSinceEpoch(0);

  /// Soft blip for generic taps. Throttled so scrolling doesn't rattle.
  Future<void> click() async {
    if (!ThemeController.instance.settings.soundClick) return;
    final now = DateTime.now();
    if (now.difference(_lastClick).inMilliseconds < 80) return;
    _lastClick = now;
    await _play('sounds/click.wav', 0.35);
  }

  /// Sent a message.
  Future<void> send() async {
    if (!ThemeController.instance.settings.soundSend) return;
    await _play('sounds/send.wav', 0.5);
  }

  /// Received a message.
  Future<void> receive() async {
    if (!ThemeController.instance.settings.soundReceive) return;
    await _play('sounds/receive.wav', 0.55);
  }

  /// The notification chime (played for the system notification too).
  Future<void> notify() async {
    await _play('sounds/notify.wav', 0.6);
  }

  Future<void> _play(String asset, double volume) async {
    try {
      await _player.stop();
      await _player.setVolume(volume);
      // AssetSource is relative to the asset bundle root ("assets/"), so the
      // path here must NOT include the "assets/" prefix.
      await _player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('sound: $e');
    }
  }

  Future<void> dispose() => _player.dispose();
}
