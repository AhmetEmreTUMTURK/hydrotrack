import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/hydration_controller.dart';
import '../domain/models.dart';
import 'plan_editor.dart';
import 'theme.dart';
import 'water_gauge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  int _amount = 250;
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final data = ref.read(hydrationProvider).asData?.value;
      if (data != null && data.day != dayKey(ref.read(clockProvider)())) {
        unawaited(ref.read(hydrationProvider.notifier).refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(hydrationProvider.notifier).refresh());
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(hydrationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_rounded, color: aqua, size: 24),
            SizedBox(width: 8),
            Text(
              'hydrotrack',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Aktif planı düzenle',
            icon: const Icon(Icons.tune_rounded),
            onPressed: value.asData?.value == null || value.asData!.value.busy
                ? null
                : () => openPlanEditor(
                    context,
                    plan: value.asData!.value.activePlan,
                  ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 40, color: muted),
                  const SizedBox(height: 16),
                  const Text(
                    'Yerel kayıtlar açılamadı. Android veya iOS cihazda tekrar deneyin.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(repositoryProvider);
                      ref.invalidate(hydrationProvider);
                    },
                    child: const Text('Yeniden dene'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(hydrationProvider.notifier).refresh();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    if (data.notice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SurfaceCard(
                          padding: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data.notice!),
                              TextButton(
                                onPressed: data.busy
                                    ? null
                                    : () => ref
                                          .read(hydrationProvider.notifier)
                                          .refresh(),
                                child: const Text('Yeniden dene'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_tab == 0) ..._today(data),
                    if (_tab == 1) ..._plans(data),
                    if (_tab == 2) ..._history(data),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop_rounded),
            label: 'Bugün',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Planlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Geçmiş',
          ),
        ],
      ),
    );
  }

  List<Widget> _today(HydrationState data) {
    final remaining = math.max(0, data.activePlan.goalMl - data.totalMl);
    final now = ref.read(clockProvider)();
    return [
      Text(
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}  •  BUGÜN',
        style: const TextStyle(
          color: muted,
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Her yudum, iyi gelir.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 6),
      const Text(
        'Kendine küçük bir iyilik yap. Su iç.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 24),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_outlined, color: aqua, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.activePlan.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6F4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.goalReached ? 'Tamamlandı' : 'Günlük hedef',
                    style: const TextStyle(
                      color: aqua,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BUGÜN İÇİLEN',
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${data.totalMl}',
                          key: const Key('total-ml'),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                            height: 1.1,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '/ ${data.activePlan.goalMl} ml',
                        style: const TextStyle(color: muted, fontSize: 15),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '%${(data.progress * 100).round()}',
                        style: const TextStyle(
                          color: aqua,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'hedefine ulaştın',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 28),
                      Icon(
                        data.goalReached
                            ? Icons.check_circle_outline
                            : Icons.water_drop_outlined,
                        color: aqua,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.goalReached
                            ? 'Hedef tamam!'
                            : '$remaining ml kaldı',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                WaterGauge(
                  progress: data.progress,
                  goalMl: data.activePlan.goalMl,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'Ne kadar su içtin?',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final ml in [150, 250, 500])
            ChoiceChip(
              avatar: Icon(
                ml == 500
                    ? Icons.local_drink_outlined
                    : Icons.water_drop_outlined,
                size: 18,
              ),
              label: Text('$ml ml'),
              selected: _amount == ml,
              showCheckmark: false,
              onSelected: data.busy
                  ? null
                  : (_) => setState(() => _amount = ml),
            ),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('add-water'),
        onPressed: data.busy
            ? null
            : () => ref.read(hydrationProvider.notifier).addWater(_amount),
        icon: const Icon(Icons.add_rounded),
        label: Text(data.busy ? 'Kaydediliyor…' : 'Su içtim  ·  $_amount ml'),
      ),
      Center(
        child: TextButton.icon(
          key: const Key('undo-water'),
          onPressed: data.busy || data.entries.isEmpty
              ? null
              : () => ref.read(hydrationProvider.notifier).undo(),
          icon: const Icon(Icons.undo_rounded, size: 17),
          label: const Text('Son eklemeyi geri al'),
        ),
      ),
      const SizedBox(height: 8),
      SurfaceCard(
        padding: 16,
        child: Row(
          children: [
            Icon(
              data.activePlan.remindersEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: aqua,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.goalReached
                        ? 'Bugünün hedefi tamamlandı'
                        : data.activePlan.remindersEnabled
                        ? 'Hatırlatma planın'
                        : 'Kendi ritmini bul',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.goalReached
                        ? 'Bugün için kalan hatırlatmalar durdurulur.'
                        : data.activePlan.remindersEnabled
                        ? '${clockLabel(data.activePlan.startMinute)} – ${clockLabel(data.activePlan.endMinute)}'
                        : 'Planından sesli hatırlatmaları açabilirsin.',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Planı aç',
              onPressed: data.busy
                  ? null
                  : () => openPlanEditor(context, plan: data.activePlan),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _plans(HydrationState data) => [
    Text('Senin ritmin.', style: Theme.of(context).textTheme.headlineLarge),
    const SizedBox(height: 8),
    const Text(
      'Gününe uyan planı seç. İçtiğin su hep seninle.',
      style: TextStyle(color: muted),
    ),
    const SizedBox(height: 24),
    for (final plan in data.plans)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (plan.id == data.activePlan.id)
                    const Icon(Icons.check_circle, color: aqua),
                  IconButton(
                    tooltip: '${plan.name} düzenle',
                    onPressed: data.busy
                        ? null
                        : () => openPlanEditor(context, plan: plan),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
              Text(
                '${plan.goalMl} ml  ·  ${clockLabel(plan.startMinute)}–${clockLabel(plan.endMinute)}',
              ),
              const SizedBox(height: 8),
              Text(
                plan.customMinutes.isEmpty
                    ? '${plan.intervalMinutes} dakikada bir'
                    : plan.reminderMinutes.map(clockLabel).join(' · '),
                style: const TextStyle(color: muted),
              ),
              if (plan.id != data.activePlan.id)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    onPressed: data.busy
                        ? null
                        : () => ref
                              .read(hydrationProvider.notifier)
                              .activate(plan.id!),
                    child: const Text('Bu planı kullan'),
                  ),
                ),
            ],
          ),
        ),
      ),
    OutlinedButton.icon(
      onPressed: data.busy ? null : () => openPlanEditor(context),
      icon: const Icon(Icons.add),
      label: const Text('Yeni plan oluştur'),
    ),
    if (data.scheduledUntil != null)
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text(
          'Hatırlatmalar ${data.scheduledUntil!.day}.${data.scheduledUntil!.month} '
          '${clockLabel(data.scheduledUntil!.hour * 60 + data.scheduledUntil!.minute)} tarihine kadar hazır. '
          'Uygulamayı açtığında bu süre yenilenir.',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ),
  ];

  List<Widget> _history(HydrationState data) => [
    Text('Yudum yudum.', style: Theme.of(context).textTheme.headlineLarge),
    const SizedBox(height: 8),
    Text(
      'Bugün ${data.entries.length} kayıt · ${data.totalMl} ml',
      style: const TextStyle(color: muted),
    ),
    const SizedBox(height: 24),
    if (data.entries.isEmpty)
      const SurfaceCard(
        child: Column(
          children: [
            Icon(Icons.water_drop_outlined, size: 40, color: aqua),
            SizedBox(height: 12),
            Text('İlk yudum için güzel bir an.'),
            SizedBox(height: 4),
            Text(
              'Eklediğin su burada görünecek.',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      ),
    for (final entry in data.entries)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SurfaceCard(
          padding: 14,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEAF6F4),
              child: Icon(Icons.local_drink_outlined, color: aqua),
            ),
            title: Text(
              '+${entry.amountMl} ml',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              data.plans.firstWhere((p) => p.id == entry.planId).name,
            ),
            trailing: Text(
              clockLabel(entry.recordedAt.hour * 60 + entry.recordedAt.minute),
            ),
          ),
        ),
      ),
    if (data.entries.isNotEmpty)
      TextButton.icon(
        onPressed: data.busy
            ? null
            : () => ref.read(hydrationProvider.notifier).undo(),
        icon: const Icon(Icons.undo),
        label: const Text('Son eklemeyi geri al'),
      ),
  ];
}
