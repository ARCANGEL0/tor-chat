import 'dart:async';

import 'package:flutter/material.dart';

import '../state/theme_controller.dart';

enum AppToastStyle { info, error }

/// Pretty themed toast that appears top-left, over everything, and auto-hides
/// after 5 seconds. Colors/font are customizable in Settings > Theme > Toasts.
class AppToast {
  static void show(
    BuildContext context,
    String message, {
    AppToastStyle style = AppToastStyle.info,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastCard(
        message: message,
        style: style,
        duration: duration,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastCard extends StatefulWidget {
  final String message;
  final AppToastStyle style;
  final Duration duration;
  final VoidCallback onDone;

  const _ToastCard({
    required this.message,
    required this.style,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    _ctrl.reverse().whenCompleteOrCancel(widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ThemeController.instance.settings;
    final scheme = Theme.of(context).colorScheme;
    final isError = widget.style == AppToastStyle.error;
    final bg = isError
        ? scheme.errorContainer
        : (s.toastBackground != null
            ? Color(s.toastBackground!)
            : const Color(0xFF2A1F4D));
    final fg = isError
        ? scheme.onErrorContainer
        : (s.toastText != null ? Color(s.toastText!) : onColor(bg));
    final font = s.toastFont.trim();
    final size = s.toastFontSize;
    final width = MediaQuery.of(context).size.width;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: width - 24),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 18,
                    color: isError
                        ? fg
                        : (s.toastBackground != null
                            ? fg
                            : const Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: fg,
                        fontSize: size,
                        fontWeight: FontWeight.w600,
                        fontFamily: font.isEmpty ? null : font,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
