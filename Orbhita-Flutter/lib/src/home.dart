import 'package:flutter/material.dart';

import 'flow_state.dart';
import 'home_cards.dart';
import 'icons.dart';
import 'plan.dart';
import 'theme.dart';

/// Home dashboard of the flow (`home` constant in the original).
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.state, required this.plan, required this.go});

  final FlowState state;
  final Plan plan;
  final void Function(String id) go;

  @override
  Widget build(BuildContext context) {
    final st = state;
    final sessions = st.planActive ? plan.sessionCount : 0;
    final children = <Widget>[
      Greeting(onProfile: () => go('profile')),
      NextCard(state: st, go: go),
      Row(
        children: [
          Expanded(child: StatTile(icon: 'file', value: remainingText(st), label: 'menit tersisa')),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(icon: 'calendar', value: '$sessions', label: 'sesi direncanakan'),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tugasmu', style: T(16, w: FontWeight.w700)),
            Text('1 tugas aktif', style: T(10, color: C.muted)),
          ],
        ),
      ),
      _taskCard(),
      DashedBorder(
        color: const Color(0xFFA5B5C1),
        child: Pressable(
          onTap: () => go('compose'),
          radius: 12,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const OIcon('plus', color: C.blue),
                const SizedBox(width: 8),
                Text('Tambah tugas baru', style: T(12, color: C.blue, w: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            const OIcon('cloud', size: 14, color: C.muted),
            const SizedBox(width: 6),
            Text('Calendar belum tersinkron', style: T(8, color: C.muted)),
            const Spacer(),
            GestureDetector(
              onTap: () => go('offline'),
              child: Text('Detail', style: T(9, color: C.blue, deco: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }

  Widget _taskCard() {
    final st = state;
    return Pressable(
      onTap: () => go('task'),
      color: Colors.white,
      radius: 16,
      border: Border.all(color: C.line),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 36,
            decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(9)),
            child: const Center(child: OIcon('file', color: C.muted)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    'AUDIT SISTEM INFORMASI',
                    style: T(7, color: C.muted, w: FontWeight.w700, ls: 0.8),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(st.str('taskTitle'), style: T(13, w: FontWeight.w700)),
                ),
                Text('Deadline 16 Okt · 23.59', style: T(10, color: C.muted)),
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 4,
                      color: const Color(0xFFE6ECEF),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: st.done ? 0.3 : 0.08,
                        child: Container(color: C.muted),
                      ),
                    ),
                  ),
                ),
                Text(
                  st.done
                      ? '1 dari 3 langkah selesai'
                      : (st.working ? 'Sedang dikerjakan' : 'Belum mulai'),
                  style: T(9, color: C.muted),
                ),
              ],
            ),
          ),
          const OIcon('chevron', size: 16, color: C.ink),
        ],
      ),
    );
  }
}
