import 'dart:convert';

String dayKey(DateTime time) {
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String clockLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

class HydrationPlan {
  HydrationPlan({
    this.id,
    required this.name,
    required this.goalMl,
    this.startMinute = 420,
    this.endMinute = 1380,
    this.intervalMinutes = 120,
    List<int> customMinutes = const [],
    this.remindersEnabled = false,
  }) : customMinutes = List.unmodifiable(customMinutes) {
    if (name.trim().isEmpty || name.length > 40) {
      throw ArgumentError('Plan adı 1–40 karakter olmalı.');
    }
    if (goalMl < 250 || goalMl > 10000) {
      throw ArgumentError('Hedef 250–10000 ml arasında olmalı.');
    }
    if (startMinute < 0 || endMinute > 1439 || startMinute >= endMinute) {
      throw ArgumentError('Başlangıç, aynı günün bitiş saatinden önce olmalı.');
    }
    if (intervalMinutes < 30 || intervalMinutes > 720) {
      throw ArgumentError('Aralık 30–720 dakika olmalı.');
    }
    if (customMinutes.length > 24 ||
        customMinutes.toSet().length != customMinutes.length ||
        customMinutes.any((m) => m < startMinute || m > endMinute)) {
      throw ArgumentError('En fazla 24 farklı saat, seçilen aralıkta olmalı.');
    }
  }

  final int? id;
  final String name;
  final int goalMl;
  final int startMinute;
  final int endMinute;
  final int intervalMinutes;
  final List<int> customMinutes;
  final bool remindersEnabled;

  List<int> get reminderMinutes => customMinutes.isNotEmpty
      ? (customMinutes.toList()..sort())
      : [for (var m = startMinute; m <= endMinute; m += intervalMinutes) m];

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'name': name.trim(),
    'goal_ml': goalMl,
    'start_minute': startMinute,
    'end_minute': endMinute,
    'interval_minutes': intervalMinutes,
    'custom_minutes': jsonEncode(customMinutes),
    'reminders_enabled': remindersEnabled ? 1 : 0,
  };

  factory HydrationPlan.fromRow(Map<String, Object?> row) => HydrationPlan(
    id: row['id'] as int,
    name: row['name'] as String,
    goalMl: row['goal_ml'] as int,
    startMinute: row['start_minute'] as int,
    endMinute: row['end_minute'] as int,
    intervalMinutes: row['interval_minutes'] as int,
    customMinutes: (jsonDecode(row['custom_minutes'] as String) as List)
        .cast<int>(),
    remindersEnabled: row['reminders_enabled'] == 1,
  );
}

class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.planId,
    required this.amountMl,
    required this.recordedAt,
    required this.day,
  });
  final int id;
  final int planId;
  final int amountMl;
  final DateTime recordedAt;
  final String day;

  factory WaterEntry.fromRow(Map<String, Object?> row) => WaterEntry(
    id: row['id'] as int,
    planId: row['plan_id'] as int,
    amountMl: row['amount_ml'] as int,
    recordedAt: DateTime.fromMillisecondsSinceEpoch(row['recorded_at'] as int),
    day: row['day'] as String,
  );
}

class HydrationState {
  HydrationState({
    required List<HydrationPlan> plans,
    required this.activePlan,
    required List<WaterEntry> entries,
    required this.day,
    this.busy = false,
    this.notice,
    this.scheduledUntil,
  }) : plans = List.unmodifiable(plans),
       entries = List.unmodifiable(entries);
  final List<HydrationPlan> plans;
  final HydrationPlan activePlan;
  // Consumption belongs to the person/day. Switching plans never erases it.
  final List<WaterEntry> entries;
  final String day;
  final bool busy;
  final String? notice;
  final DateTime? scheduledUntil;
  int get totalMl => entries.fold(0, (sum, entry) => sum + entry.amountMl);
  double get progress => (totalMl / activePlan.goalMl).clamp(0.0, 1.0);
  bool get goalReached => totalMl >= activePlan.goalMl;

  HydrationState withStatus({
    bool busy = false,
    String? notice,
    DateTime? scheduledUntil,
  }) => HydrationState(
    plans: plans,
    activePlan: activePlan,
    entries: entries,
    day: day,
    busy: busy,
    notice: notice,
    scheduledUntil: scheduledUntil,
  );
}
