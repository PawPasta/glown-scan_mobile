import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../premium/widgets/premium_required_view.dart';
import '../services/routine_api.dart';

class RoutinePage extends StatefulWidget {
  const RoutinePage({this.api, super.key});
  final RoutineApiContract? api;
  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  late final RoutineApiContract _api = widget.api ?? RoutineApi();
  late Future<_RoutineData> _data = _load();
  Future<_RoutineData> _load() async =>
      _RoutineData(await _api.getCurrent(), await _api.getToday());
  @override
  void dispose() {
    if (widget.api == null && _api is RoutineApi) (_api).close();
    super.dispose();
  }

  String _key() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  Future<void> _generate() async {
    try {
      await _api.createDraft(idempotencyKey: _key());
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _transition(SkinRoutine routine, String action) async {
    try {
      await _api.transition(routine.id, action);
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _toggle(RoutineToday today, String id) async {
    final next = {...today.completedStepIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    try {
      await _api.saveToday(date: today.date, completedStepIds: next.toList());
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _editRoutine(SkinRoutine routine) async {
    final changes = await showDialog<_RoutineDraft>(
      context: context,
      builder: (_) => _RoutineEditorDialog(routine: routine),
    );
    if (changes == null) return;
    try {
      await _api.updateRoutine(
        routineId: routine.id,
        title: changes.title,
        morningSteps: changes.morningSteps,
        eveningSteps: changes.eveningSteps,
      );
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showHistory() async {
    final end = DateTime.now().toUtc();
    final start = end.subtract(const Duration(days: 29));
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    try {
      final history = await _api.getHistory(from: date(start), to: date(end));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check-in history'),
          content: SizedBox(
            width: 400,
            child: history.items.isEmpty
                ? const Text('No check-ins in the last 30 days.')
                : ListView(
                    shrinkWrap: true,
                    children: history.items
                        .map(
                          (item) => ListTile(
                            title: Text(item.date),
                            subtitle: Text(
                              '${item.completedStepIds.length} steps completed · ${item.streakDays}-day streak',
                            ),
                            trailing: Text('${item.completionPercent}%'),
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RoutineData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        if (_isPremiumRequired(snapshot.error)) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: PremiumRequiredView(feature: 'your personalised routine'),
            ),
          );
        }
        return Center(
          child: FilledButton(
            onPressed: () => setState(() {
              _data = _load();
            }),
            child: const Text('Try again'),
          ),
        );
      }
      final data = snapshot.requireData;
      final routine = data.routine;
      if (routine == null) return _EmptyRoutine(onGenerate: _generate);
      final today = data.today;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(routine.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Status: ${routine.status.toLowerCase()}'),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _editRoutine(routine),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit routine'),
              ),
              OutlinedButton.icon(
                onPressed: _showHistory,
                icon: const Icon(Icons.history),
                label: const Text('Check-in history'),
              ),
            ],
          ),
          if (today != null) _ProgressCard(today),
          const SizedBox(height: 20),
          _Steps(
            title: 'Morning',
            steps: routine.morningSteps,
            today: today,
            onToggle: _toggle,
          ),
          const SizedBox(height: 20),
          _Steps(
            title: 'Evening',
            steps: routine.eveningSteps,
            today: today,
            onToggle: _toggle,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              if (routine.status == 'DRAFT' || routine.status == 'PAUSED')
                FilledButton(
                  onPressed: () => _transition(routine, 'activate'),
                  child: Text(
                    routine.status == 'DRAFT'
                        ? 'Activate routine'
                        : 'Resume routine',
                  ),
                ),
              if (routine.status == 'ACTIVE')
                OutlinedButton(
                  onPressed: () => _transition(routine, 'pause'),
                  child: const Text('Pause'),
                ),
              if (routine.status != 'COMPLETED')
                TextButton(
                  onPressed: () => _transition(routine, 'complete'),
                  child: const Text('Complete routine'),
                ),
            ],
          ),
        ],
      );
    },
  );

  bool _isPremiumRequired(Object? error) =>
      error is ApiException && error.code == 'PREMIUM_REQUIRED';
}

class _RoutineData {
  const _RoutineData(this.routine, this.today);
  final SkinRoutine? routine;
  final RoutineToday? today;
}

class _EmptyRoutine extends StatelessWidget {
  const _EmptyRoutine({required this.onGenerate});
  final VoidCallback onGenerate;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.spa_outlined, size: 52, color: AppTheme.deepRose),
          const SizedBox(height: 16),
          Text(
            'Build your routine',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a simple routine using your skin profile and latest analysis.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate my routine'),
          ),
        ],
      ),
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard(this.today);
  final RoutineToday today;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.sand,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${today.completionPercent}% complete · ${today.streakDays}-day streak',
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: today.completionPercent.clamp(0, 100) / 100,
        ),
      ],
    ),
  );
}

