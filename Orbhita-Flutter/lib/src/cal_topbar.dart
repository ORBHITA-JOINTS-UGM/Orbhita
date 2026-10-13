import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// Sticky top bar with breadcrumb and the "•••" menu button.
class CalTopbar extends StatelessWidget {
  const CalTopbar({
    super.key,
    required this.narrow,
    required this.tight,
    required this.onSidebar,
    required this.onMenu,
  });

  final bool narrow;
  final bool tight;
  final VoidCallback onSidebar;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: narrow ? 56 : 61,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : (tight ? 22 : 29)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDF0F2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (narrow)
                  Semantics(
                    button: true,
                    label: 'Buka rincian jadwal',
                    child: Pressable(
                      onTap: onSidebar,
                      color: C.soft,
                      radius: 10,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(child: OIcon('calendar', color: C.blue)),
                      ),
                    ),
                  ),
                if (narrow) const SizedBox(width: 10),
                if (!tight) ...[
                  Text('Ruang belajarmu', style: T(11, color: C.muted)),
                  const SizedBox(width: 10),
                  const OIcon('chevron', size: 13, color: C.muted),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    'Kalender & asisten',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T(narrow ? 12 : 11, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Buka menu',
            excludeSemantics: true,
            onTap: onMenu,
            child: GestureDetector(
              onTap: onMenu,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 29,
                height: 29,
                child: Center(
                  child: Text('•••', style: T(14, color: C.muted, ls: 2, h: 1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
