import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// Mini brand (`.orb-mini-brand`): logo + "RBHITA".
class MiniBrand extends StatelessWidget {
  const MiniBrand({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Orbit(height: 12),
          const SizedBox(width: 7),
          Text('RBHITA', style: T(10, w: FontWeight.w700, ls: 2)),
        ],
      ),
    );
  }
}

/// Header of every non-landing screen.
class FlowHeader extends StatelessWidget {
  const FlowHeader({
    super.key,
    required this.isHome,
    required this.title,
    required this.subtitle,
    required this.back,
    required this.onBack,
    required this.onClose,
  });

  final bool isHome;
  final String title;
  final String subtitle;
  final String? back;
  final VoidCallback onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 18),
      child: isHome
          ? Align(alignment: Alignment.centerLeft, child: MiniBrand(onTap: onClose))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (back != null)
                        Semantics(
                          button: true,
                          label: 'Kembali',
                          child: InkResponse(
                            onTap: onBack,
                            radius: 20,
                            child: const SizedBox(
                              width: 32,
                              height: 32,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OIcon('arrow', color: C.ink),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 32, height: 32),
                      MiniBrand(onTap: onClose),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(title, style: T(23, h: 1.18, ls: -0.6, w: FontWeight.w700)),
                ),
                Text(subtitle, style: T(12, color: C.muted, h: 1.55)),
              ],
            ),
    );
  }
}

/// Bottom navigation (`.orb-nav`).
class FlowNav extends StatelessWidget {
  const FlowNav({super.key, required this.activeId, required this.current, required this.go});

  final String activeId;
  final String current;
  final void Function(String id) go;

  static const _items = [
    ['home', 'Hari ini', 'home'],
    ['agenda', 'Agenda', 'calendar'],
    ['compose', 'Tambah', 'plus'],
    ['settings', 'Atur', 'settings'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 71),
      padding: const EdgeInsets.fromLTRB(4, 7, 4, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(width: 32),
            _item(_items[i]),
          ],
        ],
      ),
    );
  }

  Widget _item(List<String> it) {
    final active = activeId == it[0] || current == it[0];
    final color = active ? C.blue : C.muted;
    return Pressable(
      onTap: () => go(it[0]),
      color: active ? C.soft : Colors.transparent,
      radius: 11,
      child: SizedBox(
        height: 48,
        width: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OIcon(it[2], color: color),
            const SizedBox(height: 3),
            Text(
              it[1],
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: T(9, color: color, w: active ? FontWeight.w700 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
