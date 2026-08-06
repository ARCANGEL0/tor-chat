import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/app_settings.dart';
import '../state/theme_controller.dart';
import '../state/theme_style.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';

/// Animated entry screen: the app icon with pulsing onion rings + name, then
/// transitions to the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(scale: curved, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    final s = tc.settings;
    if (ThemeStyle.fromId(s.themeStyle) == ThemeStyle.matrix) {
      return _matrixSplash(s);
    }
    final scheme = Theme.of(context).colorScheme;
    final logoColor =
        Color(s.logoColor ?? AppSettings.defaultLogoColor);
    final bgColor = s.splashBackground != null
        ? Color(s.splashBackground!)
        : (s.background != null
            ? Color(s.background!)
            : Theme.of(context).scaffoldBackgroundColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AppIconPulse(logoColor: logoColor),
            const SizedBox(height: 36),
            Text(
              'OnionChat',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: logoColor,
                  ),
            ).animate().fadeIn(duration: 900.ms, delay: 300.ms).slideY(begin: 0.2),
            const SizedBox(height: 10),
            Text(
              'Anonymous P2P chat via Tor hidden services',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            )
                .animate()
                .fadeIn(duration: 900.ms, delay: 600.ms)
                .slideY(begin: 0.3),
            const SizedBox(height: 48),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(4),
                color: logoColor,
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 1000.ms),
          ],
        ),
      ),
    );
  }

  Widget _matrixSplash(AppSettings s) {
    final neon = const Color(0xFF00FF41);
    final mainFont = s.mainFont.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MatrixRain(),
          const ColoredBox(color: Color(0x66000000)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'OnionChat',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: neon,
                    fontFamily: mainFont.isEmpty ? null : mainFont,
                    shadows: [
                      Shadow(color: neon.withValues(alpha: 0.6), blurRadius: 12),
                      Shadow(color: neon.withValues(alpha: 0.35), blurRadius: 28),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 700.ms, delay: 200.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 14),
                Text(
                  'Anonymous P2P chat via Tor hidden services',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 1.2,
                    color: neon.withValues(alpha: 0.75),
                    fontFamily: mainFont.isEmpty ? null : mainFont,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 700.ms, delay: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixRain extends StatefulWidget {
  const _MatrixRain();

  @override
  State<_MatrixRain> createState() => _MatrixRainState();
}

const _kana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789';

const _rainFont = 20.0;
const _rainTrail = 10;
const _rainMinSpeed = 1.2;
const _rainMaxSpeed = 2.6;

class _MatrixColumn {
  double head;
  double speed;
  int glyphIndex;

  _MatrixColumn(this.head, this.speed, this.glyphIndex);
}

class _MatrixRainState extends State<_MatrixRain> {
  final List<String> _chars = _kana.split('');
  final List<ui.Image> _glyphs = [];
  final List<_MatrixColumn> _columns = [];
  Timer? _timer;
  int _cols = 0;
  int _rows = 0;

  @override
  void initState() {
    super.initState();
    _renderGlyphs();
  }

  Future<void> _renderGlyphs() async {
    for (final c in _chars) {
      final tp = TextPainter(
        text: TextSpan(
          text: c,
          style: const TextStyle(fontSize: _rainFont, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final recorder = ui.PictureRecorder();
      tp.paint(Canvas(recorder), Offset.zero);
      final img = await recorder.endRecording().toImage(
            tp.width.ceil().clamp(1, 512),
            tp.height.ceil().clamp(1, 512),
          );
      _glyphs.add(img);
    }
    if (mounted) _start();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (!mounted) return;
      setState(_tick);
    });
  }

  void _tick() {
    final rng = Random();
    for (final c in _columns) {
      c.head += c.speed;
      c.glyphIndex = rng.nextInt(_chars.length);
      if (c.head > _rows + _rainTrail) {
        c.head = -rng.nextInt(_rainTrail * 3).toDouble();
        c.speed = _rainMinSpeed + rng.nextDouble() * (_rainMaxSpeed - _rainMinSpeed);
      }
    }
  }

  void _ensureColumns(Size size) {
    final cols = (size.width / _rainFont).ceil().clamp(1, 200);
    final rows = (size.height / _rainFont).ceil().clamp(1, 300);
    if (cols != _cols || rows != _rows) {
      _cols = cols;
      _rows = rows;
      _columns.clear();
      final rng = Random();
      for (var i = 0; i < _cols; i++) {
        _columns.add(_MatrixColumn(
          -rng.nextInt(_rainTrail * 3).toDouble(),
          _rainMinSpeed + rng.nextDouble() * (_rainMaxSpeed - _rainMinSpeed),
          rng.nextInt(_chars.length),
        ));
      }
      final extra = rng.nextInt(rows.clamp(1, 300));
      for (var i = 0; i < extra && i < _columns.length; i++) {
        _columns[i].head += rng.nextInt(rows).toDouble();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final g in _glyphs) {
      g.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureColumns(size);
        return CustomPaint(
          painter: _MatrixRainPainter(_columns, _glyphs, _rows),
          size: size,
        );
      },
    );
  }
}

class _MatrixRainPainter extends CustomPainter {
  _MatrixRainPainter(this.columns, this.glyphs, this.rows);

  final List<_MatrixColumn> columns;
  final List<ui.Image> glyphs;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    if (glyphs.isEmpty) return;
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i];
      final x = i * _rainFont;
      for (var t = 0; t < _rainTrail; t++) {
        final row = col.head - t;
        if (row < 0 || row >= rows) continue;
        final glyph = glyphs[(col.glyphIndex + t) % glyphs.length];
        final fade = t == 0 ? 1.0 : 0.05 + 0.75 * (1 - t / _rainTrail);
        final tint = t == 0 ? Colors.white : const Color(0xFF00FF41);
        final paint = Paint()
          ..colorFilter = ColorFilter.mode(
            tint.withValues(alpha: fade),
            BlendMode.srcIn,
          );
        canvas.drawImage(
          glyph,
          Offset(
            x + (_rainFont - glyph.width) / 2,
            row * _rainFont,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MatrixRainPainter oldDelegate) => true;
}

class _AppIconPulse extends StatefulWidget {
  final Color logoColor;
  const _AppIconPulse({required this.logoColor});

  @override
  State<_AppIconPulse> createState() => _AppIconPulseState();
}

class _AppIconPulseState extends State<_AppIconPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 2; i++)
                Transform.scale(
                  scale: 0.6 + 0.5 * _pulse(t, i),
                  child: Opacity(
                    opacity: (1 - _pulse(t, i)) * 0.5,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.logoColor.withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ClipOval(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: widget.logoColor.withValues(alpha: 0.45),
                        blurRadius: 34,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const AppLogo(size: 84),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _pulse(double t, int offset) {
    final v = (t + offset * 0.5) % 1.0;
    return Curves.easeOutCubic.transform(v);
  }
}
