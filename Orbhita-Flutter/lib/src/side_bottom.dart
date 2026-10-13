import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// Bottom links of the sidebar (Google Calendar + profile).
class SideBottom extends StatelessWidget {
  const SideBottom({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;

  Widget _row(Widget lead, String t, String sub, Widget trail, String route) => Pressable(
        onTap: () => onOpen(route),
        radius: 8,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: Row(
          children: [
            lead,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: T(11, color: const Color(0xFFE0E8EF))),
                  const SizedBox(height: 3),
                  Text(sub, style: T(9, color: const Color(0xFFA9BFCE))),
                ],
              ),
            ),
            trail,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFE0E8EF);
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Column(
        children: [
          _row(
            const OIcon('cloud', size: 17, color: light),
            'Google Calendar',
            'Data contoh · belum terhubung',
            const OIcon('chevron', size: 15, color: light),
            'calendar',
          ),
          const SizedBox(height: 7),
          _row(
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: C.sand, shape: BoxShape.circle),
              child: Text('A', style: T(12, w: FontWeight.w700)),
            ),
            'Mahasiswa',
            'Profil & preferensi',
            const OIcon('settings', size: 17, color: light),
            'profile',
          ),
        ],
      ),
    );
  }
}
