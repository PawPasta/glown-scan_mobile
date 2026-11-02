import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/auth_request_status.dart';
import 'package:glown_scan_mobile/core/storage/auth_session_storage.dart';
import 'package:glown_scan_mobile/features/auth/services/auth_session_service.dart';
import 'package:glown_scan_mobile/main.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows all onboarding pages and remembers completion', (
    tester,
  ) async {
    final sessionService = _noSessionService();
    addTearDown(sessionService.close);
    await tester.pumpWidget(MyApp(sessionService: sessionService));
    await tester.pumpAndSettle();

    expect(find.text('Listen to your skin'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Follow your skin journey'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Care with intention'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_completed'), isTrue);

    await tester.pumpWidget(MyApp(sessionService: sessionService));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });

  testWidgets('skip completes onboarding', (tester) async {
    final sessionService = _noSessionService();
    addTearDown(sessionService.close);
    await tester.pumpWidget(MyApp(sessionService: sessionService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });

  testWidgets('restores a valid saved session directly to Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final storage = _MemoryAuthSessionStore()
      ..accessToken = _tokenWithExpiration(
        DateTime.now().add(const Duration(hours: 1)),
      )
      ..refreshToken = 'refresh-token';
    final sessionService = AuthSessionService(
      sessionStorage: storage,
      apiClient: ApiClient(
        baseUri: Uri.parse('https://example.test'),
        httpClient: MockClient(
          (_) async => throw StateError('Unexpected call'),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: AppStartupGate(sessionService: sessionService)),
    );
    await tester.pumpAndSettle();
    addTearDown(sessionService.close);

    expect(find.text('Care that starts with understanding.'), findsOneWidget);
    expect(find.text('Restoring your session...'), findsNothing);
  });

  testWidgets('shows refresh loading and routes expired sessions to Login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final storage = _MemoryAuthSessionStore()
      ..accessToken = _tokenWithExpiration(
        DateTime.now().add(const Duration(hours: 1)),
      )
      ..refreshToken = 'refresh-token';
    final sessionService = AuthSessionService(
      sessionStorage: storage,
      apiClient: ApiClient(
        baseUri: Uri.parse('https://example.test'),
        httpClient: MockClient(
          (_) async => throw StateError('Unexpected call'),
        ),
      ),
    );
    addTearDown(sessionService.close);

    await tester.pumpWidget(MyApp(sessionService: sessionService));
    await tester.pumpAndSettle();
    expect(find.text('Care that starts with understanding.'), findsOneWidget);

    AuthRequestStatus.instance.beginRefresh();
    await tester.pump();
    expect(find.text('Refreshing your session...'), findsOneWidget);
    AuthRequestStatus.instance.endRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Refreshing your session...'), findsNothing);

    AuthRequestStatus.instance.expireSession();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });
}

AuthSessionService _noSessionService() => AuthSessionService(
  sessionStorage: _MemoryAuthSessionStore(),
  apiClient: ApiClient(
    baseUri: Uri.parse('https://example.test'),
    httpClient: MockClient((_) async => throw StateError('Unexpected call')),
  ),
);

String _tokenWithExpiration(DateTime expiration) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'exp': expiration.millisecondsSinceEpoch ~/ 1000}),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

class _MemoryAuthSessionStore implements AuthSessionStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}
