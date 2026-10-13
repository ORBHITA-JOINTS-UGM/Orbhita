import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'month_cell.dart';
import 'theme.dart';

/// Month grid (`.oc-month-grid`). Cells fill the available height.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required this.demo,
    required this.narrow,
    required this.compactChips,
    required this.onDay,
    required this.onEvent,
    required this.onMore,
  });

  final int year;
  final int month;
  final int day;
  final bool demo;
  final bool narrow;
  final bool compactChips;
  final ValueChanged<int> onDay;
  final void Function(int day, CalEvent e) onEvent;
  final ValueChanged<int> onMore;

  @override
  Widget build(BuildContext context) {
    final totalDays = DateTime(year, month + 2, 0).day;
    final offset = (DateTime(year, month + 1, 1).weekday - 1) % 7;
    final rows = ((totalDays + offset) / 7).ceil();
    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxHeight.isFinite ? box.maxHeight : 285.0;
      final h = avail < 285 ? 285.0 : avail;
      return SizedBox(
        height: h,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E7EB)),
            borderRadius: BorderRadius.circular(13),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E7EB))),
                ),
                child: Row(
                  children: [
                    for (final d in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: narrow ? 8 : 10),
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: T(narrow ? 8 : 9,
                                color: const Color(0xFF7A8F9E), w: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    for (var r = 0; r < rows; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < 7; c++) _cell(r, c, offset, totalDays, rows),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _cell(int r, int c, int offset, int totalDays, int rows) {
    final n = r * 7 + c - offset + 1;
    final valid = n > 0 && n <= totalDays;
    return Expanded(
      child: MonthCell(
        n: n,
        month: month,
        totalDays: totalDays,
        selected: valid && n == day,
        lastCol: c == 6,
        lastRow: r == rows - 1,
        daily: demo ? events.where((e) => e.day == n).toList() : const <CalEvent>[],
        narrow: narrow,
        compactChips: compactChips,
        onDay: onDay,
        onEvent: onEvent,
        onMore: onMore,
      ),
    );
  }
}
