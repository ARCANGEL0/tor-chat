import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Owns the app-wide appearance: per-element colors, dark/light mode, chat
/// wallpaper, profile picture and Tor ports. Persists everything in
/// shared_preferences, notifies listeners so the root MaterialApp rebuilds.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _settingsKey = 'app_settings';

  AppSettings settings = AppSettings.defaults();

  ThemeMode get themeMode {
    switch (settings.themeMode) {
      case AppSettings.modeLight:
        return ThemeMode.light;
      case AppSettings.modeSystem:
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  /// The primary/button color (accent).
  Color get accentColor => Color(settings.accentColor);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        settings = AppSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    settings = settings.copy()..accentColor = color.toARGB32();
    await _save();
  }

  Future<void> setThemeMode(String mode) async {
    settings = settings.copy()..themeMode = mode;
    await _save();
  }

  Future<void> setGlobalWallpaper(String? wallpaper) async {
    settings = settings.copy()..globalWallpaper = wallpaper;
    await _save();
  }

  Future<void> setAvatar(String? avatar) async {
    settings = settings.copy()..avatar = avatar;
    await _save();
  }

  Future<void> setBio(String? bio) async {
    settings = settings.copy()..bio = (bio == null || bio.trim().isEmpty) ? null : bio.trim();
    await _save();
  }

  Future<void> setNotificationPref({
    required bool Function(AppSettings) field,
    required bool value,
  }) async {
    final s = settings.copy();
    field(s);
    settings = s;
    await _save();
  }

  Future<void> setNotif(bool value) async =>
      setNotificationPref(field: (s) => s.notificationsEnabled = value, value: value);
  Future<void> setNotifSound(bool value) async =>
      setNotificationPref(field: (s) => s.notifSound = value, value: value);
  Future<void> setNotifVibrate(bool value) async =>
      setNotificationPref(field: (s) => s.notifVibrate = value, value: value);
  Future<void> setSoundClick(bool value) async =>
      setNotificationPref(field: (s) => s.soundClick = value, value: value);
  Future<void> setSoundSend(bool value) async =>
      setNotificationPref(field: (s) => s.soundSend = value, value: value);
  Future<void> setSoundReceive(bool value) async =>
      setNotificationPref(field: (s) => s.soundReceive = value, value: value);

  Future<void> setBridges({bool? useBridges, String? bridges}) async {
    final s = settings.copy();
    if (useBridges != null) s.useBridges = useBridges;
    if (bridges != null) s.bridges = bridges;
    settings = s;
    await _save();
  }

  Future<void> setColor(ColorSetting which, Color? color) async {
    final s = settings.copy();
    switch (which) {
      case ColorSetting.header:
        s.headerColor = color?.toARGB32();
      case ColorSetting.background:
        s.background = color?.toARGB32();
      case ColorSetting.chatBackground:
        s.chatBackground = color?.toARGB32();
      case ColorSetting.buttons:
        s.accentColor = color?.toARGB32() ?? AppSettings.defaultAccent;
      case ColorSetting.bubbleMine:
        s.bubbleMine = color?.toARGB32();
      case ColorSetting.bubbleTheirs:
        s.bubbleTheirs = color?.toARGB32();
      case ColorSetting.splashBackground:
        s.splashBackground = color?.toARGB32();
      case ColorSetting.logo:
        s.logoColor = color?.toARGB32();
      case ColorSetting.mainText:
        s.mainText = color?.toARGB32();
      case ColorSetting.secondaryText:
        s.secondaryText = color?.toARGB32();
      case ColorSetting.chatHeader:
        s.chatHeader = color?.toARGB32();
      case ColorSetting.headerText:
        s.headerText = color?.toARGB32();
      case ColorSetting.chatHeaderText:
        s.chatHeaderText = color?.toARGB32();
      case ColorSetting.inputBar:
        s.inputBar = color?.toARGB32();
      case ColorSetting.inputTextarea:
        s.inputTextarea = color?.toARGB32();
      case ColorSetting.inputButton:
        s.inputButton = color?.toARGB32();
      case ColorSetting.inputAttach:
        s.inputAttach = color?.toARGB32();
      case ColorSetting.membersText:
        s.membersText = color?.toARGB32();
      case ColorSetting.membersHeader:
        s.membersHeader = color?.toARGB32();
      case ColorSetting.membersBackground:
        s.membersBackground = color?.toARGB32();
      case ColorSetting.membersIcon:
        s.membersIcon = color?.toARGB32();
      case ColorSetting.chatText:
        s.chatTextColor = color?.toARGB32();
    }
    settings = s;
    await _save();
  }

  Future<void> setMembersWallpaper(String? wallpaper) async {
    settings = settings.copy()..membersWallpaper = wallpaper;
    await _save();
  }

  Future<void> setMainWallpaper(String? wallpaper) async {
    settings = settings.copy()..mainWallpaper = wallpaper;
    await _save();
  }

  Future<void> setMainFont(String font) async {
    settings = settings.copy()..mainFont = font;
    await _save();
  }

  Future<void> setMainFontSize(double size) async {
    settings = settings.copy()..mainFontSize = size;
    await _save();
  }

  Future<void> setChatFont(String font) async {
    settings = settings.copy()..chatFont = font;
    await _save();
  }

  Future<void> setChatFontSize(double size) async {
    settings = settings.copy()..chatFontSize = size;
    await _save();
  }

  Future<void> setTorPorts({int? socks, int? control}) async {
    final s = settings.copy();
    if (socks != null) s.socksPort = socks;
    if (control != null) s.controlPort = control;
    settings = s;
    await _save();
  }

  /// Serializes the current appearance (colors, mode, wallpaper, avatar) to a
  /// JSON string for export.
  String exportThemeJson() =>
      JsonEncoder.withIndent('  ').convert(settings.appearanceJson());

  /// Applies an exported theme JSON. Returns an error message, or `null` on
  /// success.
  Future<String?> importThemeJson(String json) async {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return 'Not a valid theme file.';
      final s = settings.copy();
      if (map['accent'] is int) s.accentColor = map['accent'] as int;
      if (map['themeMode'] is String) s.themeMode = map['themeMode'] as String;
      s.globalWallpaper = map['wallpaper'] as String?;
      s.avatar = map['avatar'] as String?;
      s.headerColor = _intOrNull(map['header']);
      s.background = _intOrNull(map['background']);
      s.chatBackground = _intOrNull(map['chatBackground']);
      s.bubbleMine = _intOrNull(map['bubbleMine']);
      s.bubbleTheirs = _intOrNull(map['bubbleTheirs']);
      s.splashBackground = _intOrNull(map['splashBackground']);
      s.logoColor = _intOrNull(map['logo']);
      s.mainText = _intOrNull(map['text']);
      s.secondaryText = _intOrNull(map['secondaryText']);
      s.headerText = _intOrNull(map['headerText']);
      s.chatHeaderText = _intOrNull(map['chatHeaderText']);
      s.mainWallpaper = map['mainWallpaper'] as String?;
      s.inputBar = _intOrNull(map['inputBar']);
      s.inputTextarea = _intOrNull(map['inputTextarea']);
      s.inputButton = _intOrNull(map['inputButton']);
      s.inputAttach = _intOrNull(map['inputAttach']);
      s.chatHeader = _intOrNull(map['chatHeader']);
      s.membersText = _intOrNull(map['membersText']);
      s.membersHeader = _intOrNull(map['membersHeader']);
      s.membersBackground = _intOrNull(map['membersBackground']);
      s.membersIcon = _intOrNull(map['membersIcon']);
      s.chatTextColor = _intOrNull(map['chatText']);
      settings = s;
      await _save();
      return null;
    } catch (_) {
      return 'Could not read that theme.';
    }
  }

  int? _intOrNull(dynamic v) => v is int ? v : null;

  /// Reverts every appearance override to the theme defaults (colors, mode,
  /// wallpaper and avatar). Tor ports are kept.
  Future<void> resetAppearance() async {
    settings = AppSettings(
      accentColor: AppSettings.defaultAccent,
      themeMode: settings.themeMode,
      socksPort: settings.socksPort,
      controlPort: settings.controlPort,
      logoColor: AppSettings.defaultLogoColor,
    );
    await _save();
  }

  /// Resets everything (appearance, ports, notifications, bridges) to factory
  /// defaults. Used by "Erase all data".
  Future<void> resetAll() async {
    settings = AppSettings.defaults();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    notifyListeners();
  }
}

/// Which element's color is being edited.
enum ColorSetting {
  header,
  background,
  chatBackground,
  buttons,
  bubbleMine,
  bubbleTheirs,
  splashBackground,
  logo,
  mainText,
  secondaryText,
  chatHeader,
  headerText,
  chatHeaderText,
  inputBar,
  inputTextarea,
  inputButton,
  inputAttach,
  membersText,
  membersHeader,
  membersBackground,
  membersIcon,
  chatText,
}

/// Returns a readable foreground color for use on top of [background].
Color onColor(Color background) {
  return background.computeLuminance() > 0.5
      ? const Color(0xFF17121F)
      : Colors.white;
}
