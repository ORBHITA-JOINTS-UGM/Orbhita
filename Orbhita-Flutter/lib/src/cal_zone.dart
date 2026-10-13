import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'cal_heading.dart';
import 'cal_month.dart';
import 'cal_week.dart';
import 'icons.dart';
import 'theme.dart';

/// Heading + legend + scrollable month/week grid + caption + mobile agenda.
class CalZone extends StatelessWidget {
  const CalZone({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required this.view,
    required this.narrow,
    required this.dayEvents,
    required this.onToday,
    required this.onView,
    required this.onMove,
    required this.onAdd,
    required this.onDay,
    required this.onEvent,
    required this.onMore,
    required this.onAgenda,
  });

  final int year;
  final int month;
  final int day;
  final String view;
  final bool narrow;
  final List<CalEvent> dayEvents;
  final VoidCallback onToday;
  final ValueChanged<String> onView;
  final ValueChanged<int> onMove;
  final VoidCallback onAdd;
  final ValueChanged<int> onDay;
  final void Function(int day, CalEvent e) onEvent;
  final ValueChanged<int> onMore;
  final VoidCallback onAgenda;

  bool get demo => year == 2026 && month == 9;

  @override
  Widget build(BuildContext context) {
    final totalDays = DateTime(year, month + 2, 0).day;
    final weekday = DateTime(year, month + 1, day).weekday;
    final weekStart = math.max(1, day - (weekday - 1));
    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 32, narrow ? 23 : 26, narrow ? 16 : 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalHeading(
            month: month,
            year: year,
            view: view,
            narrow: narrow,
            onToday: onToday,
            onView: onView,
            onMove: onMove,
          ),
          LegendRow(narrow: narrow, onAdd: onAdd),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final grid = view == 'month'
                  ? SizedBox(
                      height: math.max(box.maxHeight, 285),
                      child: MonthGrid(
                        year: year,
                        month: month,
                        day: day,
                        demo: demo,
                        narrow: narrow,
                        compactChips: narrow,
                        onDay: onDay,
                        onEvent: onEvent,
                        onMore: onMore,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: math.max(box.maxWidth, 580),
                        child: WeekGrid(
                          year: year,
                          month: month,
                          day: day,
                          weekStart: weekStart,
                          totalDays: totalDays,
                          demo: demo,
                          onDay: onDay,
                          onEvent: onEvent,
                        ),
                      ),
                    );
              return SingleChildScrollView(child: grid);
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pilih tanggal untuk melihat rincian jam kegiatan.',
              style: T(9, color: const Color(0xFF7B91A0)),
            ),
          ),
          if (narrow) _agenda(weekday),
          SizedBox(height: narrow ? 0 : 0),
        ],
      ),
    );
  }

  Widget _agenda(int weekday) {
    final name = dayNames[weekday % 7];
    final short = months[month].substring(0, 3);
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Pressable(
        onTap: onAgenda,
        color: const Color(0xFFF7F9FA),
        radius: 14,
        border: Border.all(color: const Color(0xFFDFE6EB)),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 43,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDBE4EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('$day', style: T(18, w: FontWeight.w700, h: 1.3)),
                  Text(short, style: T(8, h: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name, $day ${months[month]}', style: T(12, w: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      dayEvents.isNotEmpty
                          ? '${dayEvents.length} kegiatan · mulai ${dayEvents.first.start} WIB'
                          : 'Belum ada kegiatan',
                      style: T(10, color: const Color(0xFF6D889A)),
                    ),
                  ],
                ),
              ),
            ),
            const OIcon('chevron', size: 18, color: C.ink),
          ],
        ),
      ),
    );
  }
}
