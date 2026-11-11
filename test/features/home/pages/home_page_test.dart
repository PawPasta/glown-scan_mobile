import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/features/home/pages/home_page.dart';

void main() {
  testWidgets('camera tab explains that live face scanning needs Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(
        find.text('Live face scanning is currently available on Android.'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
