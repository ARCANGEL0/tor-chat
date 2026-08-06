import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../models/app_settings.dart';
import '../state/theme_controller.dart';
import '../state/theme_style.dart';
import '../state/theme_templates.dart';
import '../widgets/app_toast.dart';
import 'wallpaper_picker_screen.dart';

/// Full appearance editor: import/export theme JSON, a color field for every
/// UI element, dark/light mode, wallpaper and reset.
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  static const _palette = <Color>[
    Color(0xFF7C3FED), // tor purple
    Color(0xFF5B2DD3), // deep violet
    Color(0xFF2E3BDB), // royal blue
    Color(0xFF1B2A8F), // deep indigo
    Color(0xFF0D47A1), // deep blue
    Color(0xFF4A148C), // royal purple
    Color(0xFF8E24AA), // magenta violet
    Color(0xFF1565C0), // vivid blue
    Color(0xFF0097A7), // teal
    Color(0xFF00897B), // green-teal
    Color(0xFFE91E63), // pink
    Color(0xFFD81B60), // raspberry
  ];

  static const _colorGroups = <(String, List<_ColorFieldSpec>)>[
    (
      'General',
      [
        _ColorFieldSpec('Buttons', 'Primary buttons, toggles and highlights',
            ColorSetting.buttons),
        _ColorFieldSpec('Header', 'Top bars in every screen',
            ColorSetting.header),
        _ColorFieldSpec('Header text', 'Text on the top bars',
            ColorSetting.headerText),
        _ColorFieldSpec('Background', 'Main page background color',
            ColorSetting.background),
        _ColorFieldSpec('Main page text', 'Text on the main pages',
            ColorSetting.mainText),
        _ColorFieldSpec('Secondary text', 'Muted text, hints and labels',
            ColorSetting.secondaryText),
        _ColorFieldSpec('Boot screen', 'Background while the app starts',
            ColorSetting.splashBackground),
        _ColorFieldSpec('Logo', 'Tint applied over the app logo',
            ColorSetting.logo),
      ],
    ),
    (
      'Chat',
      [
        _ColorFieldSpec('Chat header', 'Top bar on the chat screen',
            ColorSetting.chatHeader),
        _ColorFieldSpec('Chat header text', 'Text on the chat top bar',
            ColorSetting.chatHeaderText),
        _ColorFieldSpec('Chat background', 'Chat screen behind messages',
            ColorSetting.chatBackground),
        _ColorFieldSpec('Chat text', 'Message text color in a chat',
            ColorSetting.chatText),
        _ColorFieldSpec('My bubble', 'Your messages in a chat',
            ColorSetting.bubbleMine),
        _ColorFieldSpec('Their bubble', 'Received messages in a chat',
            ColorSetting.bubbleTheirs),
        _ColorFieldSpec('Notification bubble', 'System tips (e.g. "has connected")',
            ColorSetting.noticeColor),
        _ColorFieldSpec('Notification bubble text', 'Text on the system tips',
            ColorSetting.noticeText),
      ],
    ),
    (
      'Member list',
      [
        _ColorFieldSpec('Members text', 'Member list names',
            ColorSetting.membersText),
        _ColorFieldSpec('Members header', 'Member list title',
            ColorSetting.membersHeader),
        _ColorFieldSpec('Members background', 'Member list panel',
            ColorSetting.membersBackground),
        _ColorFieldSpec('Members icon', 'Member list icons',
            ColorSetting.membersIcon),
        _ColorFieldSpec('Online', 'Members currently in the room',
            ColorSetting.onlineText),
        _ColorFieldSpec('Offline', 'Known members not connected',
            ColorSetting.offlineText),
      ],
    ),
    (
      'Kick card',
      [
        _ColorFieldSpec('Kick background', 'The kick confirmation card',
            ColorSetting.kickBackground),
        _ColorFieldSpec('Kick border', 'Card outline',
            ColorSetting.kickBorder),
        _ColorFieldSpec('Kick title', '"Kick <name>?" heading',
            ColorSetting.kickTitle),
        _ColorFieldSpec('Kick body text', 'The explanation text',
            ColorSetting.kickBody),
        _ColorFieldSpec('Kick icon', 'The warning icon',
            ColorSetting.kickIcon),
        _ColorFieldSpec('Kick button', 'The Kick action button',
            ColorSetting.kickButton),
        _ColorFieldSpec('Kick button text', 'Label on the Kick button',
            ColorSetting.kickButtonText),
        _ColorFieldSpec('Cancel button', 'Cancel label on the card',
            ColorSetting.kickCancel),
      ],
    ),
      (
        'Text colors',
        [
          _ColorFieldSpec('Main header text', 'App bar titles',
              ColorSetting.mainHeaderText),
          _ColorFieldSpec('Main chats text', 'Room names on home screen',
              ColorSetting.mainChatsText),
          _ColorFieldSpec('Chat header text', 'Chat screen top bar text',
              ColorSetting.chatHeaderText),
          _ColorFieldSpec('Member list text', 'Member list names',
              ColorSetting.membersText),
          _ColorFieldSpec('Chat bubbles text', 'Message text in bubbles',
              ColorSetting.chatBubblesText),
          _ColorFieldSpec('Settings text', 'Settings screen text',
              ColorSetting.settingsText),
          _ColorFieldSpec('Splash text', 'Boot screen text',
              ColorSetting.splashText),
        ],
      ),
      (
        'Message area',
      [
        _ColorFieldSpec('Message area button', 'The send button color',
            ColorSetting.inputButton),
        _ColorFieldSpec('Message attachment', 'The attach (image) button color',
            ColorSetting.inputAttach),
        _ColorFieldSpec('Message area textarea', 'The text field fill color',
            ColorSetting.inputTextarea),
        _ColorFieldSpec('Message area background',
            'The footer behind the text field', ColorSetting.inputBar),
      ],
    ),
    (
      'Profile card',
      [
        _ColorFieldSpec('Profile background', 'The profile card background',
            ColorSetting.profileBackground),
        _ColorFieldSpec('Profile text', 'Username on the profile card',
            ColorSetting.profileText),
        _ColorFieldSpec('Profile muted text', 'Bio and joined time',
            ColorSetting.profileSecondaryText),
        _ColorFieldSpec('Profile accent', 'Avatar ring and profile icons',
            ColorSetting.profileAccent),
      ],
    ),
    (
      'Toasts',
      [
        _ColorFieldSpec('Toast background', 'Pop-up notices (top-left)',
            ColorSetting.toastBackground),
        _ColorFieldSpec('Toast text', 'Text on the pop-up notices',
            ColorSetting.toastText),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: ListenableBuilder(
        listenable: tc,
        builder: (context, _) {
          final s = tc.settings;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importTheme(context),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Import'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportTheme(context),
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Export'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Templates'),
              const SizedBox(height: 4),
              Text(
                'Ready-made looks that recolor AND reshape the whole app '
                '(bubbles, input bar, buttons and cards).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 18,
                children: [
                  for (final t in themeTemplates)
                    _TemplateCard(
                      template: t,
                      selected: ThemeStyle.fromId(s.themeStyle) == t.style,
                      onTap: () => tc.applyTemplate(t),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Colors'),
              const SizedBox(height: 4),
              Text(
                'Tap a field to pick its color. "Use default" restores the '
                'built-in look for that element.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              for (final group in _colorGroups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text(
                    group.$1,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                for (final f in group.$2)
                  _ColorField(
                    label: f.label,
                    description: f.description,
                    color: _currentColor(s, f.setting),
                    onTap: () => _editColor(context, f.setting),
                  ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmReset(context, tc),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset to defaults'),
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Appearance'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: AppSettings.modeSystem,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: AppSettings.modeLight,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: AppSettings.modeDark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (sel) => tc.setThemeMode(sel.first),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Backgrounds'),
              const SizedBox(height: 4),
              Text(
                'Each area can be a plain color or an image (built-in '
                'wallpaper or your own photo).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              _BackgroundRow(
                label: 'Main page background',
                current: s.mainWallpaper,
                pickerTitle: 'Main page background',
                defaultColor: s.background ?? s.accentColor,
                onChanged: tc.setMainWallpaper,
              ),
              _BackgroundRow(
                label: 'Chat background',
                current: s.globalWallpaper,
                pickerTitle: 'Chat wallpaper',
                defaultColor: s.chatBackground ?? s.accentColor,
                onChanged: tc.setGlobalWallpaper,
              ),
              _BackgroundRow(
                label: 'Member list background',
                current: s.membersWallpaper,
                pickerTitle: 'Member list background',
                defaultColor: s.membersBackground ?? s.accentColor,
                onChanged: tc.setMembersWallpaper,
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Fonts'),
              const SizedBox(height: 4),
              Text(
                'Pick a device font and size for the main pages and for chat '
                'messages.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Main font',
                subtitle: 'Every screen',
                current: s.mainFont,
                onChanged: tc.setMainFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Main text size',
                value: s.mainFontSize,
                min: 12,
                max: 18,
                onChanged: tc.setMainFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Chat font',
                subtitle: 'Messages and the input field',
                current: s.chatFont,
                onChanged: tc.setChatFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Chat text size',
                value: s.chatFontSize,
                min: 12,
                max: 20,
                onChanged: tc.setChatFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Main header font',
                subtitle: 'App bar titles',
                current: s.mainHeaderFont,
                onChanged: tc.setMainHeaderFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Main header text size',
                value: s.mainHeaderFontSize,
                min: 12,
                max: 24,
                onChanged: tc.setMainHeaderFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Main chats font',
                subtitle: 'Room names on home screen',
                current: s.mainChatsFont,
                onChanged: tc.setMainChatsFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Main chats text size',
                value: s.mainChatsFontSize,
                min: 10,
                max: 20,
                onChanged: tc.setMainChatsFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Chat header font',
                subtitle: 'Chat screen top bar',
                current: s.chatHeaderFont,
                onChanged: tc.setChatHeaderFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Chat header text size',
                value: s.chatHeaderFontSize,
                min: 12,
                max: 20,
                onChanged: tc.setChatHeaderFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Chat bubbles font',
                subtitle: 'Message text inside bubbles',
                current: s.chatBubblesFont,
                onChanged: tc.setChatBubblesFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Chat bubbles text size',
                value: s.chatBubblesFontSize,
                min: 12,
                max: 20,
                onChanged: tc.setChatBubblesFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Member list font',
                subtitle: 'Names in the member sidebar',
                current: s.memberListFont,
                onChanged: tc.setMemberListFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Member list text size',
                value: s.memberListFontSize,
                min: 10,
                max: 18,
                onChanged: tc.setMemberListFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Settings font',
                subtitle: 'Settings screen text',
                current: s.settingsFont,
                onChanged: tc.setSettingsFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Settings text size',
                value: s.settingsFontSize,
                min: 10,
                max: 18,
                onChanged: tc.setSettingsFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Splash font',
                subtitle: 'Boot screen text',
                current: s.splashFont,
                onChanged: tc.setSplashFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Splash text size',
                value: s.splashFontSize,
                min: 14,
                max: 28,
                onChanged: tc.setSplashFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Profile font',
                subtitle: 'Profile card text',
                current: s.profileFont,
                onChanged: tc.setProfileFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Profile text size',
                value: s.profileFontSize,
                min: 12,
                max: 24,
                onChanged: tc.setProfileFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Notification font',
                subtitle: 'System tips in the chat',
                current: s.noticeFont,
                onChanged: tc.setNoticeFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Notification text size',
                value: s.noticeFontSize,
                min: 10,
                max: 16,
                onChanged: tc.setNoticeFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Toast font',
                subtitle: 'Pop-up notices',
                current: s.toastFont,
                onChanged: tc.setToastFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Toast text size',
                value: s.toastFontSize,
                min: 11,
                max: 18,
                onChanged: tc.setToastFontSize,
              ),
              const SizedBox(height: 12),
              _FontRow(
                label: 'Kick card font',
                subtitle: 'Kick confirmation card',
                current: s.kickFont,
                onChanged: tc.setKickFont,
              ),
              const SizedBox(height: 4),
              _SizeRow(
                label: 'Kick card text size',
                value: s.kickFontSize,
                min: 12,
                max: 20,
                onChanged: tc.setKickFontSize,
              ),
            ],
          );
        },
      ),
    );
  }

  int? _currentColor(AppSettings s, ColorSetting setting) {
    switch (setting) {
      case ColorSetting.buttons:
        return s.accentColor;
      case ColorSetting.header:
        return s.headerColor;
      case ColorSetting.background:
        return s.background;
      case ColorSetting.chatBackground:
        return s.chatBackground;
      case ColorSetting.bubbleMine:
        return s.bubbleMine;
      case ColorSetting.bubbleTheirs:
        return s.bubbleTheirs;
      case ColorSetting.splashBackground:
        return s.splashBackground;
      case ColorSetting.logo:
        return s.logoColor ?? AppSettings.defaultLogoColor;
      case ColorSetting.mainText:
        return s.mainText;
      case ColorSetting.secondaryText:
        return s.secondaryText;
      case ColorSetting.chatHeader:
        return s.chatHeader;
      case ColorSetting.headerText:
        return s.headerText;
      case ColorSetting.chatHeaderText:
        return s.chatHeaderText;
      case ColorSetting.inputBar:
        return s.inputBar;
      case ColorSetting.inputTextarea:
        return s.inputTextarea;
      case ColorSetting.inputButton:
        return s.inputButton;
      case ColorSetting.inputAttach:
        return s.inputAttach;
      case ColorSetting.chatText:
        return s.chatTextColor;
      case ColorSetting.membersText:
        return s.membersText;
      case ColorSetting.membersHeader:
        return s.membersHeader;
      case ColorSetting.membersBackground:
        return s.membersBackground;
      case ColorSetting.membersIcon:
        return s.membersIcon;
      case ColorSetting.mainHeaderText:
        return s.mainHeaderTextColor;
      case ColorSetting.mainChatsText:
        return s.mainChatsTextColor;
      case ColorSetting.chatBubblesText:
        return s.chatBubblesTextColor;
      case ColorSetting.settingsText:
        return s.settingsTextColor;
      case ColorSetting.splashText:
        return s.splashTextColor;
      case ColorSetting.profileBackground:
        return s.profileBackground;
      case ColorSetting.profileText:
        return s.profileText;
      case ColorSetting.profileSecondaryText:
        return s.profileSecondaryText;
      case ColorSetting.profileAccent:
        return s.profileAccent;
      case ColorSetting.onlineText:
        return s.onlineText;
      case ColorSetting.offlineText:
        return s.offlineText;
      case ColorSetting.noticeColor:
        return s.noticeColor;
      case ColorSetting.noticeText:
        return s.noticeText;
      case ColorSetting.toastBackground:
        return s.toastBackground;
      case ColorSetting.toastText:
        return s.toastText;
      case ColorSetting.kickBackground:
        return s.kickBackground;
      case ColorSetting.kickBorder:
        return s.kickBorder;
      case ColorSetting.kickTitle:
        return s.kickTitle;
      case ColorSetting.kickBody:
        return s.kickBody;
      case ColorSetting.kickIcon:
        return s.kickIcon;
      case ColorSetting.kickButton:
        return s.kickButton;
      case ColorSetting.kickButtonText:
        return s.kickButtonText;
      case ColorSetting.kickCancel:
        return s.kickCancel;
    }
  }

  Future<void> _editColor(BuildContext context, ColorSetting setting) async {
    final tc = ThemeController.instance;
    final current = _currentColor(tc.settings, setting);
    final picked = await showDialog<Object?>(
      context: context,
      builder: (_) => _ColorDialog(
        title: _colorGroups
            .expand((g) => g.$2)
            .firstWhere((f) => f.setting == setting)
            .label,
        initial: current != null ? Color(current) : null,
        palette: _palette,
      ),
    );
    if (picked == _canceled) return;
    await tc.setColor(setting, picked as Color?);
  }

  Future<void> _exportTheme(BuildContext context) async {
    final tc = ThemeController.instance;
    final json = tc.exportThemeJson();
    try {
      // Android system picker (SAF): asks where to save the .json file.
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save theme as…',
        fileName: 'onionchat-theme.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(json),
      );
      if (path == null) return; // canceled
      if (!context.mounted) return;
      AppToast.show(context, 'Theme exported to $path');
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Export failed: $e', style: AppToastStyle.error);
    }
  }

  Future<void> _importTheme(BuildContext context) async {
    final tc = ThemeController.instance;
    // Opens the system file chooser directly — pick a .json theme file.
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import theme…',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return; // canceled
    String json;
    try {
      json = await File(path).readAsString();
    } catch (_) {
      if (!context.mounted) return;
      AppToast.show(context, 'Could not read that file',
          style: AppToastStyle.error);
      return;
    }
    if (json.trim().isEmpty) return;
    final error = await tc.importThemeJson(json.trim());
    if (!context.mounted) return;
    AppToast.show(
      context,
      error ?? 'Theme imported ✓',
      style: error == null ? AppToastStyle.info : AppToastStyle.error,
    );
  }

  Future<void> _confirmReset(BuildContext context, ThemeController tc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset appearance?'),
        content: const Text(
            'This restores every default color, wallpaper and profile picture.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await tc.resetAppearance();
  }
}

const _canceled = Object();

/// A circular preview thumbnail for one theme template. Tapping applies the
/// template's colors and shape style.
class _TemplateCard extends StatelessWidget {
  final ThemeTemplate template;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: Image.asset(
                template.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: scheme.primary.withValues(alpha: 0.25),
                  child: Icon(
                    Icons.palette_outlined,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 88,
            child: Text(
              template.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorFieldSpec {
  final String label;
  final String description;
  final ColorSetting setting;

  const _ColorFieldSpec(this.label, this.description, this.setting);
}

class _ColorDialog extends StatefulWidget {
  final String title;
  final Color? initial;
  final List<Color> palette;

  const _ColorDialog({
    required this.title,
    required this.initial,
    required this.palette,
  });

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _color = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in widget.palette)
                  _Swatch(
                    color: c,
                    selected: _color?.toARGB32() == c.toARGB32(),
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ColorPicker(
              pickerColor: _color ?? Theme.of(context).colorScheme.primary,
              onColorChanged: (c) => setState(() => _color = c),
              enableAlpha: false,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: _color, size: 26),
                const SizedBox(width: 8),
                Text(
                  _color != null
                      ? '#${(_color!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
                      : 'Theme default',
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _canceled),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Use default'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color ?? _canceled),
          child: const Text('Use'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  final String label;
  final String description;
  final int? color;
  final VoidCallback onTap;

  const _ColorField({
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color != null ? Color(color!) : Colors.transparent,
          border: Border.all(color: scheme.outlineVariant, width: 2),
        ),
        child: color == null
            ? Icon(Icons.auto_awesome, size: 16, color: scheme.onSurfaceVariant)
            : null,
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// A "color or image" row for one background (main page, chat, member list).
/// Opens [WallpaperPickerScreen]; picking the Default tile clears the image so
/// the area falls back to its color field.
class _BackgroundRow extends StatelessWidget {
  final String label;
  final String? current;
  final String pickerTitle;
  final int? defaultColor;
  final ValueChanged<String?> onChanged;

  const _BackgroundRow({
    required this.label,
    required this.current,
    required this.pickerTitle,
    this.defaultColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String subtitle;
    if (current == null) {
      subtitle = 'Default color';
    } else if (current!.startsWith('asset:')) {
      subtitle = 'Built-in wallpaper';
    } else {
      subtitle = 'Custom image';
    }
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      child: ListTile(
        leading: const Icon(Icons.wallpaper),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => WallpaperPickerScreen(
                current: current,
                title: pickerTitle,
                defaultColor: defaultColor,
              ),
            ),
          );
          if (result == null) return; // canceled
          onChanged(result == WallpaperPickerScreen.kDefault ? null : result);
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

const _fontOptions = <(String, String)>[
  ('Default (Roboto)', ''),
  ('sans-serif', 'sans-serif'),
  ('serif', 'serif'),
  ('monospace', 'monospace'),
  ('sans-serif-condensed', 'sans-serif-condensed'),
  ('sans-serif-medium', 'sans-serif-medium'),
];

class _FontRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String current;
  final ValueChanged<String> onChanged;

  const _FontRow({
    required this.label,
    required this.subtitle,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.font_download_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: current,
              underline: const SizedBox.shrink(),
              items: [
                for (final f in _fontOptions)
                  DropdownMenuItem(value: f.$2, child: Text(f.$1)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SizeRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: ((max - min) * 2).round(),
              label: value.toStringAsFixed(1),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
