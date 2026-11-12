import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class RoutineStep {
  const RoutineStep({
    required this.id,
    required this.period,
    required this.position,
    required this.title,
    required this.instruction,
    required this.optional,
  });
  final String id;
  final String period;
  final int position;
  final String title;
  final String instruction;
  final bool optional;
  factory RoutineStep.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['period'] is! String ||
        value['position'] is! int ||
        value['title'] is! String ||
        value['instruction'] is! String) {
      throw const ApiException(
        'A routine step is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return RoutineStep(
      id: value['id'] as String,
      period: value['period'] as String,
      position: value['position'] as int,
      title: value['title'] as String,
      instruction: value['instruction'] as String,
      optional: value['optional'] as bool? ?? false,
    );
  }
}

class SkinRoutine {
  const SkinRoutine({
    required this.id,
    required this.title,
    required this.status,
    required this.morningSteps,
    required this.eveningSteps,
  });
  final String id;
  final String title;
  final String status;
  final List<RoutineStep> morningSteps;
  final List<RoutineStep> eveningSteps;
  factory SkinRoutine.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['status'] is! String) {
      throw const ApiException(
        'The routine response is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    List<RoutineStep> steps(String key) =>
        (value[key] as List? ?? const []).map(RoutineStep.fromJson).toList();
    return SkinRoutine(
      id: value['id'] as String,
      title: value['title'] as String,
      status: value['status'] as String,
      morningSteps: steps('morningSteps'),
      eveningSteps: steps('eveningSteps'),
    );
  }
}

class RoutineToday {
  const RoutineToday({
    required this.date,
    required this.completedStepIds,
    required this.completionPercent,
    required this.streakDays,
  });
  final String date;
  final List<String> completedStepIds;
  final num completionPercent;
  final int streakDays;
  factory RoutineToday.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['date'] is! String) {
      throw const ApiException(
        'Today\'s routine progress is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return RoutineToday(
      date: value['date'] as String,
      completedStepIds: (value['completedStepIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      completionPercent: value['completionPercent'] as num? ?? 0,
      streakDays: value['streakDays'] as int? ?? 0,
    );
  }
}

abstract interface class RoutineApiContract {
  Future<SkinRoutine?> getCurrent();
  Future<SkinRoutine> createDraft({
    String? analysisSessionId,
    bool morning = true,
    bool evening = true,
    int maxStepsPerRoutine = 4,
    required String idempotencyKey,
  });
  Future<SkinRoutine> transition(String routineId, String action);
  Future<RoutineToday?> getToday();
  Future<RoutineToday> saveToday({
    required String date,
    required List<String> completedStepIds,
    String? note,
  });
}

class RoutineApi implements RoutineApiContract {
  RoutineApi({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();
  final ApiClient _client;
  @override
  Future<SkinRoutine?> getCurrent() async {
    final data = (await _client.get(
      ApiEndpoints.routineCurrent,
      requiresAuth: true,
    )).data;
    return data == null ? null : SkinRoutine.fromJson(data);
  }

  @override
  Future<SkinRoutine> createDraft({
    String? analysisSessionId,
    bool morning = true,
    bool evening = true,
    int maxStepsPerRoutine = 4,
    required String idempotencyKey,
  }) async => SkinRoutine.fromJson(
    (await _client.post(
      '${ApiEndpoints.routines}/draft',
      requiresAuth: true,
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      json: {
        'analysisSessionId': analysisSessionId,
        'preferences': {
          'morning': morning,
          'evening': evening,
          'maxStepsPerRoutine': maxStepsPerRoutine,
        },
      },
    )).data,
  );
  @override
  Future<SkinRoutine> transition(String routineId, String action) async =>
      SkinRoutine.fromJson(
        (await _client.post(
          '${ApiEndpoints.routines}/$routineId/$action',
          requiresAuth: true,
        )).data,
      );
  @override
  Future<RoutineToday?> getToday() async {
    final data = (await _client.get(
      '${ApiEndpoints.routineCurrent}/today',
      requiresAuth: true,
    )).data;
    return data == null ? null : RoutineToday.fromJson(data);
  }

  @override
  Future<RoutineToday> saveToday({
    required String date,
    required List<String> completedStepIds,
    String? note,
  }) async => RoutineToday.fromJson(
    (await _client.put(
      '${ApiEndpoints.routineCurrent}/check-ins/$date',
      requiresAuth: true,
      json: {
        'completedStepIds': completedStepIds,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    )).data,
  );
  void close() => _client.close();
}
