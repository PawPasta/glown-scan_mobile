import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/api_endpoints.dart';
import 'package:glown_scan_mobile/core/storage/auth_session_storage.dart';
import 'package:glown_scan_mobile/features/auth/services/auth_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUri = 'https://api.glownscan.xyz/';

  test('mobile login defaults to Android and sends FCM token', () async {
    final api = AuthApi(
      apiClient: ApiClient(
        baseUri: Uri.parse(baseUri),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url, Uri.parse('${baseUri}auth/mobile/login'));
          expect(jsonDecode(request.body), {
            'email': 'user@example.com',
            'password': 'Password123!',
            'platform': 'ANDROID',
            'fcmToken': 'fcm-token',
          });
          return _jsonResponse({
            'status': 200,
            'message': 'Logged in successfully',
            'data': {'accessToken': 'access-token'},
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);

    final response = await api.loginMobile(
      email: 'user@example.com',
      password: 'Password123!',
      fcmToken: 'fcm-token',
    );

    expect(response.status, 200);
    expect(response.message, 'Logged in successfully');
    expect(response.data, {'accessToken': 'access-token'});
  });

  test('refresh sends the refresh token to the refresh endpoint', () async {
    final api = AuthApi(
      apiClient: ApiClient(
        baseUri: Uri.parse(baseUri),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, ApiEndpoints.refresh);
          expect(jsonDecode(request.body), {'refreshToken': 'old-refresh'});
          return _jsonResponse({
            'status': 200,
            'message': 'Tokens refreshed',
            'data': {
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
            },
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);

    final response = await api.refresh(refreshToken: 'old-refresh');
    expect(response.data, {
      'accessToken': 'new-access',
      'refreshToken': 'new-refresh',
    });
  });

  test('Firebase login sends the Google ID token', () async {
    final api = AuthApi(
      apiClient: ApiClient(
        baseUri: Uri.parse(baseUri),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, ApiEndpoints.firebaseLogin);
          expect(jsonDecode(request.body), {
            'idToken': 'google-id-token',
            'platform': 'ANDROID',
          });
          return _jsonResponse({
            'status': 200,
            'message': 'Logged in successfully',
            'data': {
              'accessToken': 'backend-access',
              'refreshToken': 'backend-refresh',
            },
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);

    final response = await api.firebaseLogin(idToken: 'google-id-token');
    expect(response.data, {
      'accessToken': 'backend-access',
      'refreshToken': 'backend-refresh',
    });
  });

  test('register sends the required JSON body', () async {
    final api = AuthApi(
      apiClient: ApiClient(
        baseUri: Uri.parse(baseUri),
        httpClient: MockClient((request) async {
          expect(request.url.path, ApiEndpoints.register);
          expect(jsonDecode(request.body), {
            'email': 'user@example.com',
            'password': 'Password123!',
            'confirmPassword': 'Password123!',
          });
          return _jsonResponse({
            'status': 201,
            'message': 'Account created successfully',
            'data': null,
          }, 201);
        }),
      ),
    );
    addTearDown(api.close);

    final response = await api.register(
      email: 'user@example.com',
      password: 'Password123!',
      confirmPassword: 'Password123!',
    );
    expect(response.status, 201);
  });

  test('checks the password reset token', () async {
    final api = AuthApi(
      apiClient: ApiClient(
        baseUri: Uri.parse(baseUri),
        httpClient: MockClient((request) async {
          expect(request.url.path, ApiEndpoints.checkPasswordReset);
          expect(jsonDecode(request.body), {
            'email': 'user@example.com',
            'token': 'one-time-token',
          });
          return http.Response(
            '{"status":200,"message":"Success","data":{"success":true}}',
            200,
          );
        }),
      ),
    );
    addTearDown(api.close);

    expect(
      await api.checkPasswordReset(
        email: 'user@example.com',
        token: 'one-time-token',
      ),
      isTrue,
    );
  });

  test('requests and resends reset and verification emails', () async {
    final expectedPaths = [
      ApiEndpoints.requestPasswordReset,
      ApiEndpoints.resendPasswordReset,
      ApiEndpoints.resendEmailVerification,
    ];
    var requestIndex = 0;
    final api = AuthApi(
      apiClient: ApiClient(
        baseUri: Uri.parse(baseUri),
        httpClient: MockClient((request) async {
          expect(request.url.path, expectedPaths[requestIndex++]);
          expect(jsonDecode(request.body), {'email': 'user@example.com'});
          return _jsonResponse({
            'status': 200,
            'message': 'Email sent',
            'data': null,
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);

    await api.requestPasswordReset(email: 'user@example.com');
    await api.resendPasswordReset(email: 'user@example.com');
    await api.resendEmailVerification(email: 'user@example.com');
    expect(requestIndex, 3);
  });

  test(
    'authenticated requests read and send the stored bearer token',
    () async {
      final apiClient = ApiClient(
        baseUri: Uri.parse(baseUri),
        accessTokenProvider: () async => 'stored-access-token',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.headers['authorization'],
            'Bearer stored-access-token',
          );
          expect(request.url, Uri.parse('${baseUri}profile'));
          return http.Response(
            '{"status":200,"message":"Success","data":{}}',
            200,
          );
        }),
      );
      addTearDown(apiClient.close);

      final response = await apiClient.get(
        ApiEndpoints.profile,
        requiresAuth: true,
      );
      expect(response.message, 'Success');
    },
  );

  test(
    'refreshes expired tokens and retries the authenticated request',
    () async {
      final storage = _MemoryAuthSessionStore()
        ..accessToken = 'expired-access'
        ..refreshToken = 'old-refresh';
      final requests = <http.Request>[];
      final apiClient = ApiClient(
        baseUri: Uri.parse(baseUri),
        sessionStorage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == ApiEndpoints.profile) {
            if (request.headers['authorization'] == 'Bearer expired-access') {
              return _jsonResponse({
                'status': 401,
                'message': 'Access token expired',
                'data': null,
              }, 401);
            }
            return _jsonResponse({
              'status': 200,
              'message': 'Success',
              'data': {'profile': true},
            }, 200);
          }

          expect(request.url.path, ApiEndpoints.refresh);
          expect(jsonDecode(request.body), {'refreshToken': 'old-refresh'});
          return _jsonResponse({
            'status': 200,
            'message': 'Tokens refreshed',
            'data': {
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
            },
          }, 200);
        }),
      );
      addTearDown(apiClient.close);

      final response = await apiClient.get(
        ApiEndpoints.profile,
        requiresAuth: true,
      );

      expect(response.data, {'profile': true});
      expect(requests, hasLength(3));
      expect(requests[0].headers['authorization'], 'Bearer expired-access');
      expect(requests[2].headers['authorization'], 'Bearer new-access');
      expect(storage.accessToken, 'new-access');
      expect(storage.refreshToken, 'new-refresh');
    },
  );

  test('REST client supports GET, POST, PUT, PATCH, and DELETE', () async {
    const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
    var requestIndex = 0;
    final client = ApiClient(
      baseUri: Uri.parse(baseUri),
      httpClient: MockClient((request) async {
        expect(request.method, methods[requestIndex++]);
        return http.Response(
          '{"status":200,"message":"Success","data":null}',
          200,
        );
      }),
    );
    addTearDown(client.close);

    await client.get('/test');
    await client.post('/test', json: const {'value': 1});
    await client.put('/test', json: const {'value': 1});
    await client.patch('/test', json: const {'value': 1});
    await client.delete('/test', json: const {'value': 1});
    expect(requestIndex, methods.length);
  });

  test('throws the backend message and status for failed responses', () async {
    final client = ApiClient(
      baseUri: Uri.parse(baseUri),
      httpClient: MockClient(
        (_) async => _jsonResponse({
          'status': 400,
          'message': 'Email already exists',
          'data': null,
        }, 400),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      client.post(ApiEndpoints.register, json: const {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.message,
              'message',
              'Email already exists',
            ),
      ),
    );
  });
}

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

http.Response _jsonResponse(Map<String, Object?> json, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(json)),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
