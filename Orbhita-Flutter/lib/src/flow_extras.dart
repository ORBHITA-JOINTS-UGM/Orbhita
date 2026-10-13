import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// AI avatar + intro bubble shown on the compose screen.
class ChatIntro extends StatelessWidget {
  const ChatIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Orbit(height: 17)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF0F3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(
                'Kirim instruksinya. Kita ubah jadi langkah yang bisa kamu mulai.',
                style: T(12, color: C.muted, h: 1.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Day / week segmented switch on the agenda screen, plus the week strip.
class AgendaSwitch extends StatelessWidget {
  const AgendaSwitch({super.key, required this.week, required this.onChanged});

  final bool week;
  final ValueChanged<bool> onChanged;

  Widget _seg(String label, bool active, VoidCallback onTap) => Expanded(
        child: Pressable(
          onTap: onTap,
          radius: 7,
          color: active ? Colors.white : Colors.transparent,
          shadows: active
              ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2))]
              : null,
          child: SizedBox(
            height: 34,
            child: Center(
              child: Text(label, style: T(11, color: active ? C.ink : C.muted)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const days = ['Sen 12', 'Sel 13', 'Rab 14', 'Kam 15', 'Jum 16'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EFF3),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              _seg('Hari', !week, () => onChanged(false)),
              const SizedBox(width: 5),
              _seg('Minggu', week, () => onChanged(true)),
            ],
          ),
        ),
        if (week) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Pressable(
                    onTap: () => onChanged(false),
                    radius: 8,
                    color: days[i] == 'Rab 14' ? C.blue : Colors.white,
                    border: Border.all(color: C.line),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                    child: Center(
                      child: Text(
                        days[i],
                        style: T(9, color: days[i] == 'Rab 14' ? Colors.white : C.muted),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Attached-source chip on the compose screen.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.onRemove});
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFF40614D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEE8),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const OIcon('file', size: 16, color: fg),
          const SizedBox(width: 7),
          Text('instruksi-audit.pdf', style: T(10, color: fg)),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Hapus lampiran',
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Text('×', style: T(18, color: fg, h: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
