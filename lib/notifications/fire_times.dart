import 'dart:convert';

import 'notification_repeat_mode.dart';

/// A wall-clock time-of-day.
class Hm {
  const Hm(this.hour, this.minute);
  final int hour;
  final int minute;

  static Hm? parse(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return Hm(h, m);
  }
}

/// Pure computation of a config's future fire instants for a given [day].
///
/// Only times strictly after [now] are returned. Kept separate from any
/// platform notification plugin so it's directly unit-testable.
List<DateTime> computeFireTimes({
  required NotificationRepeatMode repeatMode,
  String? fixedTimesJson,
  String? windowStart,
  String? windowEnd,
  int? frequencyMinutes,
  required DateTime day,
  required DateTime now,
}) {
  final times = <DateTime>[];
  DateTime at(Hm hm) => DateTime(day.year, day.month, day.day, hm.hour, hm.minute);

  if (repeatMode == NotificationRepeatMode.fixedSchedule) {
    for (final t in _parseTimes(fixedTimesJson)) {
      final instant = at(t);
      if (instant.isAfter(now)) times.add(instant);
    }
  } else {
    final start = Hm.parse(windowStart) ?? const Hm(9, 0);
    final end = Hm.parse(windowEnd) ?? const Hm(21, 0);
    final freq = frequencyMinutes ?? 120;
    if (freq < 1) return times;
    var cursor = at(start);
    final endAt = at(end);
    var guard = 0;
    while (!cursor.isAfter(endAt) && guard < 500) {
      if (cursor.isAfter(now)) times.add(cursor);
      cursor = cursor.add(Duration(minutes: freq));
      guard++;
    }
  }
  return times;
}

List<Hm> _parseTimes(String? json) {
  if (json == null || json.isEmpty) return const [];
  final decoded = jsonDecode(json);
  if (decoded is! List) return const [];
  return decoded.map((e) => Hm.parse(e as String)).whereType<Hm>().toList();
}
