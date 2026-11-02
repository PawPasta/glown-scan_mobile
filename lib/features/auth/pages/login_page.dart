import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_session_storage.dart';
import '../../home/pages/home_page.dart';
import '../../notifications/services/push_notification_service.dart';
import '../services/auth_api.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_page_frame.dart';
import 'register_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    this.authApi,
    this.sessionStorage,
    this.fcmTokenProvider,
    this.googleIdTokenProvider,
    super.key,
  });

  final AuthApiContract? authApi;
  final AuthSessionStore? sessionStorage;
  final Future<String?> Function()? fcmTokenProvider;
  final Future<String?> Function()? googleIdTokenProvider;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthApiContract _authApi = widget.authApi ?? AuthApi();
  late final AuthSessionStore _sessionStorage =
      widget.sessionStorage ?? AuthSessionStorage();
  bool _isSubmitting = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final fcmToken =
          await (widget.fcmTokenProvider ??
              PushNotificationService.instance.getToken)();
      if (fcmToken == null || fcmToken.isEmpty) {
        throw const ApiException(
          'Could not get an FCM token. Allow notifications and try again.',
        );
      }

      final response = await _authApi.loginMobile(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fcmToken: fcmToken,
      );
      final tokens = _readTokens(response.data);
      await _sessionStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      if (!mounted) return;
      showAuthMessage(context, response.message);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
    } on ApiException catch (error) {
      if (mounted) showAuthMessage(context, error.message, error: true);
    } catch (error) {
      if (mounted) {
        showAuthMessage(context, 'Could not log in: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isSubmitting = true);
    try {
      final String? idToken;
      final provider = widget.googleIdTokenProvider;
      if (provider != null) {
        idToken = await provider();
      } else {
        final account = await GoogleSignIn().signIn();
        if (account == null) return;

        final authentication = await account.authentication;
        if (authentication.idToken == null || authentication.idToken!.isEmpty) {
          throw const ApiException('Could not get a Google ID token.');
        }

        final firebaseCredential = GoogleAuthProvider.credential(
          idToken: authentication.idToken,
          accessToken: authentication.accessToken,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          firebaseCredential,
        );
        final user = userCredential.user;
        if (user == null) {
          throw const ApiException(
            'Firebase sign-in completed without a user account.',
          );
        }

        idToken = await user.getIdToken();
      }

      if (idToken == null || idToken.isEmpty) {
        throw const ApiException('Could not get a Firebase ID token.');
      }

      final fcmToken =
          await (widget.fcmTokenProvider ??
              PushNotificationService.instance.getToken)();
      if (fcmToken == null || fcmToken.isEmpty) {
        throw const ApiException(
          'Could not get an FCM token. Allow notifications and try again.',
        );
      }

      final response = await _authApi.firebaseLogin(
        idToken: idToken,
        fcmToken: fcmToken,
      );
      final tokens = _readTokens(response.data);
      await _sessionStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      if (!mounted) return;
      showAuthMessage(context, response.message);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
    } on ApiException catch (error) {
      if (mounted) showAuthMessage(context, error.message, error: true);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          'Could not log in with Google: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  _AuthTokens _readTokens(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        'The login response is missing an access token.',
      );
    }
    final nestedTokens = data['tokens'];
    final tokenData = nestedTokens is Map<String, dynamic>
        ? nestedTokens
        : data;
    final accessToken = tokenData['accessToken'];
    final refreshToken = tokenData['refreshToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const ApiException(
        'The login response is missing an access token.',
      );
    }
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const ApiException(
        'The login response is missing a refresh token.',
      );
    }
    return _AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      eyebrow: 'Welcome back',
      title: 'Log in',
      subtitle: 'Log in to continue your skincare journey.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                controller: _emailController,
                label: 'Email address',
                icon: Icons.mail_outline,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.done,
                validator: AuthValidators.password,
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _openPage(
                          ResetPasswordPage(authApi: widget.authApi),
                        ),
                  child: const Text('Forgot your password?'),
                ),
              ),
              const SizedBox(height: 12),
              AuthSubmitButton(
                label: 'Log in',
                isLoading: _isSubmitting,
                onPressed: _login,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Login with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "Don't have an account?",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _openPage(RegisterPage(authApi: widget.authApi)),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuthTokens {
  const _AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}
