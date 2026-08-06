import 'dart:math' as math;

import 'package:flutter/material.dart';

class SurfaceShape {
  final BorderRadius rounded;
  final BevelSpec? bevel;

  const SurfaceShape.rounded(this.rounded) : bevel = null;
  const SurfaceShape.beveled(this.bevel) : rounded = BorderRadius.zero;

  bool get isBeveled => bevel != null && bevel!.any;

  BorderRadius get rippleRadius =>
      isBeveled ? BorderRadius.zero : rounded;

  BorderRadius get roundedOrTight =>
      isBeveled ? const BorderRadius.all(Radius.circular(2)) : rounded;

  ShapeBorder toShapeBorder() {
    final b = bevel;
    if (b != null && b.any) return _BevelShapeBorder(b);
    return RoundedRectangleBorder(borderRadius: rounded);
  }
}

Path surfacePath(Rect rect, SurfaceShape shape) {
  final b = shape.bevel;
  if (b != null && b.any) return _bevelPath(rect, b);
  return Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: shape.rounded.topLeft,
        topRight: shape.rounded.topRight,
        bottomLeft: shape.rounded.bottomLeft,
        bottomRight: shape.rounded.bottomRight,
      ),
    );
}

Path _bevelPath(Rect rect, BevelSpec b) {
  final w = rect.width;
  final h = rect.height;
  final s = b.size;
  final path = Path()..moveTo(0, b.topLeft ? s : 0);
  if (b.topLeft) path.lineTo(s, 0);
  path.lineTo(b.topRight ? w - s : w, 0);
  if (b.topRight) path.lineTo(w, s);
  path.lineTo(w, b.bottomRight ? h - s : h);
  if (b.bottomRight) path.lineTo(w - s, h);
  path.lineTo(b.bottomLeft ? s : 0, h);
  if (b.bottomLeft) path.lineTo(0, h - s);
  path.close();
  return path;
}

class _BevelShapeBorder extends ShapeBorder {
  final BevelSpec bevel;

  const _BevelShapeBorder(this.bevel);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      surfacePath(rect, SurfaceShape.beveled(bevel));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      getInnerPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is _BevelShapeBorder ? (t < 0.5 ? a : this) : null;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is _BevelShapeBorder ? (t < 0.5 ? this : b) : null;
}

