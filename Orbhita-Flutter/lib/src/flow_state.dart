import 'plan.dart';

/// Mutable state of one prototype flow (mirrors `fresh()` in the original).
class FlowState {
  FlowState({
    required this.values,
    required this.taskSaved,
    required this.planActive,
    required this.version,
    this.wa = false,
    this.done = false,
    this.mode = 'initial',
    this.attachment = false,
    this.working = false,
  });

  Map<String, dynamic> values;
  bool taskSaved;
  bool planActive;
  int version;
  bool wa;
  bool done;
  String mode;
  bool attachment;
  bool working;

  factory FlowState.fresh(String start, Map<String, dynamic> defaults) =>
      FlowState(
        values: Map<String, dynamic>.from(defaults),
        taskSaved: start == 'home',
        planActive: start == 'home',
        version: start == 'home' ? 1 : 0,
      );

  FlowState copy() => FlowState(
        values: Map<String, dynamic>.from(values),
        taskSaved: taskSaved,
        planActive: planActive,
        version: version,
        wa: wa,
        done: done,
        mode: mode,
        attachment: attachment,
        working: working,
      );

  String str(String key) => values[key]?.toString() ?? '';

  double get total => ['m1', 'm2', 'm3'].fold(0.0, (n, k) => n + numOf(values[k]));

  double get remaining {
    if (done) return numOf(values['m2']) + numOf(values['m3']);
    if (mode == 'estimate') {
      return numOf(values['remaining']) + numOf(values['m2']) + numOf(values['m3']);
    }
    return total;
  }
}

class ActResult {
  const ActResult.ok(this.state) : toast = null;
  const ActResult.fail(this.toast) : state = null;

  final FlowState? state;
  final String? toast;
}

/// JS `Date.parse` equivalent for the `datetime-local` strings used here.
double _parseDate(dynamic v) {
  final dt = DateTime.tryParse(v?.toString() ?? '');
  return dt == null ? double.nan : dt.millisecondsSinceEpoch.toDouble();
}

String? _validDates(FlowState s) {
  final d = _parseDate(s.values['deadline']);
  final t = _parseDate(s.values['target']);
  if (d.isNaN || t.isNaN) return 'Lengkapi deadline dan target terlebih dahulu.';
  if (t > d) return 'Target pribadi harus sebelum atau sama dengan deadline resmi.';
  return null;
}

/// Applies a button action: validation, state effects, and (by the caller)
/// navigation to `action['target']`.
ActResult applyAction(FlowState state, Map<String, dynamic> a, String current) {
  final next = state.copy();
  final effect = a['effect'] as String?;
  final label = (a['label'] ?? '') as String;
  final v = state.values;

  if (effect == 'process' && state.str('message').trim().isEmpty) {
    return const ActResult.fail('Isi instruksi atau pilih lampiran.');
  }
  if (effect == 'confirmTask' || effect == 'validateDraft') {
    final err = _validDates(state);
    if (err != null) return ActResult.fail(err);
    if (['m1', 'm2', 'm3'].any((k) => !(numOf(v[k]) > 0))) {
      return const ActResult.fail('Estimasi tiap langkah harus lebih dari nol.');
    }
  }
  if (effect == 'confirmTask') next.taskSaved = true;
  if (effect == 'confirmPlan') {
    if (!state.taskSaved) {
      return const ActResult.fail('Konfirmasi tugas lebih dahulu.');
    }
    next.planActive = true;
    next.version = 1;
    next.mode = 'initial';
  }
  if (effect == 'completeStep') {
    next.done = true;
    next.values['remaining'] = '0';
  }
  if (effect == 'saveRemaining') {
    final r = numOf(v['remaining']);
    if (r.isNaN || r.isInfinite || r < 0) {
      return const ActResult.fail('Estimasi sisa harus nol atau lebih.');
    }
    next.done = r == 0;
  }
  const modes = {
    'confirmReplan': 'postpone',
    'calendarReplan': 'calendar',
    'confirmProgress': 'progress',
    'confirmEstimate': 'estimate',
  };
  if (modes.containsKey(effect)) {
    next.planActive = true;
    next.version++;
    next.mode = modes[effect]!;
  }
  if (effect == 'validateActivity') {
    if (!(_parseDate(v['activityEnd']) > _parseDate(v['activityStart']))) {
      return const ActResult.fail('Waktu selesai harus setelah waktu mulai.');
    }
  }
  if (effect == 'verifyWA') {
    if (v['consent'] != true) {
      return const ActResult.fail('Setujui reminder WA sebelum verifikasi.');
    }
    next.wa = true;
  }
  if (effect == 'validateReminder' &&
      ['WhatsApp', 'Keduanya'].contains(v['channel']) &&
      (!state.wa || v['consent'] != true)) {
    return const ActResult.fail('Verifikasi nomor dan berikan persetujuan reminder WA.');
  }
  if (current == 'attachments' && label.contains('Gunakan')) next.attachment = true;
  if (current == 'attachments' && label.contains('Hapus')) next.attachment = false;
  if (current == 'transcript') {
    final t = next.str('transcript');
    next.values['message'] = t.isNotEmpty ? t : next.values['message'];
  }
  return ActResult.ok(next);
}
