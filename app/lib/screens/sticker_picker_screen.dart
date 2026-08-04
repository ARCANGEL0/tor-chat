import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/sticker.dart';
import '../../services/sticker_service.dart';
import '../../state/theme_controller.dart';

/// Sticker picker modal - shows available sticker packs with stickers
class StickerPickerScreen extends StatefulWidget {
  final Function(String packId, String stickerId, String imagePath) onStickerSelected;

  const StickerPickerScreen({
    super.key,
    required this.onStickerSelected,
  });

  @override
  State<StickerPickerScreen> createState() => _StickerPickerScreenState();
}

class _StickerPickerScreenState extends State<StickerPickerScreen> {
  final _stickerService = StickerService.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _stickerService.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
    _stickerService.addListener(_onStickerServiceChange);
  }

  @override
  void dispose() {
    _stickerService.removeListener(_onStickerServiceChange);
    super.dispose();
  }

  void _onStickerServiceChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tc = ThemeController.instance;
    final accent = Color(tc.settings.accentColor);

    if (_loading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final packs = _stickerService.packs;

    if (packs.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_emotions_outlined, size: 64, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No stickers yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Import WhatsApp stickers or add your own',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _importWhatsApp(),
                icon: const Icon(Icons.download),
                label: const Text('Import from WhatsApp'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Stickers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Import from WhatsApp',
                  onPressed: _importWhatsApp,
                  icon: Icon(Icons.download, color: accent),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Pack tabs
          if (packs.length > 1)
            DefaultTabController(
              length: packs.length,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: scheme.onSurfaceVariant,
                tabs: packs.map((p) => Tab(text: p.name)).toList(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    packs.first.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (packs.first.isWhatsApp) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // Sticker grid
          Expanded(
            child: TabBarView(
              children: packs.map((pack) => _StickerPackGrid(
                pack: pack,
                onStickerTap: (sticker) => widget.onStickerSelected(
                  pack.id,
                  sticker.id,
                  sticker.imagePath,
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    ).animate().slideY(
      begin: 1,
      end: 0,
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _importWhatsApp() async {
    Navigator.of(context).pop();
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('Importing WhatsApp stickers...')),
    );
    await _stickerService.importWhatsAppStickers();
    scaffold.showSnackBar(
      SnackBar(content: Text('WhatsApp stickers imported!')),
    );
  }
}

class _StickerPackGrid extends StatelessWidget {
  final StickerPack pack;
  final Function(Sticker) onStickerTap;

  const _StickerPackGrid({
    required this.pack,
    required this.onStickerTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: pack.stickers.length,
      itemBuilder: (context, index) {
        final sticker = pack.stickers[index];
        return GestureDetector(
          onTap: () => onStickerTap(sticker),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildStickerImage(sticker),
            ),
          ).animate()
            .fadeIn(duration: 200.ms, delay: (index * 30).ms)
            .scale(begin: const Offset(0.8, 0.8)),
        );
      },
    );
  }

  Widget _buildStickerImage(Sticker sticker) {
    // Check if it's a base64 encoded image
    if (sticker.imagePath.startsWith('data:') || 
        sticker.imagePath.length > 100 && !sticker.imagePath.contains('/')) {
      // Base64 encoded
      try {
        final base64 = sticker.imagePath.contains(',') 
            ? sticker.imagePath.split(',').last 
            : sticker.imagePath;
        return Image.memory(
          base64Decode(base64),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    }
    // Asset or file path
    if (sticker.imagePath.startsWith('asset:')) {
      return Image.asset(
        sticker.imagePath.substring(6),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (sticker.imagePath.startsWith('/')) {
      return Image.file(
        File(sticker.imagePath),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}