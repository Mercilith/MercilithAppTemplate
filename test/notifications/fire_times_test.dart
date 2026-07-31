import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';

void main() {
  final day = DateTime(2026, 7, 20);

  group('fixedSchedule', () {
    test('returns only future times, in order', () {
      final now = DateTime(2026, 7, 20, 9, 30);
      final times = computeFireTimes(
        repeatMode: NotificationRepeatMode.fixedSchedule,
        fixedTimesJson: '["08:00","10:00","15:00"]',
        day: day,
        now: now,
      );
      expect(times, [
        DateTime(2026, 7, 20, 10, 0),
        DateTime(2026, 7, 20, 15, 0),
      ]);
    });

    test('empty when all times have passed', () {
      final now = DateTime(2026, 7, 20, 16, 0);
      final times = computeFireTimes(
        repeatMode: NotificationRepeatMode.fixedSchedule,
        fixedTimesJson: '["08:00","10:00","15:00"]',
        day: day,
        now: now,
      );
      expect(times, isEmpty);
    });
  });

  group('repeatUntilDone', () {
    test('generates the interval series within the window, future only', () {
      final now = DateTime(2026, 7, 20, 10, 30);
      final times = computeFireTimes(
        repeatMode: NotificationRepeatMode.repeatUntilDone,
        windowStart: '09:00',
        windowEnd: '15:00',
        frequencyMinutes: 120,
        day: day,
        now: now,
      );
      // Series: 9,11,13,15 — only 11,13,15 are after 10:30.
      expect(times, [
        DateTime(2026, 7, 20, 11, 0),
        DateTime(2026, 7, 20, 13, 0),
        DateTime(2026, 7, 20, 15, 0),
      ]);
    });

    test('includes the window end when it lands on the series', () {
      final now = DateTime(2026, 7, 20, 8, 0);
      final times = computeFireTimes(
        repeatMode: NotificationRepeatMode.repeatUntilDone,
        windowStart: '09:00',
        windowEnd: '12:00',
        frequencyMinutes: 60,
        day: day,
        now: now,
      );
      expect(times.last, DateTime(2026, 7, 20, 12, 0));
      expect(times.length, 4); // 9,10,11,12
    });

    test('defaults are used when window/frequency are null', () {
      final now = DateTime(2026, 7, 20, 0, 0);
      final times = computeFireTimes(
        repeatMode: NotificationRepeatMode.repeatUntilDone,
        day: day,
        now: now,
      );
      // Defaults: 09:00..21:00 every 120 min => 9,11,13,15,17,19,21 = 7.
      expect(times.length, 7);
      expect(times.first, DateTime(2026, 7, 20, 9, 0));
      expect(times.last, DateTime(2026, 7, 20, 21, 0));
    });
  });
}
