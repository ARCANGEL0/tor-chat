import 'package:flutter/material.dart';

/// One surface shape: rounded corners, or a bevel (chamfered corner).
class SurfaceShape {
  final BorderRadius rounded;
  final BevelSpec? bevel;

  const SurfaceShape.rounded(this.rounded) : bevel = null;
  const SurfaceShape.beveled(this.bevel) : rounded = BorderRadius.zero;

  bool get isBeveled => bevel != null && bevel!.any;

  /// Radius for ink ripples. Beveled shapes just use a plain rectangle, since
  /// an InkWell can't draw a chamfer.
  BorderRadius get rippleRadius =>
      isBeveled ? BorderRadius.zero : rounded;

  /// Radius for Material fallbacks (like `OutlineInputBorder`) where a chamfer
  /// isn't possible; beveled styles become a near-square corner.
  BorderRadius get roundedOrTight =>
      isBeveled ? const BorderRadius.all(Radius.circular(2)) : rounded;

  /// A Material `ShapeBorder` for this shape. Beveled shapes get a border that
  /// clips the chisel, so Cards/Materials can use it too.
  ShapeBorder toShapeBorder() {
    final b = bevel;
    if (b != null && b.any) return _BevelShapeBorder(b);
    return RoundedRectangleBorder(borderRadius: rounded);
  }
}

/// The path for a [SurfaceShape] inside [rect], used for clipping and painting.
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

/// Path for a beveled box: each cut corner is a straight diagonal
/// [BevelSpec.size] px in from the corner.
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

/// Lets Cards/Materials clip to a beveled box.
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

/// Which corners to cut, and how deep.
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

/// Shape + effects for a template. Reshapes bubbles, input, buttons, cards and
/// the FAB, plus adds glow / scanline / glitch effects on top.
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
        return const SurfaceShape.rounded(BorderRadius.all(Radius.circular(2)));
      case ThemeStyle.cyberpunk:
        // Chiseled box, trailing corners cut.
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

  /// OutlinedBorder for Material buttons. Beveled styles just get a near-square
  /// here; ShapeBox does the actual cut where it matters.
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

  /// OutlinedBorder for the FAB.
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

  /// CRT scanlines. Lain only.
  bool get useScanlines => this == ThemeStyle.lain;

  /// Horizontal glitch tears. Lain only.
  bool get useGlitch => this == ThemeStyle.lain;

  /// Bubble fill becomes a gradient.
  bool get gradientBubbles => switch (this) {
        ThemeStyle.cyberpunk ||
        ThemeStyle.matrix ||
        ThemeStyle.lain ||
        ThemeStyle.bladerunner =>
          true,
        _ => false,
      };

  /// Neon edge color for surfaces.
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

  /// Neon glow, null = none.
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

  /// Border width (0 = none).
  double get borderWidth => switch (this) {
        ThemeStyle.matrix => 1.2,
        ThemeStyle.lain => 1.4,
        ThemeStyle.cyberpunk => 1.6,
        ThemeStyle.bladerunner => 1.2,
        _ => 0,
      };
}
