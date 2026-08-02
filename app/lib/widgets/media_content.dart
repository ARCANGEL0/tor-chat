import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/chat_message.dart';
import '../state/room_controller.dart';
import 'media_viewer.dart';

/// Renders a shared photo/video inside a message bubble. Bytes are fetched
/// lazily from the host over Tor (or from local memory when we are the host)
/// and cached per session, so the bubble shows a spinner first, then the media.
class MediaContent extends StatefulWidget {
  final ChatMessage message;

  const MediaContent({super.key, required this.message});

  @override
  State<MediaContent> createState() => _MediaContentState();
}

class _MediaContentState extends State<MediaContent> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await RoomController.instance.fetchMedia(widget.message);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load media';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 120,
        height: 90,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (_error != null) {
      return _MediaPlaceholder(
        icon: Icons.broken_image_outlined,
        label: _error!,
        onRetry: _load,
      );
    }
    final bytes = _bytes!;
    if (widget.message.isVideo) {
      return _VideoPlayer(
        bytes: bytes,
        mediaId: widget.message.mediaId!,
        message: widget.message,
      );
    }
    return _PhotoView(bytes: bytes, message: widget.message);
  }
}

class _PhotoView extends StatelessWidget {
  final Uint8List bytes;
  final ChatMessage message;

  const _PhotoView({required this.bytes, required this.message});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: 210,
          height: 210,
          errorBuilder: (_, _, _) => _MediaPlaceholder(
            icon: Icons.broken_image_outlined,
            label: 'Could not decode image',
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(message: message, bytes: bytes),
      ),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  final Uint8List bytes;
  final String mediaId;
  final ChatMessage message;

  const _VideoPlayer({
    required this.bytes,
    required this.mediaId,
    required this.message,
  });

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _controller;
  bool _initializing = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<VideoPlayerController> _ensureController() async {
    final existing = _controller;
    if (existing != null) return existing;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/media_${widget.mediaId}.mp4');
    if (!file.existsSync() || file.lengthSync() != widget.bytes.length) {
      await file.writeAsBytes(widget.bytes, flush: true);
    }
    final c = VideoPlayerController.file(file);
    await c.initialize();
    _controller = c;
    return c;
  }

  Future<void> _togglePlay() async {
    if (_initializing) return;
    setState(() => _initializing = true);
    try {
      final c = await _ensureController();
      if (!mounted) return;
      setState(() => _initializing = false);
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          width: 210,
          height: 140,
          color: Colors.black87,
          child: controller == null
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      size: 48,
                      color: Colors.white70,
                    ),
                    if (_initializing)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                )
              : Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: VideoPlayer(controller),
                    ),
                    if (controller.value.isPlaying)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _VideoControl(
                          controller: controller,
                          bytes: widget.bytes,
                          message: widget.message,
                        ),
                      ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 4,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.only(top: 10),
                      ),
                    ),
                    if (!controller.value.isPlaying)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: Center(
                            child: _initializing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white70,
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_circle_fill,
                                    size: 48,
                                    color: Colors.white70,
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Small expand button that opens the video fullscreen (with sender/timestamp
/// header + download, via [MediaViewerScreen]).
class _VideoControl extends StatelessWidget {
  final VideoPlayerController controller;
  final Uint8List bytes;
  final ChatMessage message;

  const _VideoControl({
    required this.controller,
    required this.bytes,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        await controller.pause();
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              message: message,
              bytes: bytes,
              startAt: controller.value.position,
            ),
          ),
        );
      },
      icon: const Icon(Icons.open_in_full, color: Colors.white),
      color: Colors.white,
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onRetry;

  const _MediaPlaceholder({
    required this.icon,
    required this.label,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      child: Container(
        width: 180,
        height: 90,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null)
              const Text('Tap to retry',
                  style: TextStyle(fontSize: 11, color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
