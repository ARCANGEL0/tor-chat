import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/app_settings.dart';
import '../state/theme_controller.dart';
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
    Timer(const Duration(milliseconds: 2600), () {
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
