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
                'total': 21,
              },
            }, 200);
          }
          if (request.url.path == '${ApiEndpoints.skinAnalysis}/scan-1') {
            return _json({
              'status': 200,
              'message': 'Success',
              'data': {
                'id': 'scan-1',
                'status': 'SUCCEEDED',
                'result': {'summary': 'Clear skin'},
              },
            }, 200);
          }
          expect(request.url.path, ApiEndpoints.recommendationsMe);
          return _json({
            'status': 200,
            'message': 'Success',
            'data': {
              'generatedAt': '2026-11-18T12:00:00.000Z',
              'source': {
                'assessmentAvailable': true,
                'analysisAvailable': true,
                'concernCodes': ['ACNE'],
              },
              'items': [
                {
                  'id': 'p1',
                  'name': 'Moisturizer',
                  'matchedConcerns': ['ACNE'],
                  'reasons': ['Matches hydration'],
                },
              ],
            },
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);
    final history = await api.getHistory(page: 2, limit: 10);
    expect(history.items.single.id, 'scan-1');
    expect(history.page, 2);
    expect(history.limit, 10);
    expect(history.hasMore, isTrue);
    expect((await api.getAnalysisSession('scan-1')).result, {
      'summary': 'Clear skin',
    });
    final recommendations = await api.getRecommendations();
    expect(recommendations.items.single.name, 'Moisturizer');
    expect(recommendations.items.single.matchedConcerns, ['ACNE']);
    expect(recommendations.source.analysisAvailable, isTrue);
    expect(recommendations.generatedAt, '2026-11-18T12:00:00.000Z');
  });

  test('clamps analysis history paging to the backend contract', () async {
    final api = SkinCareApi(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          expect(request.url.path, ApiEndpoints.skinAnalysis);
          expect(request.url.queryParameters, {'page': '1', 'limit': '1'});
          return _json({
            'status': 200,
            'message': 'Success',
            'data': {'items': [], 'total': 0},
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);

    final history = await api.getHistory(page: -5, limit: 0);
    expect(history.page, 1);
    expect(history.limit, 1);
    expect(history.hasMore, isFalse);
  });

  test(
    'preserves large page values and caps limit at the backend maximum',
    () async {
      final api = SkinCareApi(
        apiClient: ApiClient(
          baseUri: Uri.parse('https://api.glownscan.xyz/'),
          accessTokenProvider: () async => 'token',
          httpClient: MockClient((request) async {
            expect(request.url.path, ApiEndpoints.skinAnalysis);
            expect(request.url.queryParameters, {
              'page': '10000',
              'limit': '100',
            });
            return _json({
              'status': 200,
              'message': 'Success',
              'data': {'items': [], 'total': 0},
            }, 200);
          }),
        ),
      );
      addTearDown(api.close);

      final history = await api.getHistory(page: 10000, limit: 101);
      expect(history.page, 10000);
      expect(history.limit, 100);
    },
  );

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

  test('identifies a premium-limited analysis result', () {
    final session = SkinAnalysisSession.fromJson({
      'id': 'scan-1',
      'status': 'SUCCEEDED',
      'result': {
        'quality': {'accepted': true, 'issues': []},
        'summary': {'overallSkinScore': 82},
        'premiumRequired': true,
      },
    });

    expect(session.requiresPremium, isTrue);
  });

  test('preserves the backend premium-required error code', () async {
    final api = SkinCareApi(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(
          (_) async => _json({
            'status': 403,
            'message': 'Premium required',
            'code': 'PREMIUM_REQUIRED',
            'data': null,
          }, 403),
        ),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.getRecommendations(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'PREMIUM_REQUIRED',
        ),
      ),
    );
  });
}

http.Response _json(Map<String, Object?> body, int code) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: const {'content-type': 'application/json'},
);
