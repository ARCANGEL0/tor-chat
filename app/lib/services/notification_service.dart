import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../state/theme_controller.dart';

/// Local notifications for incoming chat messages. Notifications appear even
/// while the app is in the foreground; the chat screen suppresses them for the
/// room that is currently on screen.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _soundChannel = 'messages';
  static const _silentChannel = 'messages_silent';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Map<String, int> _counters = {};
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('ic_stat_onionchat');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (_) {},
    );
    _inited = true;
  }

  /// Asks for the notification permission (Android 13+ POST_NOTIFICATIONS).
  Future<bool> ensurePermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> showMessage({
    required String roomId,
    required String roomName,
    required String username,
    required String text,
  }) async {
    final s = ThemeController.instance.settings;
    if (!s.notificationsEnabled) return;

    // Notifications can't be passed down the widget tree; provide the icon
    // resource name so it shows the OnionChat logo.
    final channel = s.notifSound ? _soundChannel : _silentChannel;
    final android = AndroidNotificationDetails(
      channel,
      s.notifSound ? 'Chat messages' : 'Chat messages (silent)',
      channelDescription: 'New messages from your OnionChat rooms',
      channelShowBadge: true,
      importance: s.notifSound ? Importance.high : Importance.defaultImportance,
      priority: Priority.high,
      playSound: s.notifSound,
      sound: s.notifSound
          ? const RawResourceAndroidNotificationSound('notification')
          : null,
      enableVibration: s.notifVibrate,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.private,
      icon: 'ic_stat_onionchat',
    );

    await _plugin.show(
      _nextId(roomId),
      'OnionChat',
      '$roomName\n$username: $text',
      NotificationDetails(android: android),
    );
  }

  int _nextId(String roomId) {
    final c = (_counters[roomId] ?? 0) + 1;
    _counters[roomId] = c;
    return c;
  }
}
