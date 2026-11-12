import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class SkinAssessmentAnswers {
  const SkinAssessmentAnswers({
    required this.skinType,
    required this.sensitivity,
    required this.concerns,
    required this.goals,
  });

  final String skinType;
  final String sensitivity;
  final List<String> concerns;
  final List<String> goals;

  Map<String, Object?> toJson() => {
    'skinType': skinType,
    'sensitivity': sensitivity,
    'concerns': concerns,
    'goals': goals,
  };

  factory SkinAssessmentAnswers.fromJson(Map<String, dynamic> json) =>
      SkinAssessmentAnswers(
        skinType: json['skinType'] as String? ?? 'NOT_SURE',
        sensitivity: json['sensitivity'] as String? ?? 'NOT_SURE',
        concerns: _strings(json['concerns']),
        goals: _strings(json['goals']),
      );
}

class SkinAssessment {
  const SkinAssessment({required this.answers, this.updatedAt});
  final SkinAssessmentAnswers answers;
  final String? updatedAt;

  factory SkinAssessment.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['answers'] is! Map<String, dynamic>) {
      throw const ApiException(
        'The skin assessment response is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return SkinAssessment(
      answers: SkinAssessmentAnswers.fromJson(
        value['answers'] as Map<String, dynamic>,
      ),
      updatedAt: value['updatedAt'] as String?,
    );
  }
}

class SkinAnalysisSession {
  const SkinAnalysisSession({
    required this.id,
    required this.status,
    this.createdAt,
    this.completedAt,
    this.errorCode,
    this.result,
  });
  final String id;
  final String status;
  final String? createdAt;
  final String? completedAt;
  final String? errorCode;
  final Object? result;

  bool get isComplete => status == 'SUCCEEDED' || status == 'FAILED';

  factory SkinAnalysisSession.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException(
        'The skin analysis response is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    final id = value['id'] ?? value['sessionId'];
    final status = value['status'];
    if (id is! String || status is! String) {
      throw const ApiException(
        'The skin analysis response is missing its session.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return SkinAnalysisSession(
      id: id,
      status: status,
      createdAt: value['createdAt'] as String?,
      completedAt: value['completedAt'] as String?,
      errorCode: value['errorCode'] as String?,
      result: value['result'],
    );
  }
}

class SkinAnalysisHistory {
  const SkinAnalysisHistory({required this.items, required this.total});
  final List<SkinAnalysisSession> items;
  final int total;
}

class ProductRecommendation {
  const ProductRecommendation({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.imageUrl,
    this.reasons = const [],
    this.disclaimer,
  });
  final String id;
  final String name;
  final String? brand;
  final String? description;
  final String? imageUrl;
  final List<String> reasons;
  final String? disclaimer;

  factory ProductRecommendation.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String) {
      throw const ApiException(
        'A product recommendation is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return ProductRecommendation(
      id: value['id'] as String,
      name: value['name'] as String,
      brand: value['brand'] as String?,
      description: value['description'] as String?,
      imageUrl: value['imageUrl'] as String?,
      reasons: _strings(value['reasons']),
      disclaimer: value['disclaimer'] as String?,
    );
  }
}

abstract interface class SkinCareApiContract {
  Future<SkinAssessment?> getAssessment();
  Future<SkinAssessment> saveAssessment(SkinAssessmentAnswers answers);
  Future<SkinAnalysisHistory> getHistory({int page = 1, int limit = 20});
  Future<List<ProductRecommendation>> getRecommendations({int limit = 20});
}

class SkinCareApi implements SkinCareApiContract {
  SkinCareApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();
  final ApiClient _apiClient;

  @override
  Future<SkinAssessment?> getAssessment() async {
    final response = await _apiClient.get(
      ApiEndpoints.skinAssessmentCurrent,
      requiresAuth: true,
    );
    return response.data == null
        ? null
        : SkinAssessment.fromJson(response.data);
  }

  @override
  Future<SkinAssessment> saveAssessment(SkinAssessmentAnswers answers) async {
    _validate(answers);
    final response = await _apiClient.put(
      ApiEndpoints.skinAssessmentCurrent,
      requiresAuth: true,
      json: {'answers': answers.toJson()},
    );
    return SkinAssessment.fromJson(response.data);
  }

  @override
  Future<SkinAnalysisHistory> getHistory({int page = 1, int limit = 20}) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.skinAnalysis}?page=${page.clamp(1, 999)}&limit=${limit.clamp(1, 100)}',
      requiresAuth: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const ApiException(
        'The analysis history response is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return SkinAnalysisHistory(
      items: (data['items'] as List).map(SkinAnalysisSession.fromJson).toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  @override
  Future<List<ProductRecommendation>> getRecommendations({
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.recommendationsMe}?limit=${limit.clamp(1, 100)}',
      requiresAuth: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const ApiException(
        'The recommendations response is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return (data['items'] as List).map(ProductRecommendation.fromJson).toList();
  }

  void close() => _apiClient.close();

  void _validate(SkinAssessmentAnswers answers) {
    const skinTypes = {'NORMAL', 'DRY', 'OILY', 'COMBINATION', 'NOT_SURE'};
    const sensitivities = {'LOW', 'MEDIUM', 'HIGH', 'NOT_SURE'};
    const concerns = {
      'ACNE',
      'REDNESS',
      'DARK_SPOTS',
      'PORES',
      'DRYNESS',
      'OILINESS',
      'TEXTURE',
      'NONE',
    };
    const goals = {
      'REDUCE_ACNE',
      'EVEN_TONE',
      'HYDRATION',
      'OIL_CONTROL',
      'ANTI_AGING',
      'MAINTAIN_HEALTHY_SKIN',
    };
    if (!skinTypes.contains(answers.skinType) ||
        !sensitivities.contains(answers.sensitivity) ||
        answers.concerns.length > 7 ||
        answers.goals.length > 6 ||
        answers.concerns.toSet().length != answers.concerns.length ||
        answers.goals.toSet().length != answers.goals.length ||
        !answers.concerns.every(concerns.contains) ||
        !answers.goals.every(goals.contains) ||
        (answers.concerns.contains('NONE') && answers.concerns.length != 1)) {
      throw const ApiException(
        'Please choose valid skin assessment answers.',
        kind: ApiErrorKind.validation,
      );
    }
  }
}

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];
