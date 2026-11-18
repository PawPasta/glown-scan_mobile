import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/api_endpoints.dart';
import 'package:glown_scan_mobile/features/notifications/services/notification_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads notification preferences and inbox', () async {
    final api = NotificationApi(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          if (request.url.path == ApiEndpoints.notificationPreferences) {
            return _json({
              'status': 200,
              'message': 'OK',
              'data': {
                'routineReminders': true,
                'analysisUpdates': true,
                'productRecommendations': false,
                'marketing': false,
              },
            }, 200);
          }
          expect(request.url.path, ApiEndpoints.notifications);
          expect(request.url.queryParameters, {'page': '2', 'limit': '10'});
          return _json({
            'status': 200,
            'message': 'OK',
            'data': {
              'items': [
                {
                  'id': 'n1',
                  'title': 'Ready',
                  'body': 'Your analysis is ready',
                  'type': 'ANALYSIS_READY',
                  'payload': {'sessionId': 'scan-1'},
                  'createdAt': '2026-11-18T12:00:00.000Z',
                  'readAt': null,
                },
              ],
              'total': 1,
            },
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);
    expect((await api.getPreferences()).routineReminders, isTrue);
    final inbox = await api.getNotifications(page: 2, limit: 10);
    expect(inbox.items.single.read, isFalse);
    expect(inbox.items.single.type, 'ANALYSIS_READY');
    expect(inbox.items.single.payload, {'sessionId': 'scan-1'});
    expect(inbox.total, 1);
    expect(inbox.hasMore, isFalse);
  });
}

http.Response _json(Map<String, Object?> value, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      headers: const {'content-type': 'application/json'},
    );
