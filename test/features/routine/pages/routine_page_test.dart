import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/features/routine/pages/routine_page.dart';
import 'package:glown_scan_mobile/features/routine/services/routine_api.dart';

void main() {
  testWidgets('shows a Premium access message when routines are unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: RoutinePage(api: _PremiumApi())));
    await tester.pumpAndSettle();

    expect(find.text('Premium access required'), findsOneWidget);
    expect(find.textContaining('personalised routine'), findsOneWidget);
  });

  testWidgets('routine screen edits steps and opens check-in history', (
    tester,
  ) async {
    final api = _EditableRoutineApi();
    await tester.pumpWidget(MaterialApp(home: RoutinePage(api: api)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recommended: Gentle cleanser'), findsOneWidget);
    await tester.tap(find.text('Edit routine'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Routine title'),
      'Updated routine',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Step title'),
      'Cleanse gently',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(api.updatedTitle, 'Updated routine');
    expect(api.updatedMorningSteps?.single.title, 'Cleanse gently');

    await tester.tap(find.text('Check-in history'));
    await tester.pumpAndSettle();
    expect(find.text('2026-11-18'), findsOneWidget);
  });
}

class _PremiumApi implements RoutineApiContract {
  const _PremiumApi();

  @override
  Future<SkinRoutine?> getCurrent() => Future.error(
    const ApiException('Premium required', code: 'PREMIUM_REQUIRED'),
  );

  @override
  Future<SkinRoutine> createDraft({
    String? analysisSessionId,
    bool morning = true,
    bool evening = true,
    int maxStepsPerRoutine = 4,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<RoutineCheckInHistory> getHistory({
    required String from,
    required String to,
  }) => throw UnimplementedError();

  @override
  Future<RoutineToday?> getToday() => throw UnimplementedError();

  @override
  Future<RoutineToday> saveToday({
    required String date,
    required List<String> completedStepIds,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<SkinRoutine> transition(String routineId, String action) =>
      throw UnimplementedError();

  @override
  Future<SkinRoutine> updateRoutine({
    required String routineId,
    String? title,
    List<RoutineStep>? morningSteps,
    List<RoutineStep>? eveningSteps,
  }) => throw UnimplementedError();
}

class _EditableRoutineApi implements RoutineApiContract {
  String? updatedTitle;
  List<RoutineStep>? updatedMorningSteps;

  final routine = const SkinRoutine(
    id: 'routine-1',
    title: 'My routine',
    status: 'ACTIVE',
    morningSteps: [
      RoutineStep(
        id: 'step-1',
        period: 'MORNING',
        position: 1,
        title: 'Cleanse',
        instruction: 'Wash gently.',
        optional: false,
        product: RoutineProductCard(id: 'product-1', name: 'Gentle cleanser'),
      ),
    ],
    eveningSteps: [],
  );

  @override
  Future<SkinRoutine?> getCurrent() async => routine;

  @override
  Future<RoutineToday?> getToday() async => const RoutineToday(
    date: '2026-11-18',
    completedStepIds: [],
    completionPercent: 0,
    streakDays: 0,
  );

  @override
  Future<RoutineCheckInHistory> getHistory({
    required String from,
    required String to,
  }) async => const RoutineCheckInHistory(
    items: [
      RoutineToday(
        date: '2026-11-18',
        completedStepIds: [],
        completionPercent: 0,
        streakDays: 0,
      ),
    ],
  );

  @override
  Future<SkinRoutine> updateRoutine({
    required String routineId,
    String? title,
    List<RoutineStep>? morningSteps,
    List<RoutineStep>? eveningSteps,
  }) async {
    updatedTitle = title;
    updatedMorningSteps = morningSteps;
    return routine;
  }

  @override
  Future<SkinRoutine> createDraft({
    String? analysisSessionId,
    bool morning = true,
    bool evening = true,
    int maxStepsPerRoutine = 4,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<RoutineToday> saveToday({
    required String date,
    required List<String> completedStepIds,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<SkinRoutine> transition(String routineId, String action) =>
      throw UnimplementedError();
}
