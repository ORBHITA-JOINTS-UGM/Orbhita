import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// Top-right dropdown menu opened by the "•••" button.
class ReviewMenu extends StatelessWidget {
  const ReviewMenu({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;

  static const items = [
    ['home', 'Dashboard Profil'],
    ['compose', 'Buat Tugas Baru'],
    ['settings', 'Pengaturan & Profil'],
    ['reminders', 'Pengingat & Notifikasi'],
    ['login', 'Keluar'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 240),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Color(0x261B3C53), blurRadius: 40, offset: Offset(0, 12)),
          BoxShadow(color: Color(0x0D1B3C53), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'MENU UTAMA',
                style: T(12, color: C.muted, w: FontWeight.w700, ls: 0.5),
              ),
            ),
            for (final it in items)
              Pressable(
                onTap: () => onOpen(it[0]),
                radius: 10,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(it[1], style: T(14))),
                    const SizedBox(width: 12),
                    const OIcon('chevron', size: 14, color: C.ink),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
