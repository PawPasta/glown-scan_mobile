import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.routineReminders,
    required this.analysisUpdates,
    required this.productRecommendations,
    required this.marketing,
    this.reminderTime,
    this.timezone,
  });
  final bool routineReminders,
      analysisUpdates,
      productRecommendations,
      marketing;
  final String? reminderTime, timezone;
  factory NotificationPreferences.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException(
        'Notification preferences are invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return NotificationPreferences(
      routineReminders: value['routineReminders'] as bool? ?? false,
      analysisUpdates: value['analysisUpdates'] as bool? ?? false,
      productRecommendations: value['productRecommendations'] as bool? ?? false,
      marketing: value['marketing'] as bool? ?? false,
      reminderTime: value['reminderTime'] as String?,
      timezone: value['timezone'] as String?,
    );
  }
  Map<String, Object?> toJson() => {
    'routineReminders': routineReminders,
    'analysisUpdates': analysisUpdates,
    'productRecommendations': productRecommendations,
    'marketing': marketing,
    if (reminderTime != null) 'reminderTime': reminderTime,
    if (timezone != null) 'timezone': timezone,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    this.type,
    this.payload,
    this.createdAt,
  });
  final String id, title, body;
  final bool read;
  final String? type;
  final Object? payload;
  final String? createdAt;
  factory AppNotification.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['body'] is! String) {
      throw const ApiException(
        'A notification is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return AppNotification(
      id: value['id'] as String,
      title: value['title'] as String,
      body: value['body'] as String,
      read: value['readAt'] != null,
      type: value['type'] as String?,
      payload: value['payload'],
      createdAt: value['createdAt'] as String?,
    );
  }
}

class NotificationInbox {
  const NotificationInbox({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AppNotification> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => items.length < total;
}

abstract interface class NotificationApiContract {
  Future<NotificationPreferences> getPreferences();
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences value,
  );
  Future<NotificationInbox> getNotifications({int page = 1, int limit = 30});
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

class NotificationApi implements NotificationApiContract {
  NotificationApi({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();
  final ApiClient _client;
  @override
  Future<NotificationPreferences> getPreferences() async =>
      NotificationPreferences.fromJson(
        (await _client.get(
          ApiEndpoints.notificationPreferences,
          requiresAuth: true,
        )).data,
      );
  @override
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences value,
  ) async => NotificationPreferences.fromJson(
    (await _client.patch(
      ApiEndpoints.notificationPreferences,
      requiresAuth: true,
      json: value.toJson(),
    )).data,
  );
  @override
  Future<NotificationInbox> getNotifications({
    int page = 1,
    int limit = 30,
  }) async {
    final safePage = page.clamp(1, 9999);
    final safeLimit = limit.clamp(1, 100);
    final data = (await _client.get(
      '${ApiEndpoints.notifications}?page=$safePage&limit=$safeLimit',
      requiresAuth: true,
    )).data;
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const ApiException(
        'The notification inbox is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    final items = (data['items'] as List)
        .map(AppNotification.fromJson)
        .toList();
    return NotificationInbox(
      items: items,
      total: data['total'] as int? ?? items.length,
      page: safePage,
      limit: safeLimit,
    );
  }

  @override
  Future<void> markRead(String id) async {
    await _client.patch(
      '${ApiEndpoints.notifications}/$id/read',
      requiresAuth: true,
    );
  }

  @override
  Future<void> markAllRead() async {
    await _client.post(
      '${ApiEndpoints.notifications}/read-all',
      requiresAuth: true,
    );
  }

  void close() => _client.close();
}
