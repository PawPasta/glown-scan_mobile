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
      if (mounted) setState(() => _data = _load());
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
      if (mounted) setState(() => _data = _load());
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
      if (mounted) setState(() => _data = _load());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
            onPressed: () => setState(() => _data = _load()),
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
              subtitle: Text(step.instruction),
            ),
          ),
        ),
    ],
  );
}
