import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/pages/login_page.dart';
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlowScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppStartupGate(),
    );
  }
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  late Future<bool> _startup = OnboardingPreferences.hasCompleted();

  Future<void> _completeOnboarding() async {
    await OnboardingPreferences.markCompleted();
    if (!mounted) return;
    setState(() {
      _startup = Future<bool>.value(true);
    });
  }

  void _retryStartup() {
    setState(() {
      _startup = OnboardingPreferences.hasCompleted();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupErrorPage(onRetry: _retryStartup);
        }
        if (!snapshot.hasData) {
          return const _StartupLoadingPage();
        }
        if (snapshot.data!) {
          return const LoginPage();
        }
        return OnboardingPage(onCompleted: _completeOnboarding);
      },
    );
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.onRetry});

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
                'The app could not start. Please try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
