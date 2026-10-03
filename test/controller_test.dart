import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_application/application/hydration_controller.dart';
import 'package:water_application/data/hydration_repository.dart';
import 'package:water_application/domain/models.dart';
import 'package:water_application/reminders/reminder_service.dart';

class RecordingReminders implements ReminderService {
  final snapshots = <HydrationState>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<ReminderResult> synchronize(
    HydrationState state,
    DateTime now, {
    bool requestPermission = false,
  }) async {
    snapshots.add(state);
    await gate?.future;
    if (fail) throw StateError('Notification failure');
    return const ReminderResult();
  }
}

void main() {
  late HydrationRepository repository;
  late ProviderContainer container;
  late RecordingReminders reminders;
  var now = DateTime(2026, 10, 3, 10);
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    repository = await HydrationRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    reminders = RecordingReminders();
    now = DateTime(2026, 10, 3, 10);
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWith((ref) async => repository),
        reminderServiceProvider.overrideWithValue(reminders),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    await container.read(hydrationProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await repository.close();
  });

  test(
    'add, target completion, undo and plan change reconcile notifications',
    () async {
      final controller = container.read(hydrationProvider.notifier);
      await controller.addWater(2000);
      await controller.addWater(500);
      expect(reminders.snapshots.last.goalReached, isTrue);
      await controller.undo();
      expect(reminders.snapshots.last.goalReached, isFalse);
      expect(reminders.snapshots.last.totalMl, 2000);
      await controller.savePlan(HydrationPlan(name: 'Yeni', goalMl: 1500));
      expect(reminders.snapshots.last.goalReached, isTrue);
    },
  );

  test(
    'notification failure preserves committed intake and shows retry notice',
    () async {
      reminders.fail = true;
      await container.read(hydrationProvider.notifier).addWater(250);
      final state = container.read(hydrationProvider).requireValue;
      expect(state.totalMl, 250);
      expect(state.notice, contains('hatırlatıcılar kurulamadı'));
      expect(state.busy, isFalse);
    },
  );

  test('rapid duplicate taps cannot overlap a mutation', () async {
    final controller = container.read(hydrationProvider.notifier);
    reminders.gate = Completer<void>();
    final first = controller.addWater(250);
    expect(await controller.addWater(250), isFalse);
    reminders.gate!.complete();
    await first;
    expect(container.read(hydrationProvider).requireValue.totalMl, 250);
  });

  test(
    'resume after midnight refreshes totals without erasing history',
    () async {
      final controller = container.read(hydrationProvider.notifier);
      await controller.addWater(250);
      now = DateTime(2026, 10, 4, 7);
      await controller.refresh();
      expect(container.read(hydrationProvider).requireValue.totalMl, 0);
      expect((await repository.load(DateTime(2026, 10, 3))).totalMl, 250);
    },
  );
}
