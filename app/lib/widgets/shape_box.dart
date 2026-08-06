import 'package:flutter/material.dart';

import '../themes/theme_style.dart';

/// Draws a SurfaceShape (rounded or beveled) with a color/gradient fill, an
/// optional neon border, glow or plain shadow. Clips the child to the shape.
class ShapeBox extends StatelessWidget {
  final SurfaceShape shape;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glowBlur;

  /// Plain drop shadow when there's no glow. Keeps the default theme from
  /// looking flat.
  final BoxShadow? shadow;

  final EdgeInsetsGeometry? padding;
  final Widget? child;

  const ShapeBox({
    super.key,
    required this.shape,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 0,
    this.glowColor,
    this.glowBlur = 0,
    this.shadow,
    this.padding,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final content = padding != null ? Padding(padding: padding!, child: child) : child;
    return CustomPaint(
      painter: _SurfacePainter(
        shape: shape,
        color: color,
        gradient: gradient,
        borderColor: borderColor,
        borderWidth: borderWidth,
        glowColor: glowColor,
        glowBlur: glowBlur,
        shadow: shadow,
      ),
      child: ClipPath(
        clipper: _ShapeClipper(shape),
        child: content,
      ),
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  final SurfaceShape shape;

  const _ShapeClipper(this.shape);

  @override
  Path getClip(Size size) => surfacePath(Offset.zero & size, shape);

  @override
  bool shouldReclip(covariant _ShapeClipper oldClipper) =>
      oldClipper.shape.isBeveled != shape.isBeveled;
}

class _SurfacePainter extends CustomPainter {
  final SurfaceShape shape;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glowBlur;
  final BoxShadow? shadow;

  const _SurfacePainter({
    required this.shape,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 0,
    this.glowColor,
    this.glowBlur = 0,
    this.shadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = surfacePath(rect, shape);

    if (glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!.withValues(alpha: 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur)
          ..style = PaintingStyle.fill,
      );
    } else if (shadow != null) {
      canvas.drawPath(
        path.shift(shadow!.offset),
        Paint()
          ..color = shadow!.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow!.blurRadius)
          ..style = PaintingStyle.fill,
      );
    }

    final fill = Paint()..style = PaintingStyle.fill;
    if (gradient != null) {
      fill.shader = gradient!.createShader(rect);
    } else if (color != null) {
      fill.color = color!;
    }
    canvas.drawPath(path, fill);

    if (borderColor != null && borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = borderColor!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter oldDelegate) =>
      oldDelegate.shape.isBeveled != shape.isBeveled ||
      oldDelegate.color != color ||
      oldDelegate.gradient != gradient ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.glowBlur != glowBlur ||
      oldDelegate.shadow != shadow;
}
