import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/hydration_repository.dart';
import '../domain/models.dart';
import '../reminders/reminder_service.dart';

final repositoryProvider = FutureProvider<HydrationRepository>((ref) async {
  final repository = await HydrationRepository.open();
  ref.onDispose(repository.close);
  return repository;
});
final reminderServiceProvider = Provider<ReminderService>(
  (ref) => LocalReminderService(),
);
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final hydrationProvider =
    AsyncNotifierProvider<HydrationController, HydrationState>(
      HydrationController.new,
    );

class HydrationController extends AsyncNotifier<HydrationState> {
  late HydrationRepository _repository;
  bool _working = false;
  DateTime get _now => ref.read(clockProvider)();

  @override
  Future<HydrationState> build() async {
    _repository = await ref.watch(repositoryProvider.future);
    return _synchronize(await _repository.load(_now));
  }

  Future<HydrationState> _synchronize(
    HydrationState data, {
    bool requestPermission = false,
  }) async {
    try {
      final result = await ref
          .read(reminderServiceProvider)
          .synchronize(data, _now, requestPermission: requestPermission);
      return data.withStatus(
        notice: result.notice,
        scheduledUntil: result.lastScheduled,
      );
    } catch (_) {
      // A notification failure must never roll back a committed water entry.
      return data.withStatus(
        notice: 'Veriler kaydedildi; hatırlatıcılar kurulamadı. Yeniden dene.',
      );
    }
  }

  Future<bool> _mutate(
    Future<void> Function() operation, {
    bool requestPermission = false,
  }) async {
    final previous = state.asData?.value;
    if (_working || previous == null) return false;
    _working = true;
    state = AsyncData(
      previous.withStatus(
        busy: true,
        notice: previous.notice,
        scheduledUntil: previous.scheduledUntil,
      ),
    );
    try {
      await operation();
      final fresh = await _repository.load(_now);
      final updated = await _synchronize(
        fresh,
        requestPermission: requestPermission,
      );
      if (ref.mounted) state = AsyncData(updated);
      return true;
    } catch (_) {
      // Reload after failures: the write may already have committed.
      HydrationState recovered = previous;
      try {
        recovered = await _repository.load(_now);
      } catch (_) {
        /* Keep last snapshot. */
      }
      if (ref.mounted) {
        state = AsyncData(
          recovered.withStatus(
            notice:
                'İşlem tamamlanamadı. Güncel kayıtları kontrol edip yeniden deneyin.',
          ),
        );
      }
      return false;
    } finally {
      _working = false;
    }
  }

  Future<bool> addWater(int amount) =>
      _mutate(() => _repository.addWater(amount, _now));
  Future<bool> undo() => _mutate(() async {
    await _repository.undoLast(_now);
  });
  Future<bool> activate(int id) => _mutate(() => _repository.activatePlan(id));
  Future<bool> savePlan(HydrationPlan plan) => _mutate(
    () => _repository.savePlan(plan),
    requestPermission: plan.remindersEnabled,
  );
  Future<bool> refresh() => _mutate(() async {});
}
