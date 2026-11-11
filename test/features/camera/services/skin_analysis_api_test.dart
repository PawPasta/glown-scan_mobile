import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/api_endpoints.dart';
import 'package:glown_scan_mobile/features/camera/services/skin_analysis_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test(
    'uploads a captured image and sends its Cloudinary details for analysis',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'glownscan-camera-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final photo = File('${directory.path}${Platform.pathSeparator}face.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final backendRequests = <http.Request>[];
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'access-token',
        httpClient: MockClient((request) async {
          backendRequests.add(request);
          if (request.url.path == ApiEndpoints.skinAnalysisUploadIntent) {
            return _jsonResponse({
              'status': 201,
              'message': 'Created successfully',
              'data': {
                'publicId': 'glownscan/skin-analysis/user-id/scan-id',
                'timestamp': 1794380513,
                'signature': 'intent-signature',
                'apiKey': 'cloudinary-api-key',
                'cloudName': 'glownscan',
              },
            }, 201);
          }

          expect(request.url.path, ApiEndpoints.skinAnalysisAnalyze);
          expect(jsonDecode(request.body), {
            'publicId': 'glownscan/skin-analysis/user-id/scan-id',
            'version': 42,
            'signature': 'cloudinary-signature',
            'secureUrl':
                'https://res.cloudinary.com/glownscan/image/upload/face.jpg',
          });
          return _jsonResponse({
            'status': 200,
            'message': 'Analysis completed',
            'data': {'score': 91},
          }, 200);
        }),
      );
      final cloudinaryClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.host, 'api.cloudinary.com');
        expect(request.url.path, '/v1_1/glownscan/image/upload');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(
          request.body,
          contains(
            'name="public_id"\r\n\r\nglownscan/skin-analysis/user-id/scan-id',
          ),
        );
        return _jsonResponse({
          'public_id': 'glownscan/skin-analysis/user-id/scan-id',
          'version': 42,
          'signature': 'cloudinary-signature',
          'secure_url':
              'https://res.cloudinary.com/glownscan/image/upload/face.jpg',
        }, 200);
      });
      final api = SkinAnalysisApi(
        apiClient: apiClient,
        cloudinaryClient: cloudinaryClient,
      );
      addTearDown(api.close);

      final result = await api.analyze(XFile(photo.path));

      expect(result, {
        'status': 200,
        'message': 'Analysis completed',
        'data': {'score': 91},
      });
      expect(backendRequests.map((request) => request.url.path), [
        ApiEndpoints.skinAnalysisUploadIntent,
        ApiEndpoints.skinAnalysisAnalyze,
      ]);
      expect(
        backendRequests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer access-token',
        ),
        isTrue,
      );
    },
  );
}

http.Response _jsonResponse(Map<String, Object?> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
