import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass_card.dart';
import 'icons.dart';
import 'landing_bg.dart';
import 'theme.dart';

/// Dark gradient landing screen with the "Continue with Google" glass card.
class Landing extends StatelessWidget {
  const Landing({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final small = w <= 480;
      final tiny = w <= 360;

      final logoSize = tiny ? 32.0 : (small ? 40.0 : 56.0);
      final margin = tiny ? 24.0 : (small ? 32.0 : 40.0);
      final bottomMargin = math.max(tiny ? 16.0 : (small ? 20.0 : 24.0), inset);
      final cardPad = tiny
          ? const EdgeInsets.symmetric(vertical: 18, horizontal: 14)
          : small
              ? const EdgeInsets.symmetric(vertical: 22, horizontal: 18)
              : const EdgeInsets.symmetric(vertical: 30, horizontal: 24);
      final radius = small ? 20.0 : 24.0;
      final cardW = math.min(w - margin, 400.0);

      return ClipRect(
        child: ColoredBox(
          color: C.ink,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: LandingBgPainter()),
              ),
              Positioned(
                top: h * 0.2,
                left: -w * 0.1,
                child: const Blob(size: 300, color: Color(0x26DECBBF), sigma: 30),
              ),
              Positioned(
                bottom: h * 0.2,
                right: -w * 0.1,
                child: const Blob(size: 400, color: Color(0x662F5671), sigma: 40),
              ),
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Orbit(height: logoSize * 1.2, opacity: 0.8),
                          const SizedBox(width: 2),
                          Text(
                            'RBHITA',
                            style: T(
                              logoSize,
                              color: Colors.white.withValues(alpha: 0.3),
                              w: FontWeight.w700,
                              ls: logoSize > 40 ? -2 : -1,
                              family: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: bottomMargin),
                    child: SizedBox(
                      width: cardW,
                      child: GlassCard(
                        radius: radius,
                        padding: cardPad,
                        small: small,
                        tiny: tiny,
                        onContinue: onContinue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
