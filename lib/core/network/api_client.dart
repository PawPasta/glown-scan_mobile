import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/auth_session_storage.dart';

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
    Future<String?> Function()? accessTokenProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? AppConfig.apiBaseUri,
       _accessTokenProvider =
           accessTokenProvider ?? AuthSessionStorage().readAccessToken;

  final http.Client _httpClient;
  final Uri _baseUri;
  final Future<String?> Function() _accessTokenProvider;

  Future<ApiResponse> request(
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
        accessToken ?? (requiresAuth ? await _accessTokenProvider() : null);
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
