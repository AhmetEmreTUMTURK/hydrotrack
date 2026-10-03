import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_application/data/hydration_repository.dart';
import 'package:water_application/domain/models.dart';

void main() {
  late HydrationRepository repository;
  final today = DateTime(2026, 10, 3, 10);
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    repository = await HydrationRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => repository.close());

  test('undo removes last insertion even when timestamps match', () async {
    await repository.addWater(250, today);
    await repository.addWater(500, today);
    expect((await repository.load(today)).totalMl, 750);
    expect(await repository.undoLast(today), isTrue);
    expect((await repository.load(today)).totalMl, 250);
    await repository.undoLast(today);
    expect(await repository.undoLast(today), isFalse);
    expect((await repository.load(today)).totalMl, 0);
  });

  test('switching plans keeps consumption and updates target', () async {
    await repository.addWater(500, today);
    await repository.savePlan(
      HydrationPlan(
        name: 'Ofis',
        goalMl: 2000,
        customMinutes: [540, 720, 1080],
        remindersEnabled: true,
      ),
    );
    final data = await repository.load(today);
    expect(data.totalMl, 500);
    expect(data.activePlan.name, 'Ofis');
    expect(data.activePlan.customMinutes, [540, 720, 1080]);
    expect(data.entries.single.planId, data.plans.first.id);
    await repository.activatePlan(data.plans.first.id!);
    expect((await repository.load(today)).activePlan.name, 'Günlük denge');
  });

  test('midnight isolates totals and undo from previous day', () async {
    await repository.addWater(250, DateTime(2026, 10, 2, 23, 59));
    expect((await repository.load(today)).totalMl, 0);
    expect(await repository.undoLast(today), isFalse);
    expect((await repository.load(DateTime(2026, 10, 2))).totalMl, 250);
  });

  test('goal may be exceeded without losing actual intake', () async {
    await repository.addWater(2000, today);
    await repository.addWater(1000, today);
    final data = await repository.load(today);
    expect(data.totalMl, 3000);
    expect(data.progress, 1);
    expect(data.goalReached, isTrue);
    await repository.undoLast(today);
    expect((await repository.load(today)).goalReached, isFalse);
  });

  test('invalid input is rejected without changing stored state', () async {
    await expectLater(repository.addWater(-250, today), throwsArgumentError);
    await expectLater(repository.activatePlan(999), throwsArgumentError);
    expect((await repository.load(today)).totalMl, 0);
    expect(() => HydrationPlan(name: '', goalMl: 0), throwsArgumentError);
    expect(
      () => HydrationPlan(name: 'Test', goalMl: 2500, customMinutes: [60]),
      throwsArgumentError,
    );
    expect(
      () => HydrationPlan(
        name: 'Test',
        goalMl: 2500,
        startMinute: 1380,
        endMinute: 420,
      ),
      throwsArgumentError,
    );
  });

  test(
    'plans, active selection and entries survive closing database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hydrotrack-test-',
      );
      final path = '${directory.path}/persist.db';
      var disk = await HydrationRepository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      try {
        await disk.savePlan(HydrationPlan(name: 'Kalıcı plan', goalMl: 3000));
        await disk.addWater(500, today);
        await disk.close();
        disk = await HydrationRepository.open(
          factory: databaseFactoryFfi,
          path: path,
        );
        final data = await disk.load(today);
        expect(data.activePlan.name, 'Kalıcı plan');
        expect(data.totalMl, 500);
        await disk.undoLast(today);
        expect((await disk.load(today)).totalMl, 0);
      } finally {
        await disk.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
