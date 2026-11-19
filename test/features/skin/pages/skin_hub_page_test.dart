import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/features/skin/pages/skin_hub_page.dart';
import 'package:glown_scan_mobile/features/skin/services/skin_care_api.dart';

void main() {
  testWidgets('loads the next analysis history page on demand', (tester) async {
    final api = _FakeSkinCareApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SkinHubPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Load more analyses'), findsOneWidget);
    expect(find.text('Analysis one'), findsOneWidget);

    await tester.tap(find.text('Load more analyses'));
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1, 2]);
    expect(find.text('Analysis two'), findsOneWidget);
    expect(find.text('Load more analyses'), findsNothing);
  });
}

class _FakeSkinCareApi implements SkinCareApiContract {
  final List<int> requestedPages = [];

  @override
  Future<SkinAssessment?> getAssessment() async => null;

  @override
  Future<SkinAnalysisHistory> getHistory({int page = 1, int limit = 20}) async {
    requestedPages.add(page);
    final session = SkinAnalysisSession(
      id: page == 1 ? 'scan-1' : 'scan-2',
      status: 'SUCCEEDED',
      createdAt: page == 1 ? 'Analysis one' : 'Analysis two',
      result: null,
    );
    return SkinAnalysisHistory(
      items: [session],
      total: 11,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<SkinAnalysisSession> getAnalysisSession(String sessionId) async =>
      SkinAnalysisSession(id: sessionId, status: 'SUCCEEDED');

  @override
  Future<RecommendationResponse> getRecommendations({int limit = 20}) async =>
      const RecommendationResponse(
        generatedAt: null,
        source: RecommendationSource(
          assessmentAvailable: false,
          analysisAvailable: false,
          concernCodes: [],
        ),
        items: [],
      );

  @override
  Future<SkinAssessment> saveAssessment(SkinAssessmentAnswers answers) async =>
      SkinAssessment(answers: answers);
}
