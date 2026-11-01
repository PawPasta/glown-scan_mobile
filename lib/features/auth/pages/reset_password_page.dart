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
  late final AuthApiContract _authApi = widget.authApi ?? AuthApi();
  bool _isSending = false;
  bool _isChecking = false;
  bool _hasRequestedReset = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail({required bool resend}) async {
    if (!_formKey.currentState!.validate()) return;
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
    if (!_formKey.currentState!.validate()) return;
    if (_tokenController.text.trim().isEmpty) {
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
              ? 'The token was used successfully on the website.'
              : 'The token has not been used or is invalid.',
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

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      eyebrow: 'Account recovery',
      title: 'Reset your password',
      subtitle: _hasRequestedReset
          ? 'Enter the token from your email to check the reset status on the website.'
          : 'Enter your email address and we will send you a password reset link.',
      children: [
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
                OutlinedButton.icon(
                  onPressed: _isChecking ? null : _checkResetToken,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: const Text('Check token'),
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
    );
  }
}
