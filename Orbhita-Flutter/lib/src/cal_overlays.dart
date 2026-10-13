import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'icons.dart';
import 'theme.dart';

/// Full-screen event detail (`role="dialog"` in the original).
class EventDetail extends StatelessWidget {
  const EventDetail({
    super.key,
    required this.event,
    required this.dateLine,
    required this.onClose,
    required this.onOpen,
  });

  final CalEvent event;
  final String dateLine;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final (badgeBg, badgeFg) = switch (e.type) {
      'manual' => (const Color(0xFFF2E9E2), const Color(0xFF896749)),
      'session' => (const Color(0xFFE7F0E9), const Color(0xFF4D775C)),
      _ => (const Color(0xFFE8F0F5), const Color(0xFF507A96)),
    };
    final google = e.type == 'google';
    const sub = Color(0xFF6C879A);
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: 'Detail kegiatan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(typeLabel[e.type]!, style: T(9, color: badgeFg, ls: 0.4)),
                      ),
                      Semantics(
                        button: true,
                        label: 'Tutup detail kegiatan',
                        child: GestureDetector(
                          onTap: onClose,
                          behavior: HitTestBehavior.opaque,
                          child: Text('×', style: T(24, color: const Color(0xFF668298))),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 15, bottom: 12),
                  child: Text(e.title, style: T(23, h: 1.3, ls: -0.5, w: FontWeight.w700)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(dateLine, style: T(12, color: sub)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(e.detail, style: T(12, color: sub)),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 13),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    google
                        ? 'Acara dari luar ORBHITA hanya dibaca. Kelola perubahan di Google Calendar.'
                        : 'Data contoh. Perubahan dan jadwal baru tetap perlu ditinjau serta dikonfirmasi.',
                    style: T(11, color: const Color(0xFF52738B), h: 1.7),
                  ),
                ),
                if (!google)
                  Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Pressable(
                      onTap: onOpen,
                      color: C.blue,
                      radius: 10,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            e.type == 'session' ? 'Lihat langkah & progres' : 'Tinjau kegiatan',
                            style: T(12, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const OIcon('chevron', size: 17, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
