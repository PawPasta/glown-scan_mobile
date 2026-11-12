import '../../../core/storage/installation_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'push_notification_service.dart';

class DeviceRegistration {
  const DeviceRegistration({
    required this.installationId,
    required this.fcmToken,
    this.platform = 'ANDROID',
  });
  final String installationId;
  final String fcmToken;
  final String platform;
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
  });

  final DeviceApi deviceApi;
  final InstallationStore installationStore;

  Future<void> syncFcmToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final installationId = await installationStore.readOrCreateInstallationId();
    await deviceApi.register(
      DeviceRegistration(installationId: installationId, fcmToken: token),
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