class BevelSpec {
  final double size;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const BevelSpec(
    this.size, {
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  bool get any => topLeft || topRight || bottomLeft || bottomRight;
}
// here are the current themes etc, and their respective 'logos'
// will add more futurely
enum ThemeStyle {
  def('default', 'Default', 'assets/themes/default.jpg'),
  midnight('midnight', 'Midnight', 'assets/themes/midnight.jpg'),
  matrix('matrix', 'Matrix', 'assets/themes/matrix.jpg'),
  lain('lain', 'Lain', 'assets/themes/lain.jpg'),
  cyberpunk('cyberpunk', 'Cyberpunk 2077', 'assets/themes/cyberpunk.jpg'),
  bladerunner('bladerunner', 'Blade Runner 2049', 'assets/themes/bladerunner.jpg');

  const ThemeStyle(this.id, this.label, this.imageAsset);

  final String id;
  final String label;
  final String imageAsset;

  static ThemeStyle fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => ThemeStyle.def);

  SurfaceShape bubbleShapeFor(bool mine) {
    switch (this) {
      case ThemeStyle.def:
        return SurfaceShape.rounded(BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ));
      case ThemeStyle.midnight:
        return SurfaceShape.rounded(BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(mine ? 12 : 6),
          bottomRight: Radius.circular(mine ? 6 : 12),
        ));
      case ThemeStyle.matrix:
        return const SurfaceShape.rounded(BorderRadius.zero);
      case ThemeStyle.lain:
        return SurfaceShape.beveled(BevelSpec(12,
            topLeft: mine, bottomRight: mine, topRight: !mine, bottomLeft: !mine));
      case ThemeStyle.cyberpunk:
        return SurfaceShape.beveled(BevelSpec(16,
            topRight: mine, bottomLeft: mine, topLeft: !mine, bottomRight: !mine));
      case ThemeStyle.bladerunner:
        return const SurfaceShape.rounded(BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ));
    }
  }

  SurfaceShape get noticeShape {
    switch (this) {
      case ThemeStyle.def:
        return const SurfaceShape.rounded(BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(16),
        ));
      case ThemeStyle.midnight:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(10)));
      case ThemeStyle.matrix:
        return const SurfaceShape.rounded(BorderRadius.zero);
      case ThemeStyle.lain:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(2)));
      case ThemeStyle.cyberpunk:
        return SurfaceShape.beveled(const BevelSpec(14, topLeft: true, bottomRight: true));
      case ThemeStyle.bladerunner:
        return const SurfaceShape.rounded(BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ));
    }
  }

  SurfaceShape get inputShape {
    switch (this) {
      case ThemeStyle.def:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(24)));
      case ThemeStyle.midnight:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(14)));
      case ThemeStyle.matrix:
        return const SurfaceShape.rounded(BorderRadius.zero);
      case ThemeStyle.lain:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(2)));
      case ThemeStyle.cyberpunk:
        return SurfaceShape.beveled(const BevelSpec(12, topRight: true, bottomLeft: true));
      case ThemeStyle.bladerunner:
        return const SurfaceShape.rounded(BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ));
    }
  }

  SurfaceShape get fabShape {
    switch (this) {
      case ThemeStyle.def:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(28)));
      case ThemeStyle.midnight:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(20)));
      case ThemeStyle.matrix:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(4)));
      case ThemeStyle.lain:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(4)));
      case ThemeStyle.cyberpunk:
        return SurfaceShape.beveled(const BevelSpec(10, topRight: true, bottomLeft: true));
      case ThemeStyle.bladerunner:
        return const SurfaceShape.rounded(BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ));
    }
  }

  SurfaceShape get buttonShape {
    switch (this) {
      case ThemeStyle.def:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(22)));
      case ThemeStyle.midnight:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(16)));
      case ThemeStyle.matrix:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(2)));
      case ThemeStyle.lain:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(2)));
      case ThemeStyle.cyberpunk:
        return SurfaceShape.beveled(const BevelSpec(8, topRight: true, bottomLeft: true));
      case ThemeStyle.bladerunner:
        return const SurfaceShape.rounded(BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ));
    }
  }

  SurfaceShape get cardShape {
    switch (this) {
      case ThemeStyle.def:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(18)));
      case ThemeStyle.midnight:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(14)));
      case ThemeStyle.matrix:
        return const SurfaceShape.rounded(BorderRadius.zero);
      case ThemeStyle.lain:
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(2)));
      case ThemeStyle.cyberpunk:
        return SurfaceShape.beveled(const BevelSpec(14, topRight: true, bottomLeft: true));
      case ThemeStyle.bladerunner:
        return const SurfaceShape.rounded(BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ));
    }
  }

  OutlinedBorder get outlinedButtonShape {
    switch (this) {
      case ThemeStyle.def:
        return const StadiumBorder();
      case ThemeStyle.midnight:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
      case ThemeStyle.matrix:
      case ThemeStyle.lain:
      case ThemeStyle.cyberpunk:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        );
      case ThemeStyle.bladerunner:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        );
    }
  }

  OutlinedBorder get outlinedFabShape {
    switch (this) {
      case ThemeStyle.def:
        return const CircleBorder();
      case ThemeStyle.midnight:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
      case ThemeStyle.matrix:
      case ThemeStyle.lain:
      case ThemeStyle.cyberpunk:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        );
      case ThemeStyle.bladerunner:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        );
    }
  }

  bool get useScanlines => this == ThemeStyle.lain;

  bool get useGlitch => this == ThemeStyle.lain;

  bool get gradientBubbles => switch (this) {
        ThemeStyle.cyberpunk ||
        ThemeStyle.matrix ||
        ThemeStyle.lain ||
        ThemeStyle.bladerunner =>
          true,
        _ => false,
      };

  Color? get edgeColor {
    final c = switch (this) {
      ThemeStyle.matrix => 0xFF00FF41,
      ThemeStyle.lain => 0xFF00FFFF,
      ThemeStyle.cyberpunk => 0xFF00F0FF,
      ThemeStyle.bladerunner => 0xFFFFB347,
      _ => null,
    };
    return c == null ? null : Color(c);
  }

  Color? get glowColor {
    final c = switch (this) {
      ThemeStyle.matrix => 0xFF00FF41,
      ThemeStyle.lain => 0xFFFF0066,
      ThemeStyle.cyberpunk => 0xFFFCE300,
      ThemeStyle.bladerunner => 0xFFFF2A6D,
      _ => null,
    };
    return c == null ? null : Color(c);
  }

  double get glowBlur => switch (this) {
        ThemeStyle.matrix => 10,
        ThemeStyle.lain => 12,
        ThemeStyle.cyberpunk => 14,
        ThemeStyle.bladerunner => 10,
        _ => 0,
      };

  double get borderWidth => switch (this) {
        ThemeStyle.matrix => 1.2,
        ThemeStyle.lain => 1.4,
        ThemeStyle.cyberpunk => 1.6,
        ThemeStyle.bladerunner => 1.2,
        _ => 0,
      };

  Path previewPath(Rect rect) {
    switch (this) {
      case ThemeStyle.def:
        return Path()..addOval(rect);
      case ThemeStyle.midnight:
        return _blobPath(rect);
      case ThemeStyle.matrix:
        return Path()..addRect(rect);
      case ThemeStyle.lain:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)));
      case ThemeStyle.cyberpunk:
        return _bevelPath(
          rect,
          const BevelSpec(10, topLeft: true, bottomRight: true),
        );
      case ThemeStyle.bladerunner:
        return _bevelPath(
          rect,
          const BevelSpec(5, topRight: true, bottomLeft: true),
        );
    }
  }
}

Path _blobPath(Rect rect) {
  const n = 9;
  final c = rect.center;
  final base = rect.shortestSide / 2;
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = 2 * math.pi * i / n;
    final amp = 0.18 * math.sin(3 * a + 0.7) + 0.09 * math.cos(5 * a + 1.3);
    final rr = base * (1 + amp);
    pts.add(Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a)));
  }
  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = pts[i];
    final p1 = pts[(i + 1) % n];
    final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
  }
  path.close();
  return path;
}

OutlineInputBorder inputFieldBorder(ThemeStyle style, double radius,
    {double width = 1.2}) {
  final r = style == ThemeStyle.matrix ? 0.0 : radius;
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(r),
    borderSide: style == ThemeStyle.matrix
        ? BorderSide(color: const Color(0xFF00FF41), width: width)
        : BorderSide.none,
  );
}
