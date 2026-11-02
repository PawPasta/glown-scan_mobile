import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_session_storage.dart';

class AuthSessionService {
  AuthSessionService({ApiClient? apiClient, AuthSessionStore? sessionStorage})
    : _sessionStorage = sessionStorage ?? AuthSessionStorage() {
    _apiClient = apiClient;
  }

  final AuthSessionStore _sessionStorage;
  ApiClient? _apiClient;

  Future<bool> restoreSession() async {
    final accessToken = await _sessionStorage.readAccessToken();
    final refreshToken = await _sessionStorage.readRefreshToken();
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      if ((accessToken?.isNotEmpty ?? false) ||
          (refreshToken?.isNotEmpty ?? false)) {
        await _sessionStorage.clear();
      }
      return false;
    }

    if (hasValidExpiration(accessToken)) return true;

    try {
      final response =
          await (_apiClient ??= ApiClient(
            sessionStorage: _sessionStorage,
          )).post(
            ApiEndpoints.refresh,
            json: {'accessToken': accessToken, 'refreshToken': refreshToken},
          );
      final tokens = _readTokens(response.data);
      await _sessionStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionStorage.clear();
        return false;
      }
      rethrow;
    }
  }

  static bool hasValidExpiration(String token, {DateTime? now}) {
    final parts = token.split('.');
    if (parts.length != 3) return false;

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return false;
      final expiration = payload['exp'];
      if (expiration is! num) return false;
      final currentTime = (now ?? DateTime.now()).millisecondsSinceEpoch / 1000;
      return expiration > currentTime + 30;
    } on FormatException {
      return false;
    }
  }

  _SessionTokens _readTokens(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        'The refresh response is missing access and refresh tokens.',
      );
    }
    final nestedTokens = data['tokens'];
    final tokens = nestedTokens is Map<String, dynamic> ? nestedTokens : data;
    final accessToken = tokens['accessToken'];
    final refreshToken = tokens['refreshToken'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const ApiException(
        'The refresh response is missing access and refresh tokens.',
      );
    }
    return _SessionTokens(accessToken, refreshToken);
  }

  void close() {
    _apiClient?.close();
  }
}

class _SessionTokens {
  const _SessionTokens(this.accessToken, this.refreshToken);

  final String accessToken;
  final String refreshToken;
}
