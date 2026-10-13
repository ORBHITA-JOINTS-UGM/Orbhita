import 'dart:math' as math;

/// JS-like `Number(x)`: empty string is 0, unparsable is NaN.
double numOf(dynamic v) {
  if (v == null) return double.nan;
  final s = v.toString().trim();
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? double.nan;
}

/// Prints whole numbers without a decimal point, NaN as "NaN".
String fmt(num n) {
  if (n is double) {
    if (n.isNaN) return 'NaN';
    if (n.isInfinite) return n.isNegative ? '-Infinity' : 'Infinity';
    if (n == n.truncateToDouble()) return n.toInt().toString();
  }
  return n.toString();
}

String _two(double n) => fmt(n).padLeft(2, '0');

double _mins(String t) {
  final h = t.length >= 2 ? numOf(t.substring(0, 2)) : double.nan;
  final m = t.length > 3 ? numOf(t.substring(3)) : double.nan;
  return h * 60 + m;
}

String addMinutes(String time, double n) {
  final parts = time.split(':').map(numOf).toList();
  final h = parts.isNotEmpty ? parts[0] : double.nan;
  final m = parts.length > 1 ? parts[1] : double.nan;
  final v = h * 60 + m + n;
  return '${_two((v / 60).floorToDouble())}:${_two(v % 60)}';
}

class PlanSession {
  PlanSession(this.step, this.start, this.end, this.minutes);
  final int step;
  final String start;
  final String end;
  final double minutes;
}

class Plan {
  Plan(this.days, this.used, this.unallocated, this.total);
  final List<List<PlanSession>> days;
  final List<double> used;
  final double unallocated;
  final double total;

  int get sessionCount => days.fold(0, (a, d) => a + d.length);
}

String _orDefault(dynamic v, String d) {
  final s = v?.toString() ?? '';
  return s.isEmpty ? d : s;
}

Plan examplePlan(Map<String, dynamic> values, String mode, bool done) {
  final lengths = <double>[
    done ? 0 : (mode == 'estimate' ? numOf(values['remaining']) : numOf(values['m1'])),
    numOf(values['m2']),
    numOf(values['m3']),
  ];
  final days = <List<PlanSession>>[[], [], []];
  final used = <double>[0, 0, 0];
  final startTime = _orDefault(values['studyStart'], '19:30');
  final clock = <String>[startTime, startTime, startTime];
  double unallocated = 0;

  final dailyRaw = numOf(values['daily']);
  final daily = math.max(0.0, (dailyRaw.isNaN || dailyRaw == 0) ? 120.0 : dailyRaw);

  final parts = _orDefault(values['session'], '25 / 5').split('/').map(numOf).toList();
  final durRaw = parts.isNotEmpty ? parts[0] : double.nan;
  final restRaw = parts.length > 1 ? parts[1] : double.nan;
  final session = math.max(1.0, (durRaw.isNaN || durRaw == 0) ? 25.0 : durRaw);
  final gap = math.max(0.0, (restRaw.isNaN || restRaw == 0) ? 5.0 : restRaw);

  for (var index = 0; index < lengths.length; index++) {
    var left = lengths[index];
    var d = index == 0
        ? 0
        : ((mode == 'calendar' || (mode == 'postpone' && index == 2)) ? 2 : 1);
    while (left > 0 && d < 3) {
      final end = _orDefault(values['studyEnd'], '22:00');
      final available = _mins(end) - _mins(clock[d]);
      final amount = math.min(left, math.min(session, math.min(daily - used[d], available)));
      if (amount <= 0) {
        d++;
        continue;
      }
      final finish = addMinutes(clock[d], amount);
      days[d].add(PlanSession(index + 1, clock[d], finish, amount));
      used[d] += amount;
      left -= amount;
      clock[d] = addMinutes(finish, gap);
    }
    unallocated += math.max(0.0, left);
  }
  return Plan(days, used, unallocated, lengths.fold(0.0, (a, b) => a + b));
}
