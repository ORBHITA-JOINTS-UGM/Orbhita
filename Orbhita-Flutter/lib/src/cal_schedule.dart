import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'icons.dart';
import 'theme.dart';

/// Sidebar list of the selected day's events (or the empty state).
class SideSchedule extends StatelessWidget {
  const SideSchedule({
    super.key,
    required this.dayEvents,
    required this.onOpen,
    required this.onDetail,
  });

  final List<CalEvent> dayEvents;
  final ValueChanged<String> onOpen;
  final ValueChanged<CalEvent> onDetail;

  @override
  Widget build(BuildContext context) {
    if (dayEvents.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 30, 12, 30),
          child: Column(
            children: [
              const OIcon('calendar', size: 28, color: Color(0xFFA4BBCA)),
              const SizedBox(height: 14),
              Text(
                'Ruang untuk kegiatanmu.',
                textAlign: TextAlign.center,
                style: T(13, color: const Color(0xFFE5EDF2), w: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                'Tambah kegiatan manual atau hubungkan kalender pilihanmu.',
                textAlign: TextAlign.center,
                style: T(11, color: const Color(0xFFA4BBCA), h: 1.8),
              ),
              const SizedBox(height: 16),
              Pressable(
                onTap: () => onOpen('activity'),
                color: const Color(0x0BFFFFFF),
                radius: 8,
                border: Border.all(color: const Color(0x2BFFFFFF)),
                padding: const EdgeInsets.all(10),
                child: Text('Tambah kegiatan', style: T(11, color: const Color(0xFFE7EDF1))),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [for (final e in dayEvents) _event(e)],
    );
  }

  Widget _event(CalEvent e) {
    final bar = switch (e.type) {
      'manual' => const Color(0xFFD2C1B6),
      'session' => const Color(0xFFACD2B8),
      _ => const Color(0xFF7498B2),
    };
    return Pressable(
      onTap: () => onDetail(e),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x13FFFFFF))),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.start,
                          style: T(11, color: const Color(0xFFE4EAF0), w: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(e.end, style: T(10, color: const Color(0xFF90ABBD))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: bar, width: 2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(typeLabel[e.type]!,
                          style: T(8, color: const Color(0xFFA8C3D3), ls: 0.2)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(e.title,
                            style: T(12, color: Colors.white, w: FontWeight.w700)),
                      ),
                      Text(e.detail, style: T(9, color: const Color(0xFFA6BBCA), h: 1.6)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
