import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'theme.dart';

const weekHourH = 42.0;

/// A positioned event block inside a week column.
class WeekEvent extends StatelessWidget {
  const WeekEvent({super.key, required this.event, required this.onTap});

  final CalEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final col = evColors[e.type]!;
    final top = (minuteOf(e.start) - 420) / 60 * weekHourH;
    final height = ((minuteOf(e.end) - minuteOf(e.start)) / 60 * weekHourH).clamp(24.0, 1e6);
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: LeftBar(
          bar: Color(col.bar),
          bg: Color(col.bg),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T(7, color: Color(col.fg).withValues(alpha: 0.8), w: FontWeight.w700, h: 1),
                ),
                const SizedBox(height: 1),
                Expanded(
                  child: Text(
                    e.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: T(8, color: Color(col.fg), w: FontWeight.w600, h: 1.15),
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
