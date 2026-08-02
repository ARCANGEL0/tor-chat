import 'dart:io';

import 'package:flutter/material.dart';

import '../services/app_assets.dart';
import '../services/image_pick.dart';
import '../state/theme_controller.dart';

/// Full-screen wallpaper picker. Returns the chosen wallpaper value via
/// `Navigator.pop`:
///  - `[kDefault]` = use the default (global) wallpaper,
///  - `asset:<name>` = bundled,
///  - otherwise an absolute file path to a cropped custom image,
///  - `null` = canceled (back without picking).
class WallpaperPickerScreen extends StatelessWidget {
  /// Sentinel returned when the user picks the "Default" tile (distinct from
  /// `null`, which means the picker was canceled).
  static const String kDefault = '\u0000default';

  final String? current;

  /// App bar title, e.g. "Chat wallpaper" or "Main page background".
  final String title;

  /// Color shown on the "Default" tile. `null` = the chat background (or
  /// accent) color.
  final int? defaultColor;

  const WallpaperPickerScreen({
    super.key,
    this.current,
    this.title = 'Chat wallpaper',
    this.defaultColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Built-in',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
            children: [
              _DefaultTile(
                selected: current == null,
                defaultColor: defaultColor,
                onTap: () => Navigator.of(context).pop(kDefault),
              ),
              for (final name in AppAssets.wallpapers)
                _WallpaperTile(
                  name: name,
                  selected: current == 'asset:$name',
                  onTap: () => Navigator.of(context).pop('asset:$name'),
                ),
              if (current != null && !AppAssets.isAsset(current!))
                _CustomWallpaperTile(
                  path: current!,
                  selected: true,
                  onTap: () => Navigator.of(context).pop(current),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _GalleryTile(current: current),
        ],
      ),
    );
  }
}

class _DefaultTile extends StatelessWidget {
  final bool selected;
  final int? defaultColor;
  final VoidCallback onTap;

  const _DefaultTile({
    required this.selected,
    this.defaultColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    final color = defaultColor != null
        ? Color(defaultColor!)
        : tc.settings.chatBackground != null
            ? Color(tc.settings.chatBackground!)
            : Color(tc.settings.accentColor);
    return _TileFrame(
      selected: selected,
      onTap: onTap,
      child: ColoredBox(
        color: color,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wallpaper_outlined, color: Colors.white70),
              SizedBox(height: 6),
              Text(
                'Default',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _WallpaperTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      selected: selected,
      onTap: onTap,
      child: Image.asset(
        'assets/wallpapers/$name.jpg',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
      ),
    );
  }
}

class _CustomWallpaperTile extends StatelessWidget {
  final String path;
  final bool selected;
  final VoidCallback onTap;

  const _CustomWallpaperTile({
    required this.path,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      selected: selected,
      onTap: onTap,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final String? current;

  const _GalleryTile({required this.current});

  @override
  Widget build(BuildContext context) {
    final isCustom = current != null &&
        !current!.startsWith('asset:');
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () async {
              final path = await pickAndCropImage(context, circle: false);
              if (path != null && context.mounted) {
                Navigator.of(context).pop(path);
              }
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery…'),
          ),
        ),
        if (isCustom)
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(WallpaperPickerScreen.kDefault),
            icon: const Icon(Icons.wallpaper),
            label: const Text('Use default color'),
          ),
        const SizedBox(height: 8),
        Text(
          'Custom images can be cropped and resized before applying.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TileFrame extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;

  const _TileFrame({
    required this.child,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (selected)
                const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
