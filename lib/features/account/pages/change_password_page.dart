import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/utils/auth_validators.dart';
import '../../auth/widgets/auth_page_frame.dart';
import '../services/account_api.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({this.accountApi, super.key});

  final AccountApiContract? accountApi;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AccountApiContract _accountApi = widget.accountApi ?? AccountApi();
  bool _isSubmitting = false;
  bool _hideOldPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    if (widget.accountApi == null && _accountApi is AccountApi) {
      _accountApi.close();
    }
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _accountApi.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      showAuthMessage(context, 'Password changed successfully.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) showAuthMessage(context, error.message, error: true);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          'Could not change your password: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthPageFrame(
    eyebrow: 'Account security',
    title: 'Change password',
    subtitle: 'Enter your current password and choose a new one.',
    children: [
      Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _oldPasswordController,
              obscureText: _hideOldPassword,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hideOldPassword
                      ? 'Show current password'
                      : 'Hide current password',
                  onPressed: () {
                    setState(() => _hideOldPassword = !_hideOldPassword);
                  },
                  icon: Icon(
                    _hideOldPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your current password.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _hideNewPassword,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  tooltip: _hideNewPassword
                      ? 'Show new password'
                      : 'Hide new password',
                  onPressed: () {
                    setState(() => _hideNewPassword = !_hideNewPassword);
                  },
                  icon: Icon(
                    _hideNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _hideConfirmPassword,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _changePassword(),
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hideConfirmPassword
                      ? 'Show confirmation'
                      : 'Hide confirmation',
                  onPressed: () {
                    setState(
                      () => _hideConfirmPassword = !_hideConfirmPassword,
                    );
                  },
                  icon: Icon(
                    _hideConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => AuthValidators.confirmPassword(
                value,
                _newPasswordController.text,
              ),
            ),
            const SizedBox(height: 20),
            AuthSubmitButton(
              label: 'Update password',
              onPressed: _changePassword,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    ],
  );
}
