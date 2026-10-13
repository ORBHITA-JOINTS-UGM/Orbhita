import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'icons.dart';
import 'theme.dart';

/// Month title, "Hari ini" button, Bulan/Minggu switch and month arrows.
class CalHeading extends StatelessWidget {
  const CalHeading({
    super.key,
    required this.month,
    required this.year,
    required this.view,
    required this.narrow,
    required this.onToday,
    required this.onView,
    required this.onMove,
  });

  final int month;
  final int year;
  final String view;
  final bool narrow;
  final VoidCallback onToday;
  final ValueChanged<String> onView;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            'ATUR WAKTU, MULAI SATU LANGKAH',
            style: T(narrow ? 7 : 8, color: C.muted, w: FontWeight.w700, ls: narrow ? 1.15 : 1.4),
          ),
        ),
        Text.rich(
          TextSpan(
            text: '${months[month]} ',
            children: [
              TextSpan(
                text: '$year',
                style: T(narrow ? 22 : 28,
                    color: const Color(0xFF8B9CA8), h: 1.2, ls: -0.7),
              ),
            ],
          ),
          style: T(narrow ? 22 : 28, w: FontWeight.w700, h: 1.2, ls: -0.7),
        ),
      ],
    );
    final tools = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: onToday,
          color: Colors.white,
          radius: 8,
          border: Border.all(color: const Color(0xFFDCE4E9)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text('Hari ini', style: T(11)),
        ),
        const SizedBox(width: 9),
        _switch(),
        const SizedBox(width: 9),
        _arrow('‹', 'Bulan sebelumnya', -1),
        const SizedBox(width: 2),
        _arrow('›', 'Bulan berikutnya', 1),
      ],
    );
    if (narrow) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(
          spacing: 15,
          runSpacing: 15,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [title, FittedBox(fit: BoxFit.scaleDown, child: tools)],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Flexible(child: title), const SizedBox(width: 14), tools],
      ),
    );
  }

  Widget _switch() {
    Widget seg(String id, String label) {
      final active = view == id;
      return Pressable(
        onTap: () => onView(id),
        radius: 6,
        color: active ? Colors.white : Colors.transparent,
        shadows: active
            ? const [BoxShadow(color: Color(0x101B3C53), blurRadius: 5, offset: Offset(0, 1))]
            : null,
        padding: EdgeInsets.symmetric(horizontal: narrow ? 7 : 10, vertical: narrow ? 6 : 7),
        child: Text(
          label,
          style: T(narrow ? 8 : 10,
              color: active ? C.ink : const Color(0xFF6B879A),
              w: active ? FontWeight.w700 : FontWeight.w400),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('month', 'Bulan'), const SizedBox(width: 2), seg('week', 'Minggu')],
      ),
    );
  }

  Widget _arrow(String ch, String label, int d) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () => onMove(d),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: narrow ? 17 : 25,
            height: 32,
            child: Center(child: Text(ch, style: T(narrow ? 21 : 24, color: C.muted, h: 1))),
          ),
        ),
      );
}

/// "Tambah kegiatan" button row under the heading.
class LegendRow extends StatelessWidget {
  const LegendRow({super.key, required this.narrow, required this.onAdd});
  final bool narrow;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: narrow ? 10 : 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Pressable(
          onTap: onAdd,
          color: C.blue,
          radius: 8,
          shadows: const [
            BoxShadow(color: Color(0x33234C6A), blurRadius: 12, offset: Offset(0, 4)),
          ],
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OIcon('plus', size: 14, color: Colors.white),
              SizedBox(width: narrow ? 3 : 8),
              Text('Tambah kegiatan',
                  style: T(narrow ? 8 : 11, color: Colors.white, w: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
