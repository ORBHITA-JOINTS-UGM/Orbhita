import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Paints the four CSS `radial-gradient(at X Y, colour 0, transparent 50%)`
/// layers of the landing background. CSS sizes each gradient to the farthest
/// corner, and the colour fades out at 50% of that radius.
class LandingBgPainter extends CustomPainter {
  const LandingBgPainter();

  static const _layers = <(double, double, Color)>[
    (0.8, 0.0, Color(0xFF2F5671)),
    (0.0, 0.4, Color(0xFF456882)),
    (0.8, 1.0, Color(0xFFDECBBF)),
    (0.2, 1.0, Color(0xFF1D3E56)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final (fx, fy, color) in _layers.reversed) {
      final c = Offset(size.width * fx, size.height * fy);
      final far = [
        c.distance,
        (Offset(size.width, 0) - c).distance,
        (Offset(0, size.height) - c).distance,
        (Offset(size.width, size.height) - c).distance,
      ].reduce(math.max);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: far * 0.5));
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LandingBgPainter oldDelegate) => false;
}

/// A blurred circular glow.
class Blob extends StatelessWidget {
  const Blob({super.key, required this.size, required this.color, required this.sigma});

  final double size;
  final Color color;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
