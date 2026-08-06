import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/theme_style.dart';

/// Whole-app CRT effect for scanline/glitch themes (Lain). Subtle scanlines
/// plus the occasional RGB tear bar on top of everything. Decorative only,
/// ignores taps.
class ThemeFX extends StatelessWidget {
  final ThemeStyle style;
  final Widget child;

  const ThemeFX({super.key, required this.style, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (style.useScanlines)
          const IgnorePointer(
            child: CustomPaint(painter: _ScanlinesPainter()),
          ),
        if (style.useGlitch)
          const IgnorePointer(child: _GlitchOverlay()),
      ],
    );
  }
}

class _ScanlinesPainter extends CustomPainter {
  const _ScanlinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    var y = 0.0;
    const step = 3.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += step;
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinesPainter oldDelegate) => false;
}

/// Random glitch tears now and then. Mostly quiet.
class _GlitchOverlay extends StatefulWidget {
  const _GlitchOverlay();

  @override
  State<_GlitchOverlay> createState() => _GlitchOverlayState();
}

class _GlitchOverlayState extends State<_GlitchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _GlitchPainter(seed: (_controller.value * 1000).round()),
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  final int seed;

  const _GlitchPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    // Only ~14% of frames glitch.
    if (rand.nextDouble() > 0.14) return;
    final cyan = Paint()..color = const Color(0x2200FFFF);
    final magenta = Paint()..color = const Color(0x22FF00FF);
    for (var i = 0; i < 3; i++) {
      final y = rand.nextDouble() * size.height;
      final h = 1.0 + rand.nextDouble() * 3.0;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, h),
        i.isEven ? cyan : magenta,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
