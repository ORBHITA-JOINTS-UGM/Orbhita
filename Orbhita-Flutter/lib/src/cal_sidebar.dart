import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'cal_schedule.dart';
import 'icons.dart';
import 'side_bottom.dart';
import 'theme.dart';

/// Dark "Jadwalmu" sidebar (a drawer on narrow screens).
class CalSidebar extends StatelessWidget {
  const CalSidebar({
    super.key,
    required this.width,
    required this.showClose,
    required this.day,
    required this.month,
    required this.totalDays,
    required this.weekdayOfDay,
    required this.dayEvents,
    required this.onClose,
    required this.onDay,
    required this.onOpen,
    required this.onDetail,
  });

  final double width;
  final bool showClose;
  final int day;
  final int month;
  final int totalDays;
  final int weekdayOfDay;
  final List<CalEvent> dayEvents;
  final VoidCallback onClose;
  final ValueChanged<int> onDay;
  final ValueChanged<String> onOpen;
  final ValueChanged<CalEvent> onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(18, 25, 18, 14),
      decoration: const BoxDecoration(
        color: C.ink,
        border: Border(right: BorderSide(color: Color(0xFF153246))),
        boxShadow: [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Orbit(height: 14.4),
                    const SizedBox(width: 10),
                    Text('ORBHITA',
                        style: T(20, color: const Color(0xFFF6F4F2), w: FontWeight.w700, ls: 3)),
                  ],
                ),
                if (showClose)
                  Semantics(
                    button: true,
                    label: 'Tutup jadwal',
                    child: GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: Text('×', style: T(24, color: Colors.white, h: 1.2)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _title(),
          const SizedBox(height: 16),
          _dayChoice(),
          const SizedBox(height: 16),
          Expanded(
            child: SideSchedule(dayEvents: dayEvents, onOpen: onOpen, onDetail: onDetail),
          ),
          const SizedBox(height: 16),
          SideBottom(onOpen: onOpen),
        ],
      ),
    );
  }

  Widget _title() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 9, 6, 0),
      child: Row(
        children: [
          const OIcon('calendar', color: Color(0xFFE0E8ED)),
          const SizedBox(width: 9),
          Text('Jadwalmu',
              style: T(13, color: const Color(0xFFE0E8ED), w: FontWeight.w700)),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Tambah kegiatan',
            child: Pressable(
              onTap: () => onOpen('activity'),
              color: const Color(0x13FFFFFF),
              radius: 8,
              border: Border.all(color: const Color(0x18FFFFFF)),
              child: const SizedBox(
                width: 27,
                height: 27,
                child: Center(child: OIcon('plus', size: 18, color: Color(0xFFD9E4EB))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(String ch, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(ch, style: T(22, color: const Color(0xFFD4E0E8), h: 1.2)),
          ),
        ),
      );

  Widget _dayChoice() {
    final count = dayEvents.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x20FFFFFF)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          _arrow('‹', 'Hari sebelumnya', () {
            if (day > 1) onDay(day - 1);
          }),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${dayNames[weekdayOfDay]}, $day ${months[month].substring(0, 3)}',
                  textAlign: TextAlign.center,
                  style: T(13, color: const Color(0xFFF6F4F2), w: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  count > 0 ? '$count kegiatan · Asia/Jakarta' : 'Belum ada kegiatan',
                  textAlign: TextAlign.center,
                  style: T(9, color: const Color(0xFFB6C9D6)),
                ),
              ],
            ),
          ),
          _arrow('›', 'Hari berikutnya', () {
            if (day < totalDays) onDay(day + 1);
          }),
        ],
      ),
    );
  }
}
