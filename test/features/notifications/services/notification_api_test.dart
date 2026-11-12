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
          return _json({
            'status': 200,
            'message': 'OK',
            'data': {
              'items': [
                {
                  'id': 'n1',
                  'title': 'Ready',
                  'body': 'Your analysis is ready',
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
    expect((await api.getNotifications()).single.read, isFalse);
  });
}

http.Response _json(Map<String, Object?> value, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      headers: const {'content-type': 'application/json'},
    );