class _Steps extends StatelessWidget {
  const _Steps({
    required this.title,
    required this.steps,
    required this.today,
    required this.onToggle,
  });
  final String title;
  final List<RoutineStep> steps;
  final RoutineToday? today;
  final void Function(RoutineToday, String) onToggle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (steps.isEmpty)
        const Text('No steps planned.')
      else
        ...steps.map(
          (step) => Card(
            child: CheckboxListTile(
              value: today?.completedStepIds.contains(step.id) ?? false,
              onChanged: today == null
                  ? null
                  : (_) => onToggle(today!, step.id),
              title: Text(step.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.instruction),
                  if (step.product != null)
                    Text(
                      'Recommended: ${step.product!.name}${step.product!.brand == null ? '' : ' · ${step.product!.brand}'}',
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _RoutineDraft {
  const _RoutineDraft({
    required this.title,
    required this.morningSteps,
    required this.eveningSteps,
  });

  final String title;
  final List<RoutineStep> morningSteps;
  final List<RoutineStep> eveningSteps;
}

class _RoutineEditorDialog extends StatefulWidget {
  const _RoutineEditorDialog({required this.routine});

  final SkinRoutine routine;

  @override
  State<_RoutineEditorDialog> createState() => _RoutineEditorDialogState();
}

class _RoutineEditorDialogState extends State<_RoutineEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.routine.title,
  );
  late List<RoutineStep> _morning = [...widget.routine.morningSteps];
  late List<RoutineStep> _evening = [...widget.routine.eveningSteps];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<RoutineStep> _steps(String period) =>
      period == 'MORNING' ? _morning : _evening;

  void _replaceSteps(String period, List<RoutineStep> values) {
    setState(() {
      if (period == 'MORNING') {
        _morning = values;
      } else {
        _evening = values;
      }
    });
  }

  void _addStep(String period) {
    final steps = [..._steps(period)];
    steps.add(
      RoutineStep(
        id: '_draft_${DateTime.now().microsecondsSinceEpoch}',
        period: period,
        position: steps.length + 1,
        title: '',
        instruction: '',
        optional: false,
      ),
    );
    _replaceSteps(period, steps);
  }

  void _removeStep(String period, int index) {
    final steps = [..._steps(period)]..removeAt(index);
    _replaceSteps(period, [
      for (var i = 0; i < steps.length; i++)
        RoutineStep(
          id: steps[i].id,
          period: period,
          position: i + 1,
          title: steps[i].title,
          instruction: steps[i].instruction,
          optional: steps[i].optional,
          product: steps[i].product,
        ),
    ]);
  }

  Widget _stepFields(String period) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(period == 'MORNING' ? 'Morning steps' : 'Evening steps'),
      for (var index = 0; index < _steps(period).length; index++) ...[
        const SizedBox(height: 8),
        _RoutineStepEditor(
          key: ValueKey('routine-$period-$index-${_steps(period)[index].id}'),
          step: _steps(period)[index],
          onChanged: (step) {
            final steps = [..._steps(period)]..[index] = step;
            _replaceSteps(period, steps);
          },
          onRemove: () => _removeStep(period, index),
        ),
      ],
      TextButton.icon(
        onPressed: () => _addStep(period),
        icon: const Icon(Icons.add),
        label: const Text('Add step'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit routine'),
    content: SizedBox(
      width: 420,
      height: 520,
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Routine title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a routine title.'
                  : null,
            ),
            const SizedBox(height: 18),
            _stepFields('MORNING'),
            const SizedBox(height: 12),
            _stepFields('EVENING'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _RoutineDraft(
              title: _titleController.text.trim(),
              morningSteps: _morning,
              eveningSteps: _evening,
            ),
          );
        },
        child: const Text('Save changes'),
      ),
    ],
  );
}

class _RoutineStepEditor extends StatelessWidget {
  const _RoutineStepEditor({
    required this.step,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final RoutineStep step;
  final ValueChanged<RoutineStep> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextFormField(
            initialValue: step.title,
            decoration: const InputDecoration(labelText: 'Step title'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a step title.'
                : null,
            onChanged: (value) => onChanged(step.copyWith(title: value)),
          ),
          TextFormField(
            initialValue: step.instruction,
            decoration: const InputDecoration(labelText: 'Instruction'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an instruction.'
                : null,
            onChanged: (value) => onChanged(step.copyWith(instruction: value)),
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Optional'),
                  value: step.optional,
                  onChanged: (value) =>
                      onChanged(step.copyWith(optional: value)),
                ),
              ),
              IconButton(
                tooltip: 'Remove step',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
