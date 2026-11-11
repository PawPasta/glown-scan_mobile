import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

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
    if (value is! Map<String, dynamic>) {
      throw const ApiException('The skin-analysis upload intent is invalid.');
    }
    final publicId = value['publicId'];
    final timestamp = value['timestamp'];
    final signature = value['signature'];
    final apiKey = value['apiKey'];
    final cloudName = value['cloudName'];
    if (publicId is! String ||
        timestamp is! int ||
        signature is! String ||
        apiKey is! String ||
        cloudName is! String) {
      throw const ApiException(
        'The skin-analysis upload intent is missing Cloudinary details.',
      );
    }
    return SkinAnalysisUploadIntent(
      publicId: publicId,
      timestamp: timestamp,
      signature: signature,
      apiKey: apiKey,
      cloudName: cloudName,
    );
  }
}

class SkinAnalysisApi {
  SkinAnalysisApi({ApiClient? apiClient, http.Client? cloudinaryClient})
    : _apiClient = apiClient ?? ApiClient(),
      _cloudinaryClient = cloudinaryClient ?? http.Client();

  final ApiClient _apiClient;
  final http.Client _cloudinaryClient;

  Future<Object?> analyze(XFile image) async {
    final intentResponse = await _apiClient.post(
      ApiEndpoints.skinAnalysisUploadIntent,
      requiresAuth: true,
    );
    final intent = SkinAnalysisUploadIntent.fromJson(intentResponse.data);
    final bytes = await image.readAsBytes();
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

    final cloudinaryResponse = await http.Response.fromStream(
      await _cloudinaryClient.send(upload),
    );
    final uploaded = _decodeCloudinaryResponse(cloudinaryResponse);
    if (cloudinaryResponse.statusCode < 200 ||
        cloudinaryResponse.statusCode >= 300) {
      final error = uploaded['error'];
      final message =
          error is Map<String, dynamic> && error['message'] is String
          ? error['message'] as String
          : 'Cloudinary could not upload the image.';
      throw ApiException(message, statusCode: cloudinaryResponse.statusCode);
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
      );
    }

    final response = await _apiClient.post(
      ApiEndpoints.skinAnalysisAnalyze,
      requiresAuth: true,
      json: {
        'publicId': publicId,
        'version': version,
        'signature': signature,
        'secureUrl': secureUrl,
      },
    );
    // Preserve the backend envelope because the analysis schema is still being
    // discovered in the test environment and is rendered verbatim by the UI.
    return {
      'status': response.status,
      'message': response.message,
      'data': response.data,
    };
  }

  Map<String, dynamic> _decodeCloudinaryResponse(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return decoded;
    } on FormatException catch (error) {
      throw ApiException(
        'Cloudinary returned an invalid response: ${error.message}',
        statusCode: response.statusCode,
      );
    }
  }

  void close() {
    _apiClient.close();
    _cloudinaryClient.close();
  }
}
