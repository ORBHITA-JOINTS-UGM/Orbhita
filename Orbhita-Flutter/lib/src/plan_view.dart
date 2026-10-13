import 'package:flutter/material.dart';

import 'flow_state.dart';
import 'plan.dart';
import 'theme.dart';

String _tj(String s) => s.replaceFirst('T', ' · ');

/// Plan screen content (`planContent` in the original).
class PlanView extends StatelessWidget {
  const PlanView({super.key, required this.state, required this.plan});

  final FlowState state;
  final Plan plan;

  static const _days = ['RABU, 14 OKTOBER', 'KAMIS, 15 OKTOBER', 'JUMAT, 16 OKTOBER'];

  Widget _card(List<Widget> kids) => SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: C.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
        ),
      );

  Widget _tag(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(t, style: T(9, color: C.muted, w: FontWeight.w700, ls: 1)),
      );

  Widget _summaryCell(String v, String l, bool border) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: border
                ? const Border(left: BorderSide(color: Color(0x30FFFFFF)))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v, style: T(29, color: Colors.white, h: 1.2, w: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(l, style: T(10, color: const Color(0xFFCBD9E1), h: 1.4)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vals = state.values;
    final kids = <Widget>[
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(16)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _summaryCell(fmt(plan.total), 'menit perkiraan', false),
              _summaryCell('${plan.sessionCount}', 'sesi', true),
            ],
          ),
        ),
      ),
      for (var d = 0; d < plan.days.length; d++)
        if (plan.days[d].isNotEmpty)
          _card([
            _tag('${_days[d]} · ${fmt(plan.used[d])} MENIT'),
            for (final x in plan.days[d])
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: C.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.start, style: T(12, w: FontWeight.w700)),
                        Text(x.end, style: T(10, color: C.muted)),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Langkah 0${x.step}', style: T(12, w: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${fmt(x.minutes)} menit · jeda sesuai preferensi',
                            style: T(10, color: C.muted, h: 1.65),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]),
      _card([
        _tag('TIGA WAKTU, TIGA FUNGSI'),
        Text('Deadline resmi', style: T(15, w: FontWeight.w700, h: 1.4, ls: -0.15)),
        const SizedBox(height: 6),
        Text(_tj(state.str('deadline')), style: T(12, color: C.muted, h: 1.65)),
        const SizedBox(height: 13),
        Text('Target pribadi', style: T(15, w: FontWeight.w700, h: 1.4, ls: -0.15)),
        const SizedBox(height: 6),
        Text(_tj(state.str('target')), style: T(12, color: C.muted, h: 1.65)),
        Text('Sesi adalah waktu pengerjaan; bukan deadline.',
            style: T(12, color: C.muted, h: 1.65)),
      ]),
    ];
    assert(vals.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < kids.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          kids[i],
        ],
      ],
    );
  }
}
