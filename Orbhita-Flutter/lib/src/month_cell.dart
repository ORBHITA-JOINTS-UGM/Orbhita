import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'theme.dart';

/// One day cell of the month grid.
class MonthCell extends StatelessWidget {
  const MonthCell({
    super.key,
    required this.n,
    required this.month,
    required this.totalDays,
    required this.selected,
    required this.lastCol,
    required this.lastRow,
    required this.daily,
    required this.narrow,
    required this.compactChips,
    required this.onDay,
    required this.onEvent,
    required this.onMore,
  });

  final int n;
  final int month;
  final int totalDays;
  final bool selected;
  final bool lastCol;
  final bool lastRow;
  final List<CalEvent> daily;
  final bool narrow;
  final bool compactChips;
  final ValueChanged<int> onDay;
  final void Function(int day, CalEvent e) onEvent;
  final ValueChanged<int> onMore;

  bool get valid => n > 0 && n <= totalDays;

  @override
  Widget build(BuildContext context) {
    final size = narrow ? 20.0 : 23.0;
    return Container(
      padding: EdgeInsets.symmetric(vertical: narrow ? 5 : 8, horizontal: narrow ? 2 : 5),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFEEF3F6)
            : (!valid ? const Color(0xFFFCFCFC) : null),
        border: Border(
          right: lastCol ? BorderSide.none : const BorderSide(color: Color(0xFFE5EAED)),
          bottom: lastRow ? BorderSide.none : const BorderSide(color: Color(0xFFE5EAED)),
        ),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: valid ? '$n ${months[month]}' : 'Di luar bulan',
                  child: GestureDetector(
                    onTap: valid ? () => onDay(n) : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: size,
                      height: size,
                      margin: EdgeInsets.only(bottom: narrow ? 3 : 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? C.blue : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        valid ? '$n' : '',
                        style: T(narrow ? 9 : 10,
                            color: selected ? Colors.white : const Color(0xFF648095),
                            w: selected ? FontWeight.w700 : FontWeight.w400,
                            h: 1),
                      ),
                    ),
                  ),
                ),
              ),
              if (daily.isNotEmpty) _chip(daily.first),
              if (daily.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: GestureDetector(
                    onTap: () => onMore(n),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(
                        '+${daily.length - 1}',
                        style: T(narrow ? 6 : 9, color: const Color(0xFF7390A3)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(CalEvent e) {
    final col = evColors[e.type]!;
    return GestureDetector(
      onTap: () => onEvent(n, e),
      behavior: HitTestBehavior.opaque,
      child: LeftBar(
        bar: Color(col.bar),
        bg: Color(col.bg),
        padding: EdgeInsets.symmetric(horizontal: narrow ? 2 : 4, vertical: 3),
        child: Row(
          children: [
            if (!compactChips)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(e.start,
                    style: T(7, color: Color(col.fg), w: FontWeight.w700, h: 1.4)),
              ),
            Expanded(
              child: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T(narrow ? 6 : 8, color: Color(col.fg), h: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
