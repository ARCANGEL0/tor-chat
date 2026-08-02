import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/chat_message.dart';

/// Fullscreen viewer for a shared photo/video. Shows a small semi-transparent
/// header with the sender + timestamp and a download button. Downloading uses
/// the OS "Save as" dialog (SAF), so the file never leaves the device.
class MediaViewerScreen extends StatefulWidget {
  final ChatMessage message;
  final Uint8List bytes;
  final Duration? startAt;

  const MediaViewerScreen({
    super.key,
    required this.message,
    required this.bytes,
    this.startAt,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.message.isVideo;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: isVideo
                  ? _ViewerVideo(
                      bytes: widget.bytes,
                      mediaId: widget.message.mediaId ?? '',
                      startAt: widget.startAt,
                    )
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          widget.bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text(
                              'Could not decode image',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _MediaHeader(
                message: widget.message,
                saving: _saving,
                onDownload: _download,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      var name = widget.message.mediaName ?? '';
      if (name.contains('/')) {
        name = name.substring(name.lastIndexOf('/') + 1);
      }
      if (name.isEmpty) {
        final ext = widget.message.isVideo ? 'mp4' : 'jpg';
        name = 'media_${widget.message.mediaId}.$ext';
      }
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Save media',
        fileName: name,
        bytes: widget.bytes,
      );
      if (saved == null) return; // canceled
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save media: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MediaHeader extends StatelessWidget {
  final ChatMessage message;
  final bool saving;
  final VoidCallback onDownload;

  const _MediaHeader({
    required this.message,
    required this.saving,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final name = message.username.isEmpty ? 'Someone' : message.username;
    final ts = message.ts.isEmpty ? '' : '  ·  ${message.ts}';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$name$ts',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
          ),
          IconButton(
            onPressed: saving ? null : onDownload,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Fullscreen video player with tap-to-play/pause.
class _ViewerVideo extends StatefulWidget {
  final Uint8List bytes;
  final String mediaId;
  final Duration? startAt;

  const _ViewerVideo({required this.bytes, required this.mediaId, this.startAt});

  @override
  State<_ViewerVideo> createState() => _ViewerVideoState();
}

class _ViewerVideoState extends State<_ViewerVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/media_${widget.mediaId}.mp4');
      if (!file.existsSync() || file.lengthSync() != widget.bytes.length) {
        await file.writeAsBytes(widget.bytes, flush: true);
      }
      final c = VideoPlayerController.file(file);
      await c.initialize();
      if (widget.startAt != null) await c.seekTo(widget.startAt!);
      await c.play();
      if (!mounted) return;
      setState(() => _controller = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed) {
      return const Center(
        child: Text(
          'Could not play video',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    if (c == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    return GestureDetector(
      onTap: () => c.value.isPlaying ? c.pause() : c.play(),
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}
