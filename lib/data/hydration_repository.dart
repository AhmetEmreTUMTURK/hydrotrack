import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';

class HydrationRepository {
  HydrationRepository(this.db);
  final Database db;

  static Future<HydrationRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final driver = factory ?? databaseFactory;
    final location =
        path ?? p.join(await driver.getDatabasesPath(), 'hydrotrack.db');
    final db = await driver.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          goal_ml INTEGER NOT NULL CHECK(goal_ml BETWEEN 250 AND 10000),
          start_minute INTEGER NOT NULL,
          end_minute INTEGER NOT NULL,
          interval_minutes INTEGER NOT NULL,
          custom_minutes TEXT NOT NULL,
          reminders_enabled INTEGER NOT NULL DEFAULT 0)''');
          await db.execute('''CREATE TABLE water_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plan_id INTEGER NOT NULL REFERENCES plans(id),
          amount_ml INTEGER NOT NULL CHECK(amount_ml > 0),
          recorded_at INTEGER NOT NULL,
          day TEXT NOT NULL)''');
          await db.execute(
            'CREATE INDEX entries_day_id ON water_entries(day, id)',
          );
          await db.execute('''CREATE TABLE settings (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          active_plan_id INTEGER NOT NULL REFERENCES plans(id))''');
          final id = await db.insert(
            'plans',
            HydrationPlan(name: 'Günlük denge', goalMl: 2500).toRow(),
          );
          await db.insert('settings', {'id': 1, 'active_plan_id': id});
        },
      ),
    );
    return HydrationRepository(db);
  }

  Future<HydrationState> load(DateTime now) => db.transaction((txn) async {
    final plans = (await txn.query(
      'plans',
      orderBy: 'id',
    )).map(HydrationPlan.fromRow).toList();
    final settings = (await txn.query('settings', where: 'id = 1')).single;
    final entries = (await txn.query(
      'water_entries',
      where: 'day = ?',
      whereArgs: [dayKey(now)],
      orderBy: 'id DESC',
    )).map(WaterEntry.fromRow).toList();
    return HydrationState(
      plans: plans,
      activePlan: plans.singleWhere((p) => p.id == settings['active_plan_id']),
      entries: entries,
      day: dayKey(now),
    );
  });

  Future<void> addWater(int amountMl, DateTime now) async {
    if (amountMl < 25 || amountMl > 2000) {
      throw ArgumentError('Tek ekleme 25–2000 ml arasında olmalı.');
    }
    await db.transaction((txn) async {
      final settings = (await txn.query('settings', where: 'id = 1')).single;
      await txn.insert('water_entries', {
        'plan_id': settings['active_plan_id'],
        'amount_ml': amountMl,
        'recorded_at': now.millisecondsSinceEpoch,
        'day': dayKey(now),
      });
    });
  }

  /// Transaction + monotonic ID: even equal timestamps have a safe undo order.
  Future<bool> undoLast(DateTime now) => db.transaction((txn) async {
    final rows = await txn.query(
      'water_entries',
      columns: ['id'],
      where: 'day = ?',
      whereArgs: [dayKey(now)],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return false;
    await txn.delete(
      'water_entries',
      where: 'id = ?',
      whereArgs: [rows.single['id']],
    );
    return true;
  });

  Future<void> activatePlan(int id) => db.transaction((txn) async {
    final exists = await txn.query('plans', where: 'id = ?', whereArgs: [id]);
    if (exists.isEmpty) throw ArgumentError('Plan bulunamadı.');
    await txn.update('settings', {'active_plan_id': id}, where: 'id = 1');
  });

  Future<void> savePlan(HydrationPlan plan) => db.transaction((txn) async {
    int id;
    if (plan.id == null) {
      id = await txn.insert('plans', plan.toRow());
    } else {
      id = plan.id!;
      final changed = await txn.update(
        'plans',
        plan.toRow(),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed != 1) throw StateError('Plan bulunamadı.');
    }
    await txn.update('settings', {'active_plan_id': id}, where: 'id = 1');
  });

  Future<void> close() => db.close();
}
