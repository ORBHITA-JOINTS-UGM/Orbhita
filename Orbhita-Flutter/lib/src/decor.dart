import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// `.orb-hero`. The logo's inline style (`height: 1.5em`) wins over the CSS
/// size, so it renders at 1.5 x 14px.
class HeroBlock extends StatelessWidget {
  const HeroBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 196,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment(-0.77, -1),
          end: Alignment(0.77, 1),
          colors: [Color(0xFFEAF0F4), Color(0xFFF0E7E0)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Orbit(height: 21),
          Positioned(
            bottom: 16,
            child: Text(
              'SATU LANGKAH LEBIH JELAS',
              style: T(8, color: C.muted, ls: 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.orb-wave` - static recording waveform.
class WaveBlock extends StatelessWidget {
  const WaveBlock({super.key});

  static const _h = [15, 35, 63, 41, 89, 55, 30, 67, 91, 40, 59, 26, 48];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 143,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var j = 0; j < _h.length; j++) ...[
                if (j > 0) const SizedBox(width: 7),
                Container(
                  width: 5,
                  height: _h[j].toDouble(),
                  decoration: BoxDecoration(
                    color: C.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
          Positioned(
            bottom: 12,
            child: Text('00:18 / 02:00 · contoh', style: T(9, color: C.muted)),
          ),
        ],
      ),
    );
  }
}
