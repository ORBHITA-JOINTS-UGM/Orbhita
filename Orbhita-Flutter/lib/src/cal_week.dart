import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'theme.dart';
import 'week_event.dart';

const _hours = 16;
const _labelW = 44.0;

/// Week view (`.oc-week-grid`): 7 columns from `weekStart`, hours 07:00-22:00.
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required this.weekStart,
    required this.totalDays,
    required this.demo,
    required this.onDay,
    required this.onEvent,
  });

  final int year;
  final int month;
  final int day;
  final int weekStart;
  final int totalDays;
  final bool demo;
  final ValueChanged<int> onDay;
  final void Function(int day, CalEvent e) onEvent;

  @override
  Widget build(BuildContext context) {
    final cols = List<int>.generate(7, (i) => weekStart + i);
    return Container(
      constraints: const BoxConstraints(minWidth: 580),
      decoration: BoxDecoration(
        border: Border.all(color: C.calLine),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _header(cols),
          SizedBox(
            height: weekHourH * _hours,
            child: Row(
              children: [
                _labels(),
                for (final n in cols) Expanded(child: _column(n)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(List<int> cols) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFC),
        border: Border(bottom: BorderSide(color: C.calLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _labelW,
            child: Center(child: Text('WIB', style: T(8, color: const Color(0xFF8AA0AE)))),
          ),
          for (final n in cols)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (n <= totalDays) onDay(n);
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      n <= totalDays
                          ? dayNames[DateTime(year, month + 1, n).weekday % 7].substring(0, 3)
                          : '',
                      style: T(8, color: const Color(0xFF8197A7)),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: n == day ? C.blue : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        n <= totalDays ? '$n' : '',
                        style: T(12,
                            color: n == day ? Colors.white : const Color(0xFF8197A7),
                            w: FontWeight.w700,
                            h: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _labels() {
    return Container(
      width: _labelW,
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          for (var i = 0; i < _hours; i++)
            SizedBox(
              height: weekHourH,
              child: Transform.translate(
                offset: const Offset(0, -5),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      '${(i + 7).toString().padLeft(2, '0')}:00',
                      style: T(8, color: const Color(0xFF8CA1AF)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _column(int n) {
    final evs = demo ? events.where((e) => e.day == n).toList() : <CalEvent>[];
    return Container(
      decoration: BoxDecoration(
        color: n == day ? const Color(0xFFF6F9FB) : Colors.white,
        border: const Border(left: BorderSide(color: Color(0xFFE7ECEF))),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              for (var i = 0; i < _hours; i++)
                Container(
                  height: weekHourH,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFEDF0F2))),
                  ),
                ),
            ],
          ),
          for (final e in evs) WeekEvent(event: e, onTap: () => onEvent(n, e)),
        ],
      ),
    );
  }
}
