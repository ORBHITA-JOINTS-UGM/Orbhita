import 'package:flutter/material.dart';

import 'decor.dart';
import 'field.dart';
import 'flow_state.dart';
import 'icons.dart';
import 'plan.dart';
import 'theme.dart';
import 'widgets_basic.dart';

String _tj(String s) => s.replaceFirst('T', ' · ');

class BlockCtx {
  BlockCtx({
    required this.state,
    required this.current,
    required this.update,
    required this.go,
    required this.plan,
  });

  final FlowState state;
  final String current;
  final void Function(String key, dynamic value) update;
  final void Function(String id) go;
  final Plan plan;
}

/// Renders one block of a screen (equivalent of `block(b, i)`).
/// `notice` blocks intentionally render nothing, as in the original.
Widget buildBlock(Map<String, dynamic> b, int i, BlockCtx x) {
  final vals = x.state.values;
  switch (b['type']) {
    case 'hero':
      return const HeroBlock();
    case 'wave':
      return const WaveBlock();
    case 'success':
      return Container(
        height: 124,
        decoration: BoxDecoration(
          color: const Color(0xFFE6EFEA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: OIcon('check', size: 44, color: Color(0xFF3D765B))),
      );
    case 'progress':
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            const Spinner(),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Memahami instruksi · contoh proses', style: T(11, color: C.muted)),
            ),
          ],
        ),
      );
    case 'text':
      return Text(b['body'] as String, style: T(11, color: C.muted, h: 1.6));
    case 'check':
      final key = b['key'] as String;
      return OCheck(
        label: b['label'] as String,
        value: vals[key] == true,
        onChanged: (v) => x.update(key, v),
      );
    case 'select':
      final key = b['key'] as String;
      return OSelect(
        label: b['label'] as String,
        value: vals[key]?.toString() ?? '',
        options: (b['options'] as List).cast<String>(),
        onChanged: (v) => x.update(key, v),
      );
    case 'field':
      final key = b['key'] as String;
      return OField(
        label: b['label'] as String,
        kind: (b['kind'] ?? 'text') as String,
        value: vals[key]?.toString() ?? '',
        onChanged: (v) => x.update(key, v),
      );
    case 'heading':
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(b['title'] as String, style: T(16, w: FontWeight.w700)),
      );
    case 'card':
      return _card(b, i, x);
  }
  return const SizedBox.shrink();
}

Widget _card(Map<String, dynamic> b, int i, BlockCtx x) {
  final vals = x.state.values;
  final st = x.state;
  final cur = x.current;
  var title = (b['title'] ?? '') as String;
  var desc = (b['body'] ?? '') as String;
  var tag = (b['tag'] ?? '') as String;
  final target = b['target'] as String?;

  if (title == 'Laporan audit sistem informasi') title = st.str('taskTitle');
  if (RegExp(r'^0[123]  ').hasMatch(title)) {
    final n = int.parse(title.substring(1, 2));
    desc = (n == 1 && st.done)
        ? '0 menit · selesai'
        : '${st.str('m$n')} menit · ${n == 1 ? 'Estimasi awal, dapat dikoreksi' : 'Bergantung pada langkah 0${n - 1}'}';
    if (n == 1 && st.done) tag = 'SELESAI';
  }
  if (cur == 'task' && i == 0) {
    title = '${fmt(st.remaining)} menit tersisa';
    desc = '${st.done ? 'Langkah 01 selesai' : 'Belum mulai'} · '
        '${st.planActive ? 'rencana v${st.version} aktif' : 'jadwal belum aktif'}';
  }
  if (cur == 'task-saved' && i == 1) {
    desc = '3 langkah · ${fmt(st.total)} menit perkiraan\nDeadline ${_tj(st.str('deadline'))}';
  }
  if (cur == 'plan-active' && i == 1) {
    title = 'Tugas tersimpan · rencana v${st.version} aktif';
    desc = '${x.plan.sessionCount} sesi · ${fmt(x.plan.total)} menit';
  }
  if (cur == 'activity-review' && i == 0) {
    title = st.str('activityTitle');
    desc = 'Mulai ${_tj(st.str('activityStart'))}\nSelesai ${_tj(st.str('activityEnd'))}';
  }
  if (cur == 'activity-review' && title == 'Penyimpanan') {
    desc = vals['export'] == true ? 'ORBHITA + usulan ekspor Calendar' : 'ORBHITA saja';
  }
  if (cur == 'reminders' && title == 'Nomor WhatsApp penerima') {
    tag = st.wa ? 'TERVERIFIKASI · CONTOH' : 'WA BELUM AKTIF';
  }
  final sum = fmt(numOf(vals['remaining']) + numOf(vals['m2']) + numOf(vals['m3']));
  if (cur == 'estimate-review' && i == 0) {
    title = 'Sisa langkah 01: ${st.str('remaining')} menit';
    tag = 'TOTAL $sum MENIT';
  }
  if (cur == 'estimate-active' && i == 1) {
    title = '$sum menit tersisa';
    desc = 'Estimasi diperbarui; rencana telah dikonfirmasi.';
  }

  final content = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (tag.isNotEmpty || target != null)
        Row(
          children: [
            if (tag.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(tag, style: T(9, color: C.muted, w: FontWeight.w700, ls: 1)),
                ),
              )
            else
              const Spacer(),
            if (target != null) const OIcon('chevron', size: 17, color: C.muted),
          ],
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title, style: T(15, w: FontWeight.w700, h: 1.4, ls: -0.15)),
      ),
      Text(desc, style: T(12, color: C.muted, h: 1.65)),
    ],
  );

  return SizedBox(
    width: double.infinity,
    child: Pressable(
      onTap: target == null ? null : () => x.go(target),
      color: Colors.white,
      radius: 16,
      border: Border.all(color: C.line),
      padding: const EdgeInsets.all(16),
      child: content,
    ),
  );
}
