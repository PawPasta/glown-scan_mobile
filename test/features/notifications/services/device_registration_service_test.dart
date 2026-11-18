import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/api_endpoints.dart';
import 'package:glown_scan_mobile/core/storage/installation_storage.dart';
import 'package:glown_scan_mobile/features/notifications/services/device_registration_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'reads the Android IANA timezone ID from the native system zone',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('glownscan/device');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getTimezoneId');
            return 'Asia/Ho_Chi_Minh';
          });

      expect((await DeviceMetadata.read()).timezone, 'Asia/Ho_Chi_Minh');
    },
  );

  test('registers FCM token with installation and device metadata', () async {
    final api = DeviceApiClient(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'access-token',
        httpClient: MockClient((request) async {
          expect(request.url.path, ApiEndpoints.deviceMe);
          expect(request.headers['authorization'], 'Bearer access-token');
          expect(jsonDecode(request.body), {
            'installationId': 'installation-id',
            'platform': 'ANDROID',
            'fcmToken': 'fcm-token',
            'appVersion': '1.2.0',
            'locale': 'vi-VN',
            'timezone': 'Asia/Ho_Chi_Minh',
          });
          return http.Response(
            '{"status":200,"message":"Updated","data":{}}',
            200,
          );
        }),
      ),
    );
    addTearDown(api.close);
    final service = DeviceRegistrationService(
      deviceApi: api,
      installationStore: _InstallationStore(),
      metadataReader: () async => const DeviceMetadata(
        appVersion: '1.2.0',
        locale: 'vi-VN',
        timezone: 'Asia/Ho_Chi_Minh',
      ),
    );

    await service.syncFcmToken('fcm-token');
  });
}

class _InstallationStore implements InstallationStore {
  @override
  Future<String> readOrCreateInstallationId() async => 'installation-id';
}
