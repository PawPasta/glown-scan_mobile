import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/features/camera/widgets/face_scan_guide.dart';

void main() {
  testWidgets(
    'shows a green face outline and enables manual capture when stable',
    (tester) async {
      var captureCount = 0;
      const faceBounds = Rect.fromLTRB(.2, .1, .8, .9);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceScanGuide(
              preview: const ColoredBox(color: Colors.black),
              isInitializing: false,
              stableFrames: 6,
              stableFramesNeeded: 6,
              detectedFaceBounds: faceBounds,
              isCapturing: false,
              onTakePhoto: () => captureCount++,
            ),
          ),
        ),
      );

      expect(find.text('Take photo'), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('faceScanGuidePainter')),
                  )
                  .painter!
              as FaceScanPainter;
      expect(painter.faceBounds, faceBounds);
      expect(FaceScanPainter.faceDetectedColor, const Color(0xFF39E66B));

      await tester.pump();
      expect(
        captureCount,
        0,
        reason: 'Detection must never capture by itself.',
      );
      await tester.tap(find.byKey(const ValueKey('faceScanTakePhotoButton')));
      expect(captureCount, 1);
    },
  );

  testWidgets('hides capture action until a face is stable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FaceScanGuide(
            preview: ColoredBox(color: Colors.black),
            isInitializing: false,
            stableFrames: 2,
            stableFramesNeeded: 6,
            detectedFaceBounds: Rect.fromLTRB(.2, .1, .8, .9),
            isCapturing: false,
            onTakePhoto: _noOp,
          ),
        ),
      ),
    );

    expect(find.textContaining('Hold still'), findsOneWidget);
    expect(find.byKey(const ValueKey('faceScanTakePhotoButton')), findsNothing);
  });

  test('face guide is wider and taller like a face mask', () {
    final guide = FaceScanPainter.guideOvalRect(const Size(300, 400));

    expect(guide.width, 258);
    expect(guide.height, 360);
  });
}

void _noOp() {}
