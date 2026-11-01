import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/auth_session_storage.dart';
import 'api_endpoints.dart';

enum ApiMethod { get, post, put, patch, delete }

extension on ApiMethod {
  String get value => name.toUpperCase();
}

class ApiResponse {
  const ApiResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  final int status;
  final String message;
  final Object? data;
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    Uri? baseUri,
    this.accessTokenProvider,
    AuthSessionStore? sessionStorage,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? AppConfig.apiBaseUri,
       _sessionStorage = sessionStorage ?? AuthSessionStorage();

  final http.Client _httpClient;
  final Uri _baseUri;
  final Future<String?> Function()? accessTokenProvider;
  final AuthSessionStore _sessionStorage;
  Future<String>? _refreshingAccessToken;

  Future<ApiResponse> request(
    ApiMethod method,
    String endpoint, {
    Map<String, Object?>? json,
    String? accessToken,
    bool requiresAuth = false,
  }) async {
    final token =
        accessToken ?? (requiresAuth ? await _readAccessToken() : null);
    try {
      return await _requestOnce(
        method,
        endpoint,
        json: json,
        accessToken: token,
        requiresAuth: requiresAuth,
      );
    } on ApiException catch (error) {
      if (!requiresAuth ||
          endpoint == ApiEndpoints.refresh ||
          error.statusCode != 401) {
        rethrow;
      }

      final refreshedToken = await _refreshAccessToken(token);
      return _requestOnce(
        method,
        endpoint,
        json: json,
        accessToken: refreshedToken,
        requiresAuth: true,
      );
    }
  }

  Future<ApiResponse> _requestOnce(
    ApiMethod method,
    String endpoint, {
    Map<String, Object?>? json,
    String? accessToken,
    bool requiresAuth = false,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    if (json != null) {
      headers['content-type'] = 'application/json';
    }

    final token =
        accessToken ?? (requiresAuth ? await _readAccessToken() : null);
    if (requiresAuth && (token == null || token.isEmpty)) {
      throw const ApiException('Please log in again to continue.');
    }
    if (token != null && token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }

    final uri = _baseUri.resolve(
      endpoint.startsWith('/') ? endpoint.substring(1) : endpoint,
    );
    final request = http.Request(method.value, uri)..headers.addAll(headers);
    if (json != null) {
      request.body = jsonEncode(json);
    }

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      envelope = decoded;
    } on FormatException catch (error) {
      throw ApiException(
        'The server returned an invalid response: ${error.message}',
        statusCode: response.statusCode,
      );
    }

    final message = envelope['message'];
    final responseMessage = message is String ? message : 'The request failed.';
    final envelopeStatus = envelope['status'];
    final status = envelopeStatus is int ? envelopeStatus : response.statusCode;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        status < 200 ||
        status >= 300) {
      throw ApiException(responseMessage, statusCode: status);
    }
    if (!envelope.containsKey('data')) {
      throw ApiException(
        'The server response is missing the data field.',
        statusCode: response.statusCode,
      );
    }

    return ApiResponse(
      status: status,
      message: responseMessage,
      data: envelope['data'],
    );
  }

  Future<String?> _readAccessToken() =>
      accessTokenProvider?.call() ?? _sessionStorage.readAccessToken();

  Future<String> _refreshAccessToken(String? rejectedToken) async {
    final currentToken = await _readAccessToken();
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        currentToken != rejectedToken) {
      return currentToken;
    }

    final pendingRefresh = _refreshingAccessToken;
    if (pendingRefresh != null) return pendingRefresh;

    final refresh = _requestNewTokens();
    _refreshingAccessToken = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshingAccessToken, refresh)) {
        _refreshingAccessToken = null;
      }
    }
  }

  Future<String> _requestNewTokens() async {
    final refreshToken = await _sessionStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiException(
        'Please log in again to continue.',
        statusCode: 401,
      );
    }

    final response = await _requestOnce(
      ApiMethod.post,
      ApiEndpoints.refresh,
      json: {'refreshToken': refreshToken},
    );
    final tokenData = response.data;
    if (tokenData is! Map<String, dynamic>) {
      throw const ApiException(
        'The refresh response is missing access and refresh tokens.',
      );
    }
    final nestedTokens = tokenData['tokens'];
    final tokens = nestedTokens is Map<String, dynamic>
        ? nestedTokens
        : tokenData;
    final accessToken = tokens['accessToken'];
    final newRefreshToken = tokens['refreshToken'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        newRefreshToken is! String ||
        newRefreshToken.isEmpty) {
      throw const ApiException(
        'The refresh response is missing access and refresh tokens.',
      );
    }

    await _sessionStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
    );
    return accessToken;
  }

  Future<ApiResponse> get(
    String endpoint, {
    String? accessToken,
    bool requiresAuth = false,
  }) => request(
    ApiMethod.get,
    endpoint,
    accessToken: accessToken,
    requiresAuth: requiresAuth,
  );

  Future<ApiResponse> post(
    String endpoint, {
    Map<String, Object?>? json,
    String? accessToken,
    bool requiresAuth = false,
  }) => request(
    ApiMethod.post,
    endpoint,
    json: json,
    accessToken: accessToken,
    requiresAuth: requiresAuth,
  );

  Future<ApiResponse> put(
    String endpoint, {
    Map<String, Object?>? json,
    String? accessToken,
    bool requiresAuth = false,
  }) => request(
    ApiMethod.put,
    endpoint,
    json: json,
    accessToken: accessToken,
    requiresAuth: requiresAuth,
  );

  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, Object?>? json,
    String? accessToken,
    bool requiresAuth = false,
  }) => request(
    ApiMethod.patch,
    endpoint,
    json: json,
    accessToken: accessToken,
    requiresAuth: requiresAuth,
  );

  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, Object?>? json,
    String? accessToken,
    bool requiresAuth = false,
  }) => request(
    ApiMethod.delete,
    endpoint,
    json: json,
    accessToken: accessToken,
    requiresAuth: requiresAuth,
  );

  void close() {
    _httpClient.close();
  }
}
