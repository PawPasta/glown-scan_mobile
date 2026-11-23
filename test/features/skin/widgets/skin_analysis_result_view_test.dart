import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/features/skin/widgets/skin_analysis_result_view.dart';

void main() {
  testWidgets('presents Free summary, quality issues, and Premium details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkinAnalysisResultView(
              requiresPremium: true,
              result: {
                'schemaVersion': '1.0',
                'quality': {
                  'accepted': false,
                  'issues': ['LOW_LIGHT', 'BLURRY'],
                },
                'summary': {
                  'overallSkinScore': 73,
                  'confidence': 0.81,
                  'notes': [
                    'Your cheeks appear mostly even.',
                    'The image is a little soft.',
                  ],
                },
                'premiumRequired': true,
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('73'), findsOneWidget);
    expect(find.text('81% confidence'), findsOneWidget);
    expect(find.text('Some parts may be hard to assess'), findsOneWidget);
    expect(find.text('Low Light'), findsOneWidget);
    expect(find.text('Blurry'), findsOneWidget);
    expect(find.text('Your cheeks appear mostly even.'), findsOneWidget);
    expect(find.text('Unlock your complete skin report'), findsOneWidget);
    expect(find.text('Detailed skin metrics'), findsOneWidget);
    expect(find.textContaining('Raw JSON'), findsNothing);
  });

  testWidgets('shows structured details for Premium without the upgrade card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkinAnalysisResultView(
              result: {
                'quality': {'accepted': true, 'issues': []},
                'summary': {
                  'overallSkinScore': 88,
                  'confidence': 0.92,
                  'notes': ['Visible skin tone appears even.'],
                },
                'skinProfile': {
                  'skinType': 'OILY',
                  'sensitivityLevel': null,
                  'notes': 'Visible shine suggests an oily skin type in these regions.',
                },
                'metrics': {
                  'acne': {
                    'score': 8,
                    'confidence': 0.8,
                    'visibility': 'CLEAR',
                  },
                  'dryness': {
                    'score': 0,
                    'confidence': 0.5,
                    'visibility': 'NOT_VISIBLE',
                  },
                },
                'regions': {
                  'forehead': {
                    'score': 72,
                    'confidence': 0.8,
                    'visibility': 'CLEAR',
                  },
                },
                'observations': [
                  {
                    'note': 'Visible shine on the forehead area.',
                    'type': 'VISIBLE_OILINESS',
                    'box2d': [345, 362, 478, 645],
                    'severity': 2,
                    'confidence': 0.8,
                    'visibility': 'CLEAR',
                  },
                ],
                'highlights': [
                  {
                    'x': 503,
                    'y': 412,
                    'type': 'oiliness',
                    'label': 'Shine',
                    'radius': 65,
                    'severity': 2,
                    'confidence': 0.8,
                  },
                ],
                'limitations': ['One image only'],
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('88'), findsOneWidget);
    expect(find.text('Photo quality looks good'), findsOneWidget);
    expect(find.text('Skin profile'), findsOneWidget);
    expect(find.text('Skin type: Oily'), findsOneWidget);
    expect(
      find.text('Visible shine suggests an oily skin type in these regions.'),
      findsOneWidget,
    );
    expect(find.text('Skin metrics'), findsOneWidget);
    expect(find.text('Acne'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.textContaining('80% confidence'), findsNWidgets(2));
    expect(find.textContaining('Not Visible'), findsOneWidget);
    expect(find.text('Face regions'), findsOneWidget);
    expect(find.text('Visible shine on the forehead area.'), findsOneWidget);
    expect(find.text('Visible Oiliness'), findsOneWidget);
    expect(
      find.textContaining('Image area: (345, 362) to (478, 645)'),
      findsOneWidget,
    );
    expect(find.text('Shine'), findsOneWidget);
    expect(find.textContaining('Image point: (503, 412)'), findsOneWidget);
    expect(find.text('Assessment limitations'), findsOneWidget);
    expect(find.text('One image only'), findsOneWidget);
    expect(find.text('Unlock your complete skin report'), findsNothing);
  });
}
