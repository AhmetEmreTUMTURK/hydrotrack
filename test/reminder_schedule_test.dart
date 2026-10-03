import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'package:water_application/domain/models.dart';
import 'package:water_application/reminders/reminder_schedule.dart';

void main() {
  setUpAll(data.initializeTimeZones);
  HydrationPlan plan({List<int> times = const []}) => HydrationPlan(
    name: 'Test',
    goalMl: 2500,
    customMinutes: times,
    remindersEnabled: true,
  );

  test('window is inclusive, past reminders omitted, queue stays below 64', () {
    final times = upcomingReminders(
      plan: plan(),
      now: tz.TZDateTime(tz.getLocation('Europe/Istanbul'), 2026, 10, 3, 10),
      todayComplete: false,
    );
    expect(times.length, 60);
    expect(times.first.hour, 11);
    expect(times.every((t) => t.hour >= 7 && t.hour <= 23), isTrue);
    expect(times.toSet().length, times.length);
  });

  test(
    'completed target suppresses today, tomorrow is retained, undo restores',
    () {
      final now = tz.TZDateTime(tz.UTC, 2026, 10, 3, 10);
      final completed = upcomingReminders(
        plan: plan(),
        now: now,
        todayComplete: true,
      );
      expect(completed.first.day, 4);
      expect(completed.first.hour, 7);
      final undone = upcomingReminders(
        plan: plan(),
        now: now,
        todayComplete: false,
      );
      expect(undone.first.day, 3);
      expect(undone.first.hour, 11);
    },
  );

  test('custom slots are sorted and never emit at unselected times', () {
    final times = upcomingReminders(
      plan: plan(times: [900, 540, 720]),
      now: tz.TZDateTime(tz.UTC, 2026, 10, 3, 8),
      todayComplete: false,
    );
    expect(times.take(3).map((t) => t.hour), [9, 12, 15]);
  });

  test('DST transition preserves selected local hour', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final times = upcomingReminders(
      plan: plan(times: [540]),
      now: tz.TZDateTime(berlin, 2026, 10, 24, 8),
      todayComplete: false,
    );
    expect(times[0].hour, 9);
    expect(times[1].hour, 9);
    expect(times[1].difference(times[0]).inHours, 25);
  });

  test('disabled reminders produce no alarms', () {
    expect(
      upcomingReminders(
        plan: HydrationPlan(name: 'Kapalı', goalMl: 2500),
        now: tz.TZDateTime.now(tz.UTC),
        todayComplete: false,
      ),
      isEmpty,
    );
  });
}
