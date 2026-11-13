import 'dart:async';
import 'dart:ui';

import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/storage/installation_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'push_notification_service.dart';

class DeviceRegistration {
  const DeviceRegistration({
    required this.installationId,
    required this.fcmToken,
    this.platform = 'ANDROID',
    this.appVersion,
    this.locale,
    this.timezone,
  });
  final String installationId;
  final String fcmToken;
  final String platform;
  final String? appVersion;
  final String? locale;
  final String? timezone;
}

class DeviceMetadata {
  const DeviceMetadata({this.appVersion, this.locale, this.timezone});

  final String? appVersion;
  final String? locale;
  final String? timezone;

  static Future<DeviceMetadata> read() async {
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version.isEmpty ? null : info.version;
    } catch (_) {
      // Registration still works when package metadata is unavailable.
    }
    return DeviceMetadata(
      appVersion: appVersion,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      timezone: DateTime.now().timeZoneName,
    );
  }
}

abstract interface class DeviceApi {
  Future<void> register(DeviceRegistration registration);
  Future<void> unregister({required String installationId});
}

/// Test-only transport until Backend supplies its device registration contract.
class MockDeviceApi implements DeviceApi {
  final registrations = <String, DeviceRegistration>{};

  @override
  Future<void> register(DeviceRegistration registration) async {
    registrations[registration.installationId] = registration;
  }

  @override
  Future<void> unregister({required String installationId}) async {
    registrations.remove(installationId);
  }
}

class DeviceApiClient implements DeviceApi {
  DeviceApiClient({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();
  final ApiClient _apiClient;

  @override
  Future<void> register(DeviceRegistration registration) async {
    await _apiClient.put(
      ApiEndpoints.deviceMe,
      requiresAuth: true,
      json: {
        'installationId': registration.installationId,
        'platform': registration.platform,
        'fcmToken': registration.fcmToken,
        if (registration.appVersion != null)
          'appVersion': registration.appVersion,
        if (registration.locale != null) 'locale': registration.locale,
        if (registration.timezone != null) 'timezone': registration.timezone,
      },
    );
  }

  @override
  Future<void> unregister({required String installationId}) async {
    await _apiClient.delete(
      ApiEndpoints.deviceMe,
      requiresAuth: true,
      json: {'installationId': installationId},
    );
  }

  void close() => _apiClient.close();
}

class DeviceRegistrationService {
  DeviceRegistrationService({
    required this.deviceApi,
    required this.installationStore,
    this.metadataReader = DeviceMetadata.read,
  });

  final DeviceApi deviceApi;
  final InstallationStore installationStore;
  final Future<DeviceMetadata> Function() metadataReader;

  Future<void> syncFcmToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final installationId = await installationStore.readOrCreateInstallationId();
    final metadata = await metadataReader();
    await deviceApi.register(
      DeviceRegistration(
        installationId: installationId,
        fcmToken: token,
        appVersion: metadata.appVersion,
        locale: metadata.locale,
        timezone: metadata.timezone,
      ),
    );
  }

  /// Runs after a session is stored; failures must never block sign-in.
  Future<void> syncCurrentPushToken() async {
    try {
      await syncFcmToken(await PushNotificationService.instance.getToken());
    } on ApiException {
      // The next app start or FCM refresh will retry this best-effort sync.
    }
  }

  Future<void> unregister() async {
    final installationId = await installationStore.readOrCreateInstallationId();
    await deviceApi.unregister(installationId: installationId);
  }
}

/// Keeps one FCM-refresh listener for the signed-in app process.
class DeviceSyncCoordinator {
  DeviceSyncCoordinator._();

  static final instance = DeviceSyncCoordinator._();
  DeviceRegistrationService? _service;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> start(DeviceRegistrationService service) async {
    _service ??= service;
    await _service!.syncCurrentPushToken();
    _tokenSubscription ??= PushNotificationService.instance.onTokenRefresh
        .listen((token) => unawaited(_syncRefreshedToken(token)));
  }

  Future<void> _syncRefreshedToken(String token) async {
    try {
      await _service?.syncFcmToken(token);
    } on ApiException {
      // A later token refresh or app launch retries the best-effort sync.
    }
  }

  Future<void> stop() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    final deviceApi = _service?.deviceApi;
    if (deviceApi is DeviceApiClient) {
      deviceApi.close();
    }
    _service = null;
  }
}
