import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      case ColorSetting.mainHeaderText:
        s.mainHeaderTextColor = color?.toARGB32();
      case ColorSetting.mainChatsText:
        s.mainChatsTextColor = color?.toARGB32();
      case ColorSetting.chatBubblesText:
        s.chatBubblesTextColor = color?.toARGB32();
      case ColorSetting.settingsText:
        s.settingsTextColor = color?.toARGB32();
  case ColorSetting.splashText:
    s.splashTextColor = color?.toARGB32();
  case ColorSetting.profileBackground:
    s.profileBackground = color?.toARGB32();
  case ColorSetting.profileText:
    s.profileText = color?.toARGB32();
  case ColorSetting.profileSecondaryText:
    s.profileSecondaryText = color?.toARGB32();
  case ColorSetting.profileAccent:
    s.profileAccent = color?.toARGB32();
  case ColorSetting.onlineText:
    s.onlineText = color?.toARGB32();
  case ColorSetting.offlineText:
    s.offlineText = color?.toARGB32();
  case ColorSetting.noticeColor:
    s.noticeColor = color?.toARGB32();
  case ColorSetting.noticeText:
    s.noticeText = color?.toARGB32();
  case ColorSetting.toastBackground:
    s.toastBackground = color?.toARGB32();
  case ColorSetting.toastText:
    s.toastText = color?.toARGB32();
  case ColorSetting.kickBackground:
    s.kickBackground = color?.toARGB32();
  case ColorSetting.kickBorder:
    s.kickBorder = color?.toARGB32();
  case ColorSetting.kickTitle:
    s.kickTitle = color?.toARGB32();
  case ColorSetting.kickBody:
    s.kickBody = color?.toARGB32();
  case ColorSetting.kickIcon:
    s.kickIcon = color?.toARGB32();
  case ColorSetting.kickButton:
    s.kickButton = color?.toARGB32();
  case ColorSetting.kickButtonText:
    s.kickButtonText = color?.toARGB32();
  case ColorSetting.kickCancel:
    s.kickCancel = color?.toARGB32();
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

  Future<void> setMainHeaderFont(String font) async {
    settings = settings.copy()..mainHeaderFont = font;
    await _save();
  }

  Future<void> setMainChatsFont(String font) async {
    settings = settings.copy()..mainChatsFont = font;
    await _save();
  }

  Future<void> setChatHeaderFont(String font) async {
    settings = settings.copy()..chatHeaderFont = font;
    await _save();
  }

  Future<void> setChatBubblesFont(String font) async {
    settings = settings.copy()..chatBubblesFont = font;
    await _save();
  }

  Future<void> setMemberListFont(String font) async {
    settings = settings.copy()..memberListFont = font;
    await _save();
  }

  Future<void> setSettingsFont(String font) async {
    settings = settings.copy()..settingsFont = font;
    await _save();
  }

  Future<void> setSplashFont(String font) async {
    settings = settings.copy()..splashFont = font;
    await _save();
  }

  Future<void> setMainHeaderFontSize(double size) async {
    settings = settings.copy()..mainHeaderFontSize = size;
    await _save();
  }

  Future<void> setMainChatsFontSize(double size) async {
    settings = settings.copy()..mainChatsFontSize = size;
    await _save();
  }

  Future<void> setChatHeaderFontSize(double size) async {
    settings = settings.copy()..chatHeaderFontSize = size;
    await _save();
  }

  Future<void> setChatBubblesFontSize(double size) async {
    settings = settings.copy()..chatBubblesFontSize = size;
    await _save();
  }

  Future<void> setMemberListFontSize(double size) async {
    settings = settings.copy()..memberListFontSize = size;
    await _save();
  }

  Future<void> setSettingsFontSize(double size) async {
    settings = settings.copy()..settingsFontSize = size;
    await _save();
  }

  Future<void> setSplashFontSize(double size) async {
    settings = settings.copy()..splashFontSize = size;
    await _save();
  }

  Future<void> setProfileFont(String font) async {
    settings = settings.copy()..profileFont = font;
    await _save();
  }

  Future<void> setProfileFontSize(double size) async {
    settings = settings.copy()..profileFontSize = size;
    await _save();
  }

  Future<void> setNoticeFont(String font) async {
    settings = settings.copy()..noticeFont = font;
    await _save();
  }

  Future<void> setNoticeFontSize(double size) async {
    settings = settings.copy()..noticeFontSize = size;
    await _save();
  }

  Future<void> setToastFont(String font) async {
    settings = settings.copy()..toastFont = font;
    await _save();
  }

  Future<void> setToastFontSize(double size) async {
    settings = settings.copy()..toastFontSize = size;
    await _save();
  }

  Future<void> setKickFont(String font) async {
    settings = settings.copy()..kickFont = font;
    await _save();
  }

  Future<void> setKickFontSize(double size) async {
    settings = settings.copy()..kickFontSize = size;
    await _save();
  }

  Future<void> setMainHeaderTextColor(Color? color) async {
    settings = settings.copy()..mainHeaderTextColor = color?.toARGB32();
    await _save();
  }

  Future<void> setMainChatsTextColor(Color? color) async {
    settings = settings.copy()..mainChatsTextColor = color?.toARGB32();
    await _save();
  }

  Future<void> setChatHeaderTextColor(Color? color) async {
    settings = settings.copy()..chatHeaderTextColor = color?.toARGB32();
    await _save();
  }

  Future<void> setMemberListTextColor(Color? color) async {
    settings = settings.copy()..memberListTextColor = color?.toARGB32();
    await _save();
  }

  Future<void> setChatBubblesTextColor(Color? color) async {
    settings = settings.copy()..chatBubblesTextColor = color?.toARGB32();
    await _save();
  }

  Future<void> setSettingsTextColor(Color? color) async {
    settings = settings.copy()..settingsTextColor = color?.toARGB32();
    await _save();
  }

  Future<void> setSplashTextColor(Color? color) async {
    settings = settings.copy()..splashTextColor = color?.toARGB32();
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
      s.mainHeaderTextColor = _intOrNull(map['mainHeaderTextColor']);
      s.mainChatsTextColor = _intOrNull(map['mainChatsTextColor']);
      s.chatHeaderTextColor = _intOrNull(map['chatHeaderTextColor']);
      s.memberListTextColor = _intOrNull(map['memberListTextColor']);
      s.chatBubblesTextColor = _intOrNull(map['chatBubblesTextColor']);
      s.settingsTextColor = _intOrNull(map['settingsTextColor']);
      s.splashTextColor = _intOrNull(map['splashTextColor']);
      s.profileBackground = _intOrNull(map['profileBackground']);
      s.profileText = _intOrNull(map['profileText']);
      s.profileSecondaryText = _intOrNull(map['profileSecondaryText']);
      s.profileAccent = _intOrNull(map['profileAccent']);
      s.profileFont = map['profileFont'] as String? ?? '';
      s.profileFontSize = map['profileFontSize'] is num
          ? (map['profileFontSize'] as num).toDouble()
          : 15.0;
      s.onlineText = _intOrNull(map['onlineText']);
      s.offlineText = _intOrNull(map['offlineText']);
      s.noticeColor = _intOrNull(map['noticeColor']);
      s.noticeText = _intOrNull(map['noticeText']);
      s.noticeFont = map['noticeFont'] as String? ?? '';
      s.noticeFontSize = map['noticeFontSize'] is num
          ? (map['noticeFontSize'] as num).toDouble()
          : 12.0;
      s.toastBackground = _intOrNull(map['toastBackground']);
      s.toastText = _intOrNull(map['toastText']);
      s.toastFont = map['toastFont'] as String? ?? '';
      s.toastFontSize = map['toastFontSize'] is num
          ? (map['toastFontSize'] as num).toDouble()
          : 13.0;
      s.kickBackground = _intOrNull(map['kickBackground']);
      s.kickBorder = _intOrNull(map['kickBorder']);
      s.kickTitle = _intOrNull(map['kickTitle']);
      s.kickBody = _intOrNull(map['kickBody']);
      s.kickIcon = _intOrNull(map['kickIcon']);
      s.kickButton = _intOrNull(map['kickButton']);
      s.kickButtonText = _intOrNull(map['kickButtonText']);
      s.kickCancel = _intOrNull(map['kickCancel']);
      s.kickFont = map['kickFont'] as String? ?? '';
      s.kickFontSize = map['kickFontSize'] is num
          ? (map['kickFontSize'] as num).toDouble()
          : 15.0;
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
  mainHeaderText,
  mainChatsText,
  chatBubblesText,
  settingsText,
  splashText,
  profileBackground,
  profileText,
  profileSecondaryText,
  profileAccent,
  onlineText,
  offlineText,
  noticeColor,
  noticeText,
  toastBackground,
  toastText,
  kickBackground,
  kickBorder,
  kickTitle,
  kickBody,
  kickIcon,
  kickButton,
  kickButtonText,
  kickCancel,
}

/// Returns a readable foreground color for use on top of [background].
Color onColor(Color background) {
  return background.computeLuminance() > 0.5
      ? const Color(0xFF17121F)
      : Colors.white;
}