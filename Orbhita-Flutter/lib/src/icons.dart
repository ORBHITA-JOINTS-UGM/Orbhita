import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

const Map<String, String> _paths = {
  'home': 'M3 10l9-7 9 7v10h-6v-7H9v7H3z',
  'calendar': 'M4 5h16v16H4z M8 2v6 M16 2v6 M4 10h16',
  'plus': 'M12 4v16 M4 12h16',
  'settings':
      'M12 8a4 4 0 1 0 0 8a4 4 0 0 0 0-8 M12 2v3 M12 19v3 M2 12h3 M19 12h3 M5 5l2 2 M17 17l2 2 M5 19l2-2 M17 7l2-2',
  'chevron': 'M9 5l7 7-7 7',
  'arrow': 'M19 12H5 M11 6l-6 6 6 6',
  'file': 'M6 2h8l4 4v16H6z M14 2v5h5 M9 12h6 M9 16h6',
  'mic':
      'M9 3a3 3 0 0 1 6 0v8a3 3 0 0 1-6 0z M5 9v2a7 7 0 0 0 14 0V9 M12 18v4 M8 22h8',
  'check': 'M5 12l4 4L19 6',
  'bell': 'M6 16h12l-2-3V9a4 4 0 0 0-8 0v4z M10 20h4',
  'clock': 'M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18 M12 7v5l4 2',
  'spark': 'M12 2l3 7 7 3-7 3-3 7-3-7-7-3 7-3z',
  'warning': 'M12 3l10 18H2z M12 9v5 M12 17v1',
  'cloud': 'M7 18H5a4 4 0 0 1 0-8 7 7 0 0 1 13-2 5 5 0 0 1 1 10h-2 M12 11v10 M8 17l4 4 4-4',
  'send': 'M12 19V5 M5 12l7-7 7 7',
};

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Stroke icon drawn from the original SVG path data.
class OIcon extends StatelessWidget {
  const OIcon(this.name, {super.key, this.size = 20, this.color, this.stroke});

  final String name;
  final double size;
  final Color? color;
  final double? stroke;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? C.ink;
    final d = _paths[name] ?? _paths['spark']!;
    final sw = stroke ?? (name == 'send' ? 2 : 1.65);
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="${_hex(c)}" stroke-width="$sw" stroke-linecap="round" '
        'stroke-linejoin="round"><path d="$d"/></svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// The ORBHITA logo mark ("O" glyph image).
class Orbit extends StatelessWidget {
  const Orbit({super.key, required this.height, this.opacity = 1});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        'assets/images/logo.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}

const String _googleSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_googleSvg, width: size, height: size);
}
