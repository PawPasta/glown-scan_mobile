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
