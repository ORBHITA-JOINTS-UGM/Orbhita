import 'package:flutter/material.dart';

/// Colour tokens taken from the original stylesheet.
class C {
  static const ink = Color(0xFF1B3C53);
  static const blue = Color(0xFF234C6A);
  static const muted = Color(0xFF456882);
  static const sand = Color(0xFFD2C1B6);
  static const cream = Color(0xFFF8F6F3);
  static const line = Color(0xFFDCE4E9);
  static const calLine = Color(0xFFE0E5E8);
  static const soft = Color(0xFFEDF2F5);
}

const _fallback = ['Helvetica', 'Roboto'];

/// Text style helper. Default line-height is 1.5 like the original root style.
TextStyle T(
  double size, {
  Color color = C.ink,
  FontWeight w = FontWeight.w400,
  double? h = 1.5,
  double? ls,
  TextDecoration? deco,
  String family = 'Arial',
}) {
  return TextStyle(
    fontFamily: family,
    fontFamilyFallback: _fallback,
    fontSize: size,
    color: color,
    fontWeight: w,
    height: h,
    letterSpacing: ls,
    decoration: deco ?? TextDecoration.none,
    decorationColor: color,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    fontFamilyFallback: _fallback,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.blue,
      primary: C.blue,
      surface: Colors.white,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Pressable surface with optional fill, border and radius.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.radius = 0,
    this.border,
    this.padding = EdgeInsets.zero,
    this.shadows,
    this.gradient,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final BoxBorder? border;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: r,
          border: border,
          boxShadow: shadows,
          gradient: gradient,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A rounded box with a coloured left bar (CSS `border-left` + radius).
class LeftBar extends StatelessWidget {
  const LeftBar({
    super.key,
    required this.bar,
    required this.bg,
    required this.child,
    this.radius = 3,
    this.width = 2,
    this.padding = EdgeInsets.zero,
  });

  final Color bar;
  final Color bg;
  final Widget child;
  final double radius;
  final double width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: Border(left: BorderSide(color: bar, width: width)),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Dashed rounded rectangle border.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 12,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(color, radius),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.5),
        Radius.circular(radius),
      ));
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color || old.radius != radius;
}
