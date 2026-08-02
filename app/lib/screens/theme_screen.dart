import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../models/app_settings.dart';
import '../state/theme_controller.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Theme exported to $path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that file')),
      );
      return;
    }
    if (json.trim().isEmpty) return;
    final error = await tc.importThemeJson(json.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Theme imported ✓')),
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
