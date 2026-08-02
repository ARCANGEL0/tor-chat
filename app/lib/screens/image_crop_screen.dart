import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// In-app, app-themed crop window. Shows the picked image behind a live
/// silhouette (circle for avatars/chat pictures, rectangle for wallpapers)
/// that shows exactly what will be kept, with pinch/zoom/drag + resizable
/// handles. Pops with the cropped image bytes, or `null` if canceled.
class ImageCropScreen extends StatefulWidget {
  final Uint8List image;
  final bool circle;
  final String title;

  const ImageCropScreen({
    super.key,
    required this.image,
    required this.circle,
    this.title = 'Crop image',
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();

  static Future<Uint8List?> crop(
    BuildContext context, {
    required Uint8List image,
    required bool circle,
    String title = 'Crop image',
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) =>
            ImageCropScreen(image: image, circle: circle, title: title),
      ),
    );
  }
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();
  Completer<Uint8List>? _pending;
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy || _pending != null) return;
    setState(() => _busy = true);
    _pending = Completer<Uint8List>();
    if (widget.circle) {
      _controller.cropCircle();
    } else {
      _controller.crop();
    }
    try {
      final bytes =
          await _pending!.future.timeout(const Duration(seconds: 45));
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (_) {
      _pending = null;
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not crop that image.')),
      );
    }
  }

  void _onCropped(CropResult result) {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    if (result is CropSuccess) {
      pending.complete(result.croppedImage);
    } else if (result is CropFailure) {
      pending.completeError(result.cause);
    } else {
      pending.completeError(StateError('Unknown crop result'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _busy ? null : _confirm,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Crop(
                image: widget.image,
                controller: _controller,
                withCircleUi: widget.circle,
                interactive: true,
                maskColor: Colors.black.withValues(alpha: 0.6),
                baseColor: Colors.black,
                cornerDotBuilder: (size, alignment) =>
                    DotControl(color: scheme.primary),
                onCropped: _onCropped,
                progressIndicator: Center(
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    widget.circle
                        ? Icons.circle_outlined
                        : Icons.crop_landscape_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.circle
                          ? 'The circle shows how it will look. Pinch, zoom or '
                              'drag the image to frame it.'
                          : 'Drag the corners to resize, or pinch/zoom to frame '
                              'the area to use as the wallpaper.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
