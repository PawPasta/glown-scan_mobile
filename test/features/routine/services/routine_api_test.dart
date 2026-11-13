import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/api_endpoints.dart';
import 'package:glown_scan_mobile/features/routine/services/routine_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'creates an idempotent routine draft and saves daily progress',
    () async {
      final api = RoutineApi(
        apiClient: ApiClient(
          baseUri: Uri.parse('https://api.glownscan.xyz/'),
          accessTokenProvider: () async => 'token',
          httpClient: MockClient((request) async {
            expect(request.headers['authorization'], 'Bearer token');
            if (request.url.path == '${ApiEndpoints.routines}/draft') {
              expect(request.headers['idempotency-key'], 'draft-key');
              expect(
                jsonDecode(request.body),
                containsPair('preferences', {
                  'morning': true,
                  'evening': true,
                  'maxStepsPerRoutine': 4,
                }),
              );
              return _json({
                'status': 201,
                'message': 'Created',
                'data': _routine(),
              }, 201);
            }
            expect(
              request.url.path,
              '${ApiEndpoints.routineCurrent}/check-ins/2026-11-12',
            );
            expect(jsonDecode(request.body), {
              'completedStepIds': ['step-1'],
            });
            return _json({
              'status': 200,
              'message': 'Saved',
              'data': {
                'date': '2026-11-12',
                'completedStepIds': ['step-1'],
                'completionPercent': 50,
                'streakDays': 2,
              },
            }, 200);
          }),
        ),
      );
      addTearDown(api.close);
      expect(
        (await api.createDraft(idempotencyKey: 'draft-key')).status,
        'DRAFT',
      );
      expect(
        (await api.saveToday(
          date: '2026-11-12',
          completedStepIds: ['step-1'],
        )).streakDays,
        2,
      );
    },
  );

  test('edits a routine and reads inclusive check-in history', () async {
    final api = RoutineApi(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          if (request.method == 'PATCH') {
            expect(request.url.path, '${ApiEndpoints.routines}/routine-1');
            expect(jsonDecode(request.body), {'title': 'Gentle routine'});
            return _json({
              'status': 200,
              'message': 'Updated',
              'data': _routine(),
            }, 200);
          }
          expect(request.url.queryParameters, {
            'from': '2026-11-01',
            'to': '2026-11-07',
          });
          return _json({
            'status': 200,
            'message': 'Success',
            'data': {
              'items': [
                {
                  'date': '2026-11-07',
                  'completedStepIds': [],
                  'completionPercent': 0,
                  'streakDays': 2,
                },
              ],
            },
          }, 200);
        }),
      ),
    );
    addTearDown(api.close);

    expect(
      (await api.updateRoutine(
        routineId: 'routine-1',
        title: 'Gentle routine',
      )).id,
      'routine-1',
    );
    expect(
      (await api.getHistory(
        from: '2026-11-01',
        to: '2026-11-07',
      )).items.single.streakDays,
      2,
    );
  });
}

Map<String, Object?> _routine() => {
  'id': 'routine-1',
  'title': 'My routine',
  'status': 'DRAFT',
  'morningSteps': [],
  'eveningSteps': [],
};
http.Response _json(Map<String, Object?> value, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      headers: const {'content-type': 'application/json'},
    );
