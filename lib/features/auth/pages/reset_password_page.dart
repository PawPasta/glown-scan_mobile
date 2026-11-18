import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../services/auth_api.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_page_frame.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({this.authApi, super.key});

  final AuthApiContract? authApi;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AuthApiContract _authApi = widget.authApi ?? AuthApi();
  bool _isSending = false;
  bool _isChecking = false;
  bool _isConfirming = false;
  bool _hasRequestedReset = false;
  bool _resetComplete = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail({required bool resend}) async {
    final emailError = AuthValidators.email(_emailController.text);
    if (emailError != null) {
      showAuthMessage(context, emailError, error: true);
      return;
    }
    setState(() => _isSending = true);
    try {
      final response = resend
          ? await _authApi.resendPasswordReset(
              email: _emailController.text.trim(),
            )
          : await _authApi.requestPasswordReset(
              email: _emailController.text.trim(),
            );
      if (!mounted) return;
      setState(() => _hasRequestedReset = true);
      showAuthMessage(context, response.message);
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkResetToken() async {
    final emailError = AuthValidators.email(_emailController.text);
    if (emailError != null) {
      showAuthMessage(context, emailError, error: true);
      return;
    }
    if (_tokenController.text.trim().length < 32) {
      showAuthMessage(context, 'Enter the token from your email.', error: true);
      return;
    }

    setState(() => _isChecking = true);
    try {
      final success = await _authApi.checkPasswordReset(
        email: _emailController.text.trim(),
        token: _tokenController.text.trim(),
      );
      if (mounted) {
        showAuthMessage(
          context,
          success
              ? 'This reset token has already been used.'
              : 'This reset token has not been used yet.',
          error: !success,
        );
      }
    } on ApiException catch (error) {
      if (mounted) showAuthMessage(context, error.message, error: true);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          'Could not check the token: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!_formKey.currentState!.validate()) return;
    final token = _tokenController.text.trim();
    if (token.length < 32) {
      showAuthMessage(
        context,
        'Enter the reset token from your email.',
        error: true,
      );
      return;
    }
    setState(() => _isConfirming = true);
    try {
      final response = await _authApi.confirmPasswordReset(
        email: _emailController.text.trim(),
        token: token,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _resetComplete = true);
      showAuthMessage(context, response.message);
    } on ApiException catch (error) {
      if (mounted) showAuthMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      eyebrow: 'Account recovery',
      title: _resetComplete ? 'Password updated' : 'Reset your password',
      subtitle: _resetComplete
          ? 'Your password has been reset. You can now sign in with the new password.'
          : _hasRequestedReset
          ? 'Enter the token from your email and choose a new password.'
          : 'Enter your email address and we will send you a password reset link.',
      children: [
        if (_resetComplete) ...[
          const Icon(Icons.check_circle_outline, size: 64),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
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
                  textInputAction: _hasRequestedReset
                      ? TextInputAction.next
                      : TextInputAction.done,
                  validator: AuthValidators.email,
                ),
                if (_hasRequestedReset) ...[
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _tokenController,
                    label: 'Email token',
                    icon: Icons.key_outlined,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _newPasswordController,
                    label: 'New password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: AuthValidators.password,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm new password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (value) => AuthValidators.confirmPassword(
                      value,
                      _newPasswordController.text,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AuthSubmitButton(
                  label: _hasRequestedReset
                      ? 'Resend reset email'
                      : 'Send reset email',
                  isLoading: _isSending,
                  onPressed: () => _sendResetEmail(resend: _hasRequestedReset),
                ),
                if (_hasRequestedReset) ...[
                  const SizedBox(height: 12),
                  AuthSubmitButton(
                    label: 'Set new password',
                    isLoading: _isConfirming,
                    onPressed: _confirmReset,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isChecking ? null : _checkResetToken,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: const Text('Check reset status'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to log in'),
          ),
        ],
      ],
    );
  }
}
