import 'package:flutter/material.dart';

import 'flow_state.dart';
import 'icons.dart';
import 'plan.dart';
import 'theme.dart';

const _light = Color(0xFFC9D7E1);

/// Greeting row with the avatar (`.orb-greeting`, compact sizes).
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.onProfile});
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1, bottom: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RABU, 14 OKTOBER 2026',
                    style: T(8, color: C.muted, w: FontWeight.w700, ls: 1.2)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text('Halo, mahasiswa.',
                      style: T(19, h: 1.3, ls: -0.7, w: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onProfile,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: C.sand, shape: BoxShape.circle),
              child: Text('A', style: T(12, w: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark "next session" card.
class NextCard extends StatelessWidget {
  const NextCard({super.key, required this.state, required this.go});
  final FlowState state;
  final void Function(String id) go;

  @override
  Widget build(BuildContext context) {
    final st = state;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(color: C.sand, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    st.planActive ? 'SESI BERIKUTNYA' : 'BELUM TERJADWAL',
                    style: T(8, color: _light, w: FontWeight.w700, ls: 1.3),
                  ),
                ],
              ),
              const OIcon('clock', color: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              st.done ? 'Susun analisis & bukti' : 'Baca instruksi & petakan temuan',
              style: T(19, color: Colors.white, h: 1.3, ls: -0.5, w: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 9),
          Text(st.str('taskTitle'), style: T(10, color: _light)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.only(top: 17),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x25FFFFFF))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st.planActive
                            ? (st.done ? 'Kamis · 19.30' : 'Hari ini · 19.30')
                            : 'Tinjau rencana dahulu',
                        style: T(13, color: Colors.white, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        st.done ? '25 menit · langkah 02' : '25 menit · langkah 01',
                        style: T(9, color: _light),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: () => go(st.planActive ? 'progress' : 'plan'),
                  color: C.sand,
                  radius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  child: Row(
                    children: [
                      Text(st.planActive ? 'Mulai' : 'Tinjau',
                          style: T(11, w: FontWeight.w700)),
                      const SizedBox(width: 5),
                      const OIcon('chevron', size: 16, color: C.ink),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two stat tiles.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.value, required this.label});
  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: C.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          OIcon(icon, color: C.muted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: T(22, h: 1.2, w: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(label, style: T(9, color: C.muted, h: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String remainingText(FlowState s) => fmt(s.remaining);
