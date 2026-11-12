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
    'uploads a photo, submits an idempotent analysis job, and reads status',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'glownscan-camera-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final photo = File('${directory.path}${Platform.pathSeparator}face.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final backend = ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'access-token',
        httpClient: MockClient((request) async {
          if (request.url.path == ApiEndpoints.skinAnalysisUploadIntent) {
            return _json({
              'status': 201,
              'message': 'Created',
              'data': {
                'publicId': 'glownscan/skin-analysis/user-id/scan-id',
                'timestamp': 1794380513,
                'signature': 'intent-signature',
                'apiKey': 'key',
                'cloudName': 'cloud',
              },
            }, 201);
          }
          if (request.url.path == ApiEndpoints.skinAnalysisAnalyze) {
            expect(request.headers['idempotency-key'], 'retry-safe-key');
            expect(
              jsonDecode(request.body),
              containsPair(
                'publicId',
                'glownscan/skin-analysis/user-id/scan-id',
              ),
            );
            return _json({
              'status': 202,
              'message': 'Queued',
              'data': {'sessionId': 'session-id', 'status': 'QUEUED'},
            }, 202);
          }
          expect(request.url.path, '${ApiEndpoints.skinAnalysis}/session-id');
          return _json({
            'status': 200,
            'message': 'Success',
            'data': {
              'id': 'session-id',
              'status': 'SUCCEEDED',
              'result': {'quality': 'good'},
            },
          }, 200);
        }),
      );
      final cloudinary = MockClient((request) async {
        expect(request.url.path, '/v1_1/cloud/image/upload');
        return _json({
          'public_id': 'glownscan/skin-analysis/user-id/scan-id',
          'version': 42,
          'signature': 'cloudinary-signature',
          'secure_url':
              'https://res.cloudinary.com/cloud/image/upload/face.jpg',
        }, 200);
      });
      final api = SkinAnalysisApi(
        apiClient: backend,
        cloudinaryClient: cloudinary,
      );
      addTearDown(api.close);

      final queued = await api.analyze(
        XFile(photo.path),
        idempotencyKey: 'retry-safe-key',
      );
      final completed = await api.getStatus(queued.id);

      expect(queued.status, 'QUEUED');
      expect(completed.status, 'SUCCEEDED');
      expect(completed.result, {'quality': 'good'});
    },
  );
}

http.Response _json(Map<String, Object?> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
