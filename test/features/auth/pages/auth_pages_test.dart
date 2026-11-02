import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/storage/auth_session_storage.dart';
import 'package:glown_scan_mobile/features/auth/pages/login_page.dart';
import 'package:glown_scan_mobile/features/auth/pages/register_page.dart';
import 'package:glown_scan_mobile/features/auth/pages/reset_password_page.dart';
import 'package:glown_scan_mobile/features/auth/services/auth_api.dart';

void main() {
  testWidgets('register validates password and shows resend after success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeAuthApi();
    await tester.pumpWidget(MaterialApp(home: RegisterPage(authApi: api)));

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'weak',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'weak',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    expect(api.registerCalls, 0);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Strong!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'Strong!',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(api.registerCalls, 1);
    expect(find.text('Resend verification email'), findsOneWidget);
    final disabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Account created'),
    );
    expect(disabledButton.onPressed, isNull);

    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();
    expect(api.verificationResendCalls, 1);
  });

  testWidgets('login sends Android FCM token and stores session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeAuthApi();
    final storage = _FakeAuthSessionStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          authApi: api,
          sessionStorage: storage,
          fcmTokenProvider: () async => 'device-fcm-token',
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Password!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(api.loginCalls, 1);
    expect(api.lastFcmToken, 'device-fcm-token');
    expect(api.lastPlatform, MobilePlatform.android);
    expect(storage.accessToken, 'access-token');
    expect(storage.refreshToken, 'refresh-token');
    expect(find.text('Care that starts with understanding.'), findsOneWidget);
  });

  testWidgets('Google login sends ID token and stores backend session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeAuthApi();
    final storage = _FakeAuthSessionStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          authApi: api,
          sessionStorage: storage,
          googleIdTokenProvider: () async => 'google-id-token',
          fcmTokenProvider: () async => 'google-fcm-token',
        ),
      ),
    );

    await tester.tap(find.text('Login with Google'));
    await tester.pumpAndSettle();

    expect(api.firebaseLoginCalls, 1);
    expect(api.lastIdToken, 'google-id-token');
    expect(api.lastFcmToken, 'google-fcm-token');
    expect(storage.accessToken, 'access-token');
    expect(storage.refreshToken, 'refresh-token');
    expect(find.text('Care that starts with understanding.'), findsOneWidget);
  });

  testWidgets('standard login disables other login controls while submitting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fcmToken = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          authApi: _FakeAuthApi(),
          sessionStorage: _FakeAuthSessionStore(),
          fcmTokenProvider: () => fcmToken.future,
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Password123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Email address'),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Password'))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Forgot your password?'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Create an account'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Login with Google'),
          )
          .onPressed,
      isNull,
    );

    fcmToken.complete('device-fcm-token');
    await tester.pumpAndSettle();
  });

  testWidgets('Google login disables other login controls while submitting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final googleIdToken = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          authApi: _FakeAuthApi(),
          sessionStorage: _FakeAuthSessionStore(),
          googleIdTokenProvider: () => googleIdToken.future,
        ),
      ),
    );
    await tester.tap(find.text('Login with Google'));
    await tester.pump();

    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Email address'),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Password'))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Forgot your password?'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Create an account'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    googleIdToken.complete('google-id-token');
    await tester.pumpAndSettle();
  });

  testWidgets('reset password sends, checks token, and resends email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeAuthApi();
    await tester.pumpWidget(MaterialApp(home: ResetPasswordPage(authApi: api)));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'user@example.com',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();
    expect(api.resetRequestCalls, 1);
    expect(find.text('Resend reset email'), findsOneWidget);
    expect(find.text('Check token'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email token'),
      'reset-token',
    );
    await tester.tap(find.text('Check token'));
    await tester.pumpAndSettle();
    expect(api.resetCheckCalls, 1);
    expect(
      find.text('The token was used successfully on the website.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Resend reset email'));
    await tester.pumpAndSettle();
    expect(api.resetResendCalls, 1);
  });
}

class _FakeAuthApi implements AuthApiContract {
  int registerCalls = 0;
  int loginCalls = 0;
  int firebaseLoginCalls = 0;
  int verificationResendCalls = 0;
  int resetRequestCalls = 0;
  int resetResendCalls = 0;
  int resetCheckCalls = 0;
  String? lastFcmToken;
  String? lastIdToken;
  MobilePlatform? lastPlatform;

  @override
  Future<ApiResponse> register({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    registerCalls++;
    return const ApiResponse(
      status: 201,
      message: 'Account created successfully',
      data: null,
    );
  }

  @override
  Future<ApiResponse> loginMobile({
    required String email,
    required String password,
    required String fcmToken,
    MobilePlatform platform = MobilePlatform.android,
  }) async {
    loginCalls++;
    lastFcmToken = fcmToken;
    lastPlatform = platform;
    return const ApiResponse(
      status: 200,
      message: 'Logged in successfully',
      data: {'accessToken': 'access-token', 'refreshToken': 'refresh-token'},
    );
  }

  @override
  Future<ApiResponse> firebaseLogin({
    required String idToken,
    required String fcmToken,
    MobilePlatform platform = MobilePlatform.android,
  }) async {
    firebaseLoginCalls++;
    lastIdToken = idToken;
    lastFcmToken = fcmToken;
    return const ApiResponse(
      status: 200,
      message: 'Logged in successfully',
      data: {'accessToken': 'access-token', 'refreshToken': 'refresh-token'},
    );
  }

  @override
  Future<ApiResponse> refresh({
    required String accessToken,
    required String refreshToken,
  }) async => const ApiResponse(
    status: 200,
    message: 'Tokens refreshed',
    data: {'accessToken': 'access-token', 'refreshToken': 'refresh-token'},
  );

  @override
  Future<ApiResponse> requestPasswordReset({required String email}) async {
    resetRequestCalls++;
    return const ApiResponse(
      status: 200,
      message: 'Password reset email sent',
      data: null,
    );
  }

  @override
  Future<ApiResponse> resendPasswordReset({required String email}) async {
    resetResendCalls++;
    return const ApiResponse(
      status: 200,
      message: 'Email sent again',
      data: null,
    );
  }

  @override
  Future<ApiResponse> resendEmailVerification({required String email}) async {
    verificationResendCalls++;
    return const ApiResponse(
      status: 200,
      message: 'Verification email sent again',
      data: null,
    );
  }

  @override
  Future<bool> checkPasswordReset({
    required String email,
    required String token,
  }) async {
    resetCheckCalls++;
    return true;
  }
}

class _FakeAuthSessionStore implements AuthSessionStore {
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
