import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// The `.orb-button` family: primary / secondary / ghost / danger.
class OButton extends StatelessWidget {
  const OButton({
    super.key,
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final String style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = C.blue;
    Color fg = Colors.white;
    Color border = Colors.transparent;
    switch (style) {
      case 'secondary':
        bg = Colors.white;
        border = const Color(0xFFB8C9D4);
        fg = C.blue;
        break;
      case 'ghost':
        bg = Colors.transparent;
        fg = C.muted;
        break;
      case 'danger':
        bg = const Color(0xFF924541);
        break;
    }
    final txt = T(12, color: fg, w: FontWeight.w700);
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Pressable(
        onTap: onTap,
        color: bg,
        radius: 12,
        border: Border.all(color: border),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(label, textAlign: TextAlign.center, style: txt),
                ),
                if (style == 'primary') ...[
                  const SizedBox(width: 8),
                  OIcon('chevron', size: 16, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White labelled checkbox row (`.orb-check`).
class OCheck extends StatelessWidget {
  const OCheck({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      color: Colors.white,
      radius: 12,
      border: Border.all(color: C.line),
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 22),
        child: Row(
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: C.blue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: Color(0xFF767676), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: T(12))),
          ],
        ),
      ),
    );
  }
}

/// Loading row with a rotating ring (`.orb-loading`).
class Spinner extends StatefulWidget {
  const Spinner({super.key});

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: CustomPaint(size: const Size(20, 20), painter: _RingPainter()),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFC1D1DB);
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    canvas.drawArc(r, -math.pi / 2, math.pi / 2, false, base..color = C.blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small dropdown (`select` inside `.orb-field`).
class OSelect extends StatelessWidget {
  const OSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T(11, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFCBD7DF)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : null,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: T(12),
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: C.ink),
              items: [
                for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
