import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/features/notifications/pages/notifications_page.dart';
import 'package:glown_scan_mobile/features/notifications/services/notification_api.dart';

void main() {
  testWidgets('loads the next notification page when requested', (
    tester,
  ) async {
    final api = _PagedNotificationApi();
    await tester.pumpWidget(MaterialApp(home: NotificationsPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('First notification'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1, 2]);
    expect(find.text('Second notification'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });
}

class _PagedNotificationApi implements NotificationApiContract {
  final requestedPages = <int>[];

  @override
  Future<NotificationPreferences> getPreferences() async =>
      const NotificationPreferences(
        routineReminders: true,
        analysisUpdates: true,
        productRecommendations: true,
        marketing: false,
      );

  @override
  Future<NotificationInbox> getNotifications({
    int page = 1,
    int limit = 30,
  }) async {
    requestedPages.add(page);
    final item = AppNotification(
      id: 'notification-$page',
      title: page == 1 ? 'First notification' : 'Second notification',
      body: 'Notification details',
      read: true,
    );
    return NotificationInbox(items: [item], total: 2, page: page, limit: limit);
  }

  @override
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences value,
  ) async => value;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}
