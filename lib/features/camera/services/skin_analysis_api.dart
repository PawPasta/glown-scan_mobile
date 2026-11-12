import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../skin/services/skin_care_api.dart';

class SkinAnalysisUploadIntent {
  const SkinAnalysisUploadIntent({
    required this.publicId,
    required this.timestamp,
    required this.signature,
    required this.apiKey,
    required this.cloudName,
  });
  final String publicId;
  final int timestamp;
  final String signature;
  final String apiKey;
  final String cloudName;

  factory SkinAnalysisUploadIntent.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['publicId'] is! String ||
        value['timestamp'] is! int ||
        value['signature'] is! String ||
        value['apiKey'] is! String ||
        value['cloudName'] is! String) {
      throw const ApiException(
        'The skin-analysis upload intent is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return SkinAnalysisUploadIntent(
      publicId: value['publicId'] as String,
      timestamp: value['timestamp'] as int,
      signature: value['signature'] as String,
      apiKey: value['apiKey'] as String,
      cloudName: value['cloudName'] as String,
    );
  }
}

class SkinAnalysisApi {
  SkinAnalysisApi({
    ApiClient? apiClient,
    http.Client? cloudinaryClient,
    this.uploadTimeout = const Duration(seconds: 60),
  }) : _apiClient = apiClient ?? ApiClient(),
       _cloudinaryClient = cloudinaryClient ?? http.Client();
  final ApiClient _apiClient;
  final http.Client _cloudinaryClient;
  final Duration uploadTimeout;

  Future<SkinAnalysisSession> analyze(
    XFile image, {
    String? idempotencyKey,
  }) async {
    final intent = SkinAnalysisUploadIntent.fromJson(
      (await _apiClient.post(
        ApiEndpoints.skinAnalysisUploadIntent,
        requiresAuth: true,
      )).data,
    );
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const ApiException(
        'The captured photo is empty.',
        kind: ApiErrorKind.validation,
      );
    }
    final upload =
        http.MultipartRequest(
            'POST',
            Uri.https(
              'api.cloudinary.com',
              '/v1_1/${Uri.encodeComponent(intent.cloudName)}/image/upload',
            ),
          )
          ..fields['public_id'] = intent.publicId
          ..fields['timestamp'] = '${intent.timestamp}'
          ..fields['signature'] = intent.signature
          ..fields['api_key'] = intent.apiKey
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              Uint8List.fromList(bytes),
              filename: image.name.isEmpty ? 'skin-scan.jpg' : image.name,
            ),
          );
    final http.Response cloudinaryResponse;
    try {
      cloudinaryResponse = await http.Response.fromStream(
        await _cloudinaryClient.send(upload).timeout(uploadTimeout),
      ).timeout(uploadTimeout);
    } on TimeoutException {
      throw const ApiException(
        'Photo upload timed out. Please try again.',
        kind: ApiErrorKind.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        'Photo upload failed. Check your connection and try again.',
        kind: ApiErrorKind.network,
      );
    }
    final uploaded = _decodeCloudinaryResponse(cloudinaryResponse);
    if (cloudinaryResponse.statusCode < 200 ||
        cloudinaryResponse.statusCode >= 300) {
      final error = uploaded['error'];
      throw ApiException(
        error is Map<String, dynamic> && error['message'] is String
            ? error['message'] as String
            : 'Cloudinary could not upload the image.',
        statusCode: cloudinaryResponse.statusCode,
      );
    }
    final publicId = uploaded['public_id'];
    final version = uploaded['version'];
    final signature = uploaded['signature'];
    final secureUrl = uploaded['secure_url'];
    if (publicId is! String ||
        version is! int ||
        signature is! String ||
        secureUrl is! String) {
      throw const ApiException(
        'Cloudinary did not return the data needed to analyze this photo.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return SkinAnalysisSession.fromJson(
      (await _apiClient.post(
        ApiEndpoints.skinAnalysisAnalyze,
        requiresAuth: true,
        extraHeaders: {
          'Idempotency-Key': idempotencyKey ?? _newIdempotencyKey(),
        },
        json: {
          'publicId': publicId,
          'version': version,
          'signature': signature,
          'secureUrl': secureUrl,
        },
      )).data,
    );
  }

  Future<SkinAnalysisSession> getStatus(String sessionId) async =>
      SkinAnalysisSession.fromJson(
        (await _apiClient.get(
          '${ApiEndpoints.skinAnalysis}/$sessionId',
          requiresAuth: true,
        )).data,
      );

  Map<String, dynamic> _decodeCloudinaryResponse(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on FormatException {
      throw ApiException(
        'Cloudinary returned an invalid response.',
        statusCode: response.statusCode,
        kind: ApiErrorKind.invalidResponse,
      );
    }
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    String segment(int length) => List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${segment(8)}-${segment(4)}-4${segment(3)}-${segment(4)}-${segment(12)}';
  }

  void close() {
    _apiClient.close();
    _cloudinaryClient.close();
  }
}
