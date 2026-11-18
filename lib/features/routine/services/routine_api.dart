import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class RoutineProductCard {
  const RoutineProductCard({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;

  factory RoutineProductCard.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String) {
      throw const ApiException(
        'A routine product card is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return RoutineProductCard(
      id: value['id'] as String,
      name: value['name'] as String,
      brand: value['brand'] as String?,
      imageUrl: value['imageUrl'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (brand != null) 'brand': brand,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

class RoutineStep {
  const RoutineStep({
    required this.id,
    required this.period,
    required this.position,
    required this.title,
    required this.instruction,
    required this.optional,
    this.product,
  });
  final String id;
  final String period;
  final int position;
  final String title;
  final String instruction;
  final bool optional;
  final RoutineProductCard? product;

  RoutineStep copyWith({String? title, String? instruction, bool? optional}) =>
      RoutineStep(
        id: id,
        period: period,
        position: position,
        title: title ?? this.title,
        instruction: instruction ?? this.instruction,
        optional: optional ?? this.optional,
        product: product,
      );

  Map<String, Object?> toJson() => {
    if (id.isNotEmpty && !id.startsWith('_draft_')) 'id': id,
    'period': period,
    'position': position,
    'title': title,
    'instruction': instruction,
    'optional': optional,
    if (product != null) 'product': product!.toJson(),
  };
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
      product: value['product'] == null
          ? null
          : RoutineProductCard.fromJson(value['product']),
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

class RoutineCheckInHistory {
  const RoutineCheckInHistory({required this.items});

  final List<RoutineToday> items;

  factory RoutineCheckInHistory.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['items'] is! List) {
      throw const ApiException(
        'The routine history response is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return RoutineCheckInHistory(
      items: (value['items'] as List).map(RoutineToday.fromJson).toList(),
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
  Future<SkinRoutine> updateRoutine({
    required String routineId,
    String? title,
    List<RoutineStep>? morningSteps,
    List<RoutineStep>? eveningSteps,
  });
  Future<RoutineToday?> getToday();
  Future<RoutineToday> saveToday({
    required String date,
    required List<String> completedStepIds,
    String? note,
  });
  Future<RoutineCheckInHistory> getHistory({
    required String from,
    required String to,
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
  Future<SkinRoutine> updateRoutine({
    required String routineId,
    String? title,
    List<RoutineStep>? morningSteps,
    List<RoutineStep>? eveningSteps,
  }) async => SkinRoutine.fromJson(
    (await _client.patch(
      '${ApiEndpoints.routines}/$routineId',
      requiresAuth: true,
      json: {
        'title': ?title,
        'morningSteps': ?morningSteps?.map((step) => step.toJson()).toList(),
        'eveningSteps': ?eveningSteps?.map((step) => step.toJson()).toList(),
      },
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

  @override
  Future<RoutineCheckInHistory> getHistory({
    required String from,
    required String to,
  }) async => RoutineCheckInHistory.fromJson(
    (await _client.get(
      '${ApiEndpoints.routineCurrent}/check-ins?from=$from&to=$to',
      requiresAuth: true,
    )).data,
  );
  void close() => _client.close();
}
