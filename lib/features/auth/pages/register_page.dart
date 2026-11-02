import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../services/auth_api.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_page_frame.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({this.authApi, super.key});

  final AuthApiContract? authApi;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AuthApiContract _authApi = widget.authApi ?? AuthApi();
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _isRegistered = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isRegistered || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final response = await _authApi.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _isRegistered = true);
      showAuthMessage(context, response.message);
    } on ApiException catch (error) {
      if (mounted) showAuthMessage(context, error.message, error: true);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          'Could not create your account: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    try {
      final response = await _authApi.resendEmailVerification(
        email: _emailController.text.trim(),
      );
      if (mounted) showAuthMessage(context, response.message);
    } on ApiException catch (error) {
      if (mounted) showAuthMessage(context, error.message, error: true);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          'Could not send the email: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _backToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(authApi: widget.authApi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      eyebrow: _isRegistered ? 'Verify your email' : 'Start your journey',
      title: _isRegistered ? 'Check your email' : 'Create an account',
      subtitle: _isRegistered
          ? 'We sent a verification link to ${_emailController.text.trim()}.'
          : 'Create an account to start a skincare routine tailored to you.',
      children: [
        if (_isRegistered) ...[
          const Icon(
            Icons.mark_email_read_outlined,
            size: 68,
            color: Color(0xFFC76D88),
          ),
          const SizedBox(height: 20),
          AuthSubmitButton(label: 'Account created', onPressed: null),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isResending ? null : _resendVerification,
            icon: _isResending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mark_email_unread_outlined),
            label: const Text('Resend verification email'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _backToLogin,
            child: const Text('Back to log in'),
          ),
        ] else ...[
          Form(
            key: _formKey,
            child: Column(
              children: [
                AuthTextField(
                  controller: _emailController,
                  label: 'Email address',
                  icon: Icons.mail_outline,
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
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  icon: Icons.lock_reset_outlined,
                  obscureText: _hideConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: (value) => AuthValidators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                  suffix: IconButton(
                    tooltip: _hideConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () => setState(
                      () => _hideConfirmPassword = !_hideConfirmPassword,
                    ),
                    icon: Icon(
                      _hideConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Use at least 6 characters, including an uppercase letter, '
                    'a lowercase letter, and a special character.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AuthSubmitButton(
                  label: 'Create account',
                  isLoading: _isSubmitting,
                  onPressed: _isRegistered ? null : _register,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _backToLogin,
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ],
    );
  }
}
