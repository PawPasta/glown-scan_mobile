import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

enum MobilePlatform {
  android('ANDROID'),
  ios('IOS');

  const MobilePlatform(this.apiValue);

  final String apiValue;
}

abstract interface class AuthApiContract {
  Future<ApiResponse> register({
    required String email,
    required String password,
    required String confirmPassword,
  });

  Future<ApiResponse> loginMobile({
    required String email,
    required String password,
    MobilePlatform platform,
  });

  Future<ApiResponse> firebaseLogin({
    required String idToken,
    MobilePlatform platform,
  });

  Future<ApiResponse> refresh({
    required String accessToken,
    required String refreshToken,
  });

  Future<ApiResponse> requestPasswordReset({required String email});

  Future<ApiResponse> resendPasswordReset({required String email});

  Future<ApiResponse> resendEmailVerification({required String email});

  Future<ApiResponse> verifyEmail({
    required String email,
    required String token,
  });

  Future<bool> checkEmailVerification({
    required String email,
    required String token,
  });

  Future<ApiResponse> confirmPasswordReset({
    required String email,
    required String token,
    required String newPassword,
  });

  Future<bool> checkPasswordReset({
    required String email,
    required String token,
  });
}

class AuthApi implements AuthApiContract {
  AuthApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<ApiResponse> register({
    required String email,
    required String password,
    required String confirmPassword,
  }) => _apiClient.post(
    ApiEndpoints.register,
    json: {
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
    },
  );

  @override
  Future<ApiResponse> refresh({
    required String accessToken,
    required String refreshToken,
  }) => _apiClient.post(
    ApiEndpoints.refresh,
    json: {'accessToken': accessToken, 'refreshToken': refreshToken},
  );

  @override
  Future<ApiResponse> loginMobile({
    required String email,
    required String password,
    MobilePlatform platform = MobilePlatform.android,
  }) => _apiClient.post(
    ApiEndpoints.loginMobile,
    json: {'email': email, 'password': password, 'platform': platform.apiValue},
  );

  @override
  Future<ApiResponse> firebaseLogin({
    required String idToken,
    MobilePlatform platform = MobilePlatform.android,
  }) => _apiClient.post(
    ApiEndpoints.firebaseLogin,
    json: {'idToken': idToken, 'platform': platform.apiValue},
  );

  @override
  Future<ApiResponse> requestPasswordReset({required String email}) =>
      _apiClient.post(
        ApiEndpoints.requestPasswordReset,
        json: {'email': email},
      );

  @override
  Future<ApiResponse> resendPasswordReset({required String email}) =>
      _apiClient.post(ApiEndpoints.resendPasswordReset, json: {'email': email});

  @override
  Future<ApiResponse> resendEmailVerification({required String email}) =>
      _apiClient.post(
        ApiEndpoints.resendEmailVerification,
        json: {'email': email},
      );

  @override
  Future<ApiResponse> verifyEmail({
    required String email,
    required String token,
  }) => _apiClient.post(
    ApiEndpoints.verifyEmail,
    json: {'email': email, 'token': token},
  );

  @override
  Future<bool> checkEmailVerification({
    required String email,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.checkEmailVerification,
      json: {'email': email, 'token': token},
    );
    return _readConsumedState(response.data);
  }

  @override
  Future<ApiResponse> confirmPasswordReset({
    required String email,
    required String token,
    required String newPassword,
  }) => _apiClient.post(
    ApiEndpoints.confirmPasswordReset,
    json: {'email': email, 'token': token, 'newPassword': newPassword},
  );

  @override
  Future<bool> checkPasswordReset({
    required String email,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.checkPasswordReset,
      json: {'email': email, 'token': token},
    );
    return _readConsumedState(response.data);
  }

  bool _readConsumedState(Object? data) {
    if (data is! Map<String, dynamic> || data['success'] is! bool) {
      throw const ApiException(
        'The token check response is missing a valid data.success field.',
      );
    }
    return data['success'] as bool;
  }

  void close() {
    _apiClient.close();
  }
}
