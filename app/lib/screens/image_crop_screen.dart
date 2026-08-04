import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../widgets/app_toast.dart';

/// WhatsApp-style image picker used before sending a photo in a chat:
/// full-screen preview over a transparent header (crop + download + X),
/// and a circular "Send" button bottom-right. Tapping the crop icon switches
/// to a live crop window where you drag the region and hit "Apply".
///
/// With [isSend] false it keeps the classic in-app crop window used for
/// avatars and wallpapers. Pops with the (possibly cropped) image bytes, or
/// `null` if canceled.
class ImageCropScreen extends StatefulWidget {
  final Uint8List image;
  final bool circle;
  final String title;
  final bool isSend;

  const ImageCropScreen({
    super.key,
    required this.image,
    required this.circle,
    this.title = 'Crop image',
    this.isSend = false,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();

  static Future<Uint8List?> crop(
    BuildContext context, {
    required Uint8List image,
    required bool circle,
    String title = 'Crop image',
    bool isSend = false,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          image: image,
          circle: circle,
          title: title,
          isSend: isSend,
        ),
      ),
    );
  }
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();
  Completer<Uint8List>? _pending;
  bool _busy = false;
  bool _saving = false;
  bool _cropMode = false;
  late Uint8List _displayImage;

  @override
  void initState() {
    super.initState();
    _displayImage = widget.image;
  }

  Future<void> _applyCrop() async {
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
      if (mounted) {
        setState(() {
          _displayImage = bytes;
          _cropMode = false;
          _busy = false;
        });
      }
    } catch (_) {
      _pending = null;
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, 'Could not crop that image.',
          style: AppToastStyle.error);
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

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save image',
        fileName: 'image_${DateTime.now().millisecondsSinceEpoch}.png',
        type: FileType.any,
        bytes: _displayImage,
      );
      if (path != null && mounted) {
        AppToast.show(context, 'Saved to $path');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not save image: $e',
            style: AppToastStyle.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmSend() {
    if (_saving) return;
    Navigator.of(context).pop(_displayImage);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSend) return _buildClassic(context);
    return _buildSend(context);
  }

  Widget _buildClassic(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _busy ? null : _applyCrop,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          ? 'The circle shows how it will look. Pinch, zoom '
                              'or drag the image to frame it.'
                          : 'Drag the corners to resize, or pinch/zoom to '
                              'frame the area to use as the wallpaper.',
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

  Widget _buildSend(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sendGradient = const [Color(0xFF5B2DD3), Color(0xFF8B5CF6)];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Transparent header over the image.
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_cropMode)
                  ColoredBox(
                    color: Colors.black,
                    child: Crop(
                      image: _displayImage,
                      controller: _controller,
                      interactive: true,
                      maskColor: Colors.black.withValues(alpha: 0.55),
                      baseColor: Colors.black,
                      cornerDotBuilder: (size, alignment) =>
                          DotControl(color: scheme.primary),
                      onCropped: _onCropped,
                      progressIndicator: Center(
                        child: CircularProgressIndicator(color: scheme.primary),
                      ),
                    ),
                  )
                else
                  InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        _displayImage,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Transparent top bar: X left, crop + download right.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Cancel',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _cropMode
                          ? () => setState(() => _cropMode = false)
                          : () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (_cropMode) ...[
                      IconButton(
                        tooltip: 'Cancel crop',
                        icon: const Icon(Icons.crop_free, color: Colors.white),
                        onPressed: () => setState(() => _cropMode = false),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Apply crop',
                        icon: const Icon(Icons.check, color: Colors.white),
                        onPressed: _busy ? null : _applyCrop,
                      ),
                    ] else ...[
                      IconButton(
                        tooltip: 'Save to device',
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: _saving ? null : _download,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Crop',
                        icon: const Icon(Icons.crop, color: Colors.white),
                        onPressed: () => setState(() => _cropMode = true),
                      ),
                    ],
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),

          // Bottom-right circular Send button.
          Positioned(
            right: 20,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: _cropMode ? null : _confirmSend,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _cropMode
                          ? const [Colors.white24, Colors.white24]
                          : sendGradient,
                    ),
                    boxShadow: _cropMode
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.55),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),

          // Bottom bar for crop mode.
          if (_cropMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _cropMode = false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _busy ? null : _applyCrop,
                        icon: const Icon(Icons.check),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
