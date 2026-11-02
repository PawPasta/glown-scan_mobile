import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/features/account/services/account_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('changes password with an authenticated request', () async {
    final requests = <http.Request>[];
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      accessTokenProvider: () async => 'test-access-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        return _jsonResponse({
          'status': 200,
          'message': 'Success',
          'data': null,
        });
      }),
    );
    final api = AccountApi(apiClient: apiClient);
    addTearDown(api.close);

    await api.changePassword(
      oldPassword: 'OldPassword123!',
      newPassword: 'NewPassword456!',
    );

    expect(requests.map((request) => request.method), ['POST']);
    expect(requests.map((request) => request.url.path), [
      '/auth/password/change',
    ]);
    expect(jsonDecode(requests.first.body), {
      'oldPassword': 'OldPassword123!',
      'newPassword': 'NewPassword456!',
    });
    expect(
      requests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer test-access-token',
      ),
      isTrue,
    );
  });

  test(
    'loads a profile using the authenticated GET profile endpoint',
    () async {
      final requests = <http.Request>[];
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        accessTokenProvider: () async => 'test-access-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse({
            'status': 200,
            'message': 'Success',
            'data': _profileData(),
          });
        }),
      );
      final api = AccountApi(apiClient: apiClient);
      addTearDown(api.close);

      final profile = await api.getProfile();

      expect(profile.id, 'profile-id');
      expect(profile.fullName, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.dateOfBirth, isNull);
      expect(profile.gender, 'MALE');
      expect(requests.map((request) => request.method), ['GET']);
      expect(requests.map((request) => request.url.path), ['/auth/profile']);
      expect(
        requests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer test-access-token',
        ),
        isTrue,
      );
    },
  );

  test('patches profile details without sending skin profile data', () async {
    final requests = <http.Request>[];
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      accessTokenProvider: () async => 'test-access-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        return _jsonResponse({
          'status': 200,
          'message': 'Success',
          'data': _profileData(),
        });
      }),
    );
    final api = AccountApi(apiClient: apiClient);
    addTearDown(api.close);

    final profile = await api.updateProfile(
      fullName: 'Bèo Bảo',
      dateOfBirth: '2000-01-02',
      gender: 'FEMALE',
    );

    expect(profile.id, 'profile-id');
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/auth/profile');
    expect(jsonDecode(requests.single.body), {
      'fullName': 'Bèo Bảo',
      'dateOfBirth': '2000-01-02',
      'gender': 'FEMALE',
    });
  });

  test('uploads an avatar with Cloudinary intent and confirms its response', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('glownscan-');
    addTearDown(() => tempDirectory.delete(recursive: true));
    final imageFile = File('${tempDirectory.path}\\avatar.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    final backendRequests = <http.Request>[];
    final backendClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      accessTokenProvider: () async => 'test-access-token',
      httpClient: MockClient((request) async {
        backendRequests.add(request);
        final apiRequest = request;
        if (apiRequest.url.path.endsWith('upload-intent')) {
          return _jsonResponse({
            'status': 200,
            'message': 'Success',
            'data': {
              'publicId': 'avatars/user-id',
              'timestamp': 123456,
              'signature': 'signed-value',
              'apiKey': 'public-api-key',
              'cloudName': 'glownscan',
            },
          });
        }
        if (apiRequest.url.path.endsWith('avatar/confirm')) {
          expect(jsonDecode(apiRequest.body), {
            'publicId': 'avatars/user-id',
            'version': 987,
            'signature': 'cloudinary-signature',
            'secureUrl':
                'https://res.cloudinary.com/glownscan/image/upload/avatar.jpg',
          });
        }
        return _jsonResponse({
          'status': 200,
          'message': 'Success',
          'data': {
            'profile': {
              'id': 'profile-id',
              'fullName': 'Bèo Bảo',
              'avatarUrl': 'https://res.cloudinary.com/glownscan/image/upload/avatar.jpg',
              'dateOfBirth': null,
              'gender': null,
            },
          },
        });
      }),
    );
    final cloudinaryClient = MockClient((request) async {
      expect(request.url.host, 'api.cloudinary.com');
      expect(request.url.path, '/v1_1/glownscan/image/upload');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(request.body, contains('name="public_id"\r\n\r\navatars/user-id'));
      expect(request.body, contains('name="timestamp"\r\n\r\n123456'));
      expect(request.body, contains('name="signature"\r\n\r\nsigned-value'));
      expect(request.body, contains('name="api_key"\r\n\r\npublic-api-key'));
      return http.Response(
        jsonEncode({
          'public_id': 'avatars/user-id',
          'version': 987,
          'signature': 'cloudinary-signature',
          'secure_url':
              'https://res.cloudinary.com/glownscan/image/upload/avatar.jpg',
        }),
        200,
      );
    });
    final api = AccountApi(
      apiClient: backendClient,
      cloudinaryClient: cloudinaryClient,
    );
    addTearDown(api.close);

    final profile = await api.uploadAvatar(XFile(imageFile.path));

    expect(profile.avatarUrl, contains('cloudinary.com'));
    expect(backendRequests.map((request) => request.url.path), [
      '/auth/profile/avatar/upload-intent',
      '/auth/profile/avatar/confirm',
      '/auth/profile',
    ]);
    expect(
      backendRequests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer test-access-token',
      ),
      isTrue,
    );
  });
}

http.Response _jsonResponse(Map<String, Object?> body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _profileData() => {
  'profile': {
    'id': 'profile-id',
    'userId': 'user-id',
    'fullName': null,
    'avatarUrl': null,
    'dateOfBirth': null,
    'gender': 'MALE',
    'createdAt': '2026-11-02T09:45:06.890747+00:00',
    'updatedAt': '2026-11-02T09:49:22.718985+00:00',
  },
};
