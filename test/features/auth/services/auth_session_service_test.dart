import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/storage/auth_session_storage.dart';
import 'package:glown_scan_mobile/features/auth/services/auth_session_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'keeps a session with an unexpired access token without refreshing',
    () async {
      final storage = _MemoryAuthSessionStore()
        ..accessToken = _tokenExpiringAt(
          DateTime.now().add(const Duration(hours: 1)),
        )
        ..refreshToken = 'refresh-token';
      var requestCount = 0;
      final service = AuthSessionService(
        sessionStorage: storage,
        apiClient: ApiClient(
          baseUri: Uri.parse('https://example.test'),
          httpClient: MockClient((_) async {
            requestCount++;
            return http.Response('', 500);
          }),
        ),
      );
      addTearDown(service.close);

      expect(await service.restoreSession(), isTrue);
      expect(requestCount, 0);
      expect(storage.accessToken, isNotNull);
      expect(storage.refreshToken, 'refresh-token');
    },
  );

  test('refreshes an expired access token and saves both new tokens', () async {
    final storage = _MemoryAuthSessionStore()
      ..accessToken = _tokenExpiringAt(
        DateTime.now().subtract(const Duration(minutes: 1)),
      )
      ..refreshToken = 'old-refresh';
    final service = AuthSessionService(
      sessionStorage: storage,
      apiClient: ApiClient(
        baseUri: Uri.parse('https://example.test'),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/refresh');
          expect(jsonDecode(request.body), {
            'accessToken': storage.accessToken,
            'refreshToken': 'old-refresh',
          });
          return _jsonResponse({
            'status': 200,
            'message': 'Success',
            'data': {
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
            },
          }, 200);
        }),
      ),
    );
    addTearDown(service.close);

    expect(await service.restoreSession(), isTrue);
    expect(storage.accessToken, 'new-access');
    expect(storage.refreshToken, 'new-refresh');
  });

  test(
    'clears tokens when the refresh token has expired or been revoked',
    () async {
      final storage = _MemoryAuthSessionStore()
        ..accessToken = _tokenExpiringAt(
          DateTime.now().subtract(const Duration(minutes: 1)),
        )
        ..refreshToken = 'invalid-refresh';
      final service = AuthSessionService(
        sessionStorage: storage,
        apiClient: ApiClient(
          baseUri: Uri.parse('https://example.test'),
          httpClient: MockClient(
            (_) async => _jsonResponse({
              'status': 401,
              'message': 'Refresh token is invalid',
              'data': null,
            }, 401),
          ),
        ),
      );
      addTearDown(service.close);

      expect(await service.restoreSession(), isFalse);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    },
  );

  test('does not retain an incomplete token pair', () async {
    final storage = _MemoryAuthSessionStore()..accessToken = 'access-token';
    final service = AuthSessionService(sessionStorage: storage);
    addTearDown(service.close);

    expect(await service.restoreSession(), isFalse);
    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });
}

String _tokenExpiringAt(DateTime expiration) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'exp': expiration.millisecondsSinceEpoch ~/ 1000}),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

http.Response _jsonResponse(Map<String, Object?> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

class _MemoryAuthSessionStore implements AuthSessionStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}
