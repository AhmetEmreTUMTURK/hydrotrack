import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../domain/models.dart';
import 'reminder_schedule.dart';

class ReminderResult {
  const ReminderResult({this.notice, this.lastScheduled});
  final String? notice;
  final DateTime? lastScheduled;
}

abstract interface class ReminderService {
  Future<ReminderResult> synchronize(
    HydrationState state,
    DateTime now, {
    bool requestPermission = false,
  });
}

class LocalReminderService implements ReminderService {
  LocalReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  static const _firstId = 41000;
  static const _count = 60; // Leaves headroom below iOS's 64 pending requests.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_water_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<ReminderResult> synchronize(
    HydrationState state,
    DateTime now, {
    bool requestPermission = false,
  }) async {
    if (!_supported) {
      return const ReminderResult(
        notice: 'Hatırlatıcılar Android ve iOS cihazlarda kullanılabilir.',
      );
    }
    await _initialize();
    // These IDs belong exclusively to HydroTrack reminders. Also clears any
    // delivered reminder when the goal is reached or reminders are disabled.
    for (var id = _firstId; id < _firstId + _count; id++) {
      await _plugin.cancel(id);
    }
    if (!state.activePlan.remindersEnabled) return const ReminderResult();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (requestPermission) {
      await android?.requestNotificationsPermission();
      await ios?.requestPermissions(alert: true, badge: false, sound: true);
      // A denied exact-alarm request falls back to inexact scheduling.
      await android?.requestExactAlarmsPermission();
    }
    final enabled = android != null
        ? await android.areNotificationsEnabled() ?? false
        : (await ios?.checkPermissions())?.isEnabled ?? false;
    if (!enabled) {
      return const ReminderResult(
        notice:
            'Bildirim izni kapalı. Cihaz ayarlarından HydroTrack bildirimlerini açın.',
      );
    }

    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    final exact =
        android == null ||
        await android.canScheduleExactNotifications() == true;
    final times = upcomingReminders(
      plan: state.activePlan,
      now: tz.TZDateTime.from(now, tz.local),
      todayComplete: state.goalReached,
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'hydration_alarm_v1',
        'Su hatırlatıcıları',
        channelDescription: 'Plan saatlerinde sesli ve titreşimli hatırlatma',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        ),
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 700, 250, 700, 250, 1000]),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    try {
      for (var i = 0; i < times.length; i++) {
        await _plugin.zonedSchedule(
          _firstId + i,
          'Bir bardak su zamanı 💧',
          '${state.activePlan.name} · Günlük hedefin ${state.activePlan.goalMl} ml',
          times[i],
          details,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'hydration',
        );
      }
    } catch (_) {
      // Do not leave a partially scheduled plan reported as fully configured.
      for (var id = _firstId; id < _firstId + _count; id++) {
        await _plugin.cancel(id);
      }
      rethrow;
    }
    return ReminderResult(
      lastScheduled: times.isEmpty ? null : times.last,
      notice: exact
          ? null
          : 'Kesin alarm izni kapalı; hatırlatmalar gecikebilir.',
    );
  }
}
