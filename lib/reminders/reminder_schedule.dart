import 'package:timezone/timezone.dart' as tz;
import '../domain/models.dart';

/// Calendar construction preserves wall-clock hours across DST changes.
/// One-shot notifications let us omit today without disabling tomorrow.
List<tz.TZDateTime> upcomingReminders({
  required HydrationPlan plan,
  required tz.TZDateTime now,
  required bool todayComplete,
  int limit = 60,
}) {
  if (!plan.remindersEnabled) return [];
  final result = <tz.TZDateTime>[];
  for (var day = 0; day < 60 && result.length < limit; day++) {
    if (day == 0 && todayComplete) continue;
    for (final minute in plan.reminderMinutes) {
      final time = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + day,
        minute ~/ 60,
        minute % 60,
      );
      // Skip a nonexistent local hour during a DST jump, and duplicates.
      if (time.hour * 60 + time.minute != minute) continue;
      if (time.isAfter(now) && !result.contains(time)) result.add(time);
      if (result.length == limit) break;
    }
  }
  return result;
}
