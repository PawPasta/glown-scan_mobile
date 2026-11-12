import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/api_endpoints.dart';
import 'package:glown_scan_mobile/features/skin/services/skin_care_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'reads and saves the current assessment with contract validation',
    () async {
      var requests = 0;
      final api = SkinCareApi(
        apiClient: ApiClient(
          baseUri: Uri.parse('https://api.glownscan.xyz/'),
          accessTokenProvider: () async => 'token',
          httpClient: MockClient((request) async {
            requests++;
            expect(request.headers['authorization'], 'Bearer token');
            if (request.method == 'GET') {
              return _json({
                'status': 200,
                'message': 'Success',
                'data': null,
              }, 200);
            }
            expect(request.url.path, ApiEndpoints.skinAssessmentCurrent);
            expect(jsonDecode(request.body), {
              'answers': {
                'skinType': 'COMBINATION',
                'sensitivity': 'LOW',
                'concerns': ['ACNE'],
                'goals': ['HYDRATION'],
              },
            });
            return _json({
              'status': 200,
              'message': 'Saved',
              'data': {
                'answers': {
                  'skinType': 'COMBINATION',
                  'sensitivity': 'LOW',
                  'concerns': ['ACNE'],
                  'goals': ['HYDRATION'],
                },
              },
            }, 200);
          }),
        ),
      );
      addTearDown(api.close);
      expect(await api.getAssessment(), isNull);
      final saved = await api.saveAssessment(
        const SkinAssessmentAnswers(
          skinType: 'COMBINATION',
          sensitivity: 'LOW',
          concerns: ['ACNE'],
          goals: ['HYDRATION'],
        ),
      );
      expect(saved.answers.skinType, 'COMBINATION');
      expect(requests, 2);
    },
  );

  test('loads paginated history and product recommendations', () async {
    final api = SkinCareApi(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          if (request.url.path == ApiEndpoints.skinAnalysis) {
            expect(request.url.queryParameters, {'page': '2', 'limit': '10'});
            return _json({
              'status': 200,
              'message': 'Success',
              'data': {
                'items': [
                  {'id': 'scan-1', 'status': 'SUCCEEDED'},
                ],
                'total': 1,
              },
            }, 200);
          }
          expect(request.url.path, ApiEndpoints.recommendationsMe);
          return _json({
            'status': 200,
            'message': 'Success',
            'data': {
              'items': [
                {
                  'id': 'p1',
                  'name': 'Moisturizer',
                  'reasons': ['Matches hydration'],
                },
              ],
            },
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);
    expect(
      (await api.getHistory(page: 2, limit: 10)).items.single.id,
      'scan-1',
    );
    expect((await api.getRecommendations()).single.name, 'Moisturizer');
  });

  test('rejects NONE with another concern before making a request', () async {
    final api = SkinCareApi(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        httpClient: MockClient(
          (_) async => throw StateError('No request expected'),
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.saveAssessment(
        const SkinAssessmentAnswers(
          skinType: 'NORMAL',
          sensitivity: 'LOW',
          concerns: ['NONE', 'ACNE'],
          goals: [],
        ),
      ),
      throwsA(isA<ApiException>()),
    );
  });
}

http.Response _json(Map<String, Object?> body, int code) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: const {'content-type': 'application/json'},
);
