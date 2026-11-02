import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/network/auth_request_status.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/services/auth_session_service.dart';
import 'features/home/pages/home_page.dart';
import 'features/notifications/services/push_notification_service.dart';
import 'features/onboarding/pages/onboarding_page.dart';
import 'features/onboarding/services/onboarding_preferences.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.local');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
  unawaited(PushNotificationService.instance.initialize());
}

class MyApp extends StatelessWidget {
  const MyApp({this.sessionService, super.key});

  final AuthSessionService? sessionService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _appNavigatorKey,
      title: 'GlowScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          _AuthRequestOverlay(child: child ?? const SizedBox.shrink()),
      home: AppStartupGate(sessionService: sessionService),
    );
  }
}

final _appNavigatorKey = GlobalKey<NavigatorState>();

class _AuthRequestOverlay extends StatefulWidget {
  const _AuthRequestOverlay({required this.child});

  final Widget child;

  @override
  State<_AuthRequestOverlay> createState() => _AuthRequestOverlayState();
}

class _AuthRequestOverlayState extends State<_AuthRequestOverlay> {
  final _requestStatus = AuthRequestStatus.instance;
  late int _handledExpirationVersion = _requestStatus.sessionExpirationVersion;

  @override
  void initState() {
    super.initState();
    _requestStatus.addListener(_handleRequestStatus);
  }

  @override
  void dispose() {
    _requestStatus.removeListener(_handleRequestStatus);
    super.dispose();
  }

  void _handleRequestStatus() {
    final version = _requestStatus.sessionExpirationVersion;
    if (version <= _handledExpirationVersion) return;
    _handledExpirationVersion = version;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _requestStatus,
    builder: (context, _) => Stack(
      children: [
        widget.child,
        if (_requestStatus.isRefreshing)
          Positioned.fill(
            child: Stack(
              children: [
                const ModalBarrier(
                  dismissible: false,
                  color: Color(0x66000000),
                ),
                Center(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Refreshing your session',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.paper,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.softBorder),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Refreshing your session...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({this.sessionService, super.key});

  final AuthSessionService? sessionService;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  late final AuthSessionService _sessionService =
      widget.sessionService ?? AuthSessionService();
  late Future<_StartupDestination> _startup = _resolveStartup();

  @override
  void dispose() {
    if (widget.sessionService == null) _sessionService.close();
    super.dispose();
  }

  Future<_StartupDestination> _resolveStartup() async {
    final onboardingCompleted = await OnboardingPreferences.hasCompleted();
    if (!onboardingCompleted) return _StartupDestination.onboarding;
    return _resolveSession();
  }

  Future<_StartupDestination> _resolveSession() async =>
      await _sessionService.restoreSession()
      ? _StartupDestination.home
      : _StartupDestination.login;

  Future<void> _completeOnboarding() async {
    await OnboardingPreferences.markCompleted();
    if (!mounted) return;
    setState(() {
      _startup = _resolveSession();
    });
  }

  void _retryStartup() {
    setState(() {
      _startup = _resolveStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupDestination>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupErrorPage(
            error: snapshot.error,
            onRetry: _retryStartup,
          );
        }
        if (!snapshot.hasData) {
          return const _StartupLoadingPage();
        }
        return switch (snapshot.data!) {
          _StartupDestination.home => const HomePage(),
          _StartupDestination.login => const LoginPage(),
          _StartupDestination.onboarding => OnboardingPage(
            onCompleted: _completeOnboarding,
          ),
        };
      },
    );
  }
}

enum _StartupDestination { onboarding, login, home }

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring your session...'),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Your session could not be verified. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
