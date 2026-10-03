import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/hydration_controller.dart';
import '../domain/models.dart';

Future<void> openPlanEditor(BuildContext context, {HydrationPlan? plan}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PlanEditor(plan: plan),
    );

class PlanEditor extends ConsumerStatefulWidget {
  const PlanEditor({super.key, this.plan});
  final HydrationPlan? plan;
  @override
  ConsumerState<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<PlanEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _goal;
  late int _start, _end, _interval;
  late bool _custom, _enabled;
  late List<int> _times;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p?.name ?? 'Yeni plan');
    _goal = TextEditingController(text: '${p?.goalMl ?? 2500}');
    _start = p?.startMinute ?? 420;
    _end = p?.endMinute ?? 1380;
    _interval = p?.intervalMinutes ?? 120;
    _times = p?.customMinutes.toList() ?? [];
    _custom = _times.isNotEmpty;
    _enabled = p?.remindersEnabled ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<int?> _pick(int minute) async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    return result == null ? null : result.hour * 60 + result.minute;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _error = null;
    });
    try {
      if (_custom && _times.isEmpty) {
        throw ArgumentError('En az bir saat ekleyin.');
      }
      final plan = HydrationPlan(
        id: widget.plan?.id,
        name: _name.text.trim(),
        goalMl: int.parse(_goal.text),
        startMinute: _start,
        endMinute: _end,
        intervalMinutes: _interval,
        customMinutes: _custom ? _times : [],
        remindersEnabled: _enabled,
      );
      setState(() => _saving = true);
      final saved = await ref.read(hydrationProvider.notifier).savePlan(plan);
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context);
      } else {
        setState(() => _error = 'Plan kaydedilemedi. Yeniden deneyin.');
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.plan == null
                    ? 'Kendi ritmini oluştur'
                    : 'Planını düzenle',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Hedefini ve sana uygun hatırlatma saatlerini seç.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Plan adı'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Bir ad yazın.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _goal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Günlük hedef',
                  suffixText: 'ml',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 250 || n > 10000
                      ? '250–10000 ml arasında bir sayı girin.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final value = await _pick(_start);
                        if (value != null && mounted) {
                          setState(() => _start = value);
                        }
                      },
                      child: Text('Başlangıç  ${clockLabel(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final value = await _pick(_end);
                        if (value != null && mounted) {
                          setState(() => _end = value);
                        }
                      },
                      child: Text('Bitiş  ${clockLabel(_end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Düzenli aralık')),
                  ButtonSegment(value: true, label: Text('Özel saatler')),
                ],
                selected: {_custom},
                onSelectionChanged: (v) => setState(() => _custom = v.single),
              ),
              const SizedBox(height: 16),
              if (!_custom)
                DropdownButtonFormField<int>(
                  initialValue: _interval,
                  decoration: const InputDecoration(
                    labelText: 'Hatırlatma sıklığı',
                  ),
                  items: [30, 60, 90, 120, 180, 240, 360, 720]
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text(
                            n % 60 == 0
                                ? '${n ~/ 60} saatte bir'
                                : '$n dakikada bir',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _interval = v);
                  },
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in _times)
                      InputChip(
                        label: Text(clockLabel(t)),
                        onDeleted: () => setState(() => _times.remove(t)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Saat ekle'),
                      onPressed: () async {
                        final t = await _pick(_start);
                        if (t != null && mounted) {
                          setState(() {
                            if (!_times.contains(t)) {
                              _times.add(t);
                              _times.sort();
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sesli hatırlatma'),
                subtitle: const Text('Seçtiğin saatlerde ses ve titreşim'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet ve kullan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
