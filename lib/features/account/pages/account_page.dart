import 'package:flutter/material.dart';

import '../services/account_api.dart';
import 'change_password_page.dart';
import 'profile_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({required this.onLogout, this.accountApi, super.key});

  final VoidCallback onLogout;
  final AccountApiContract? accountApi;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final AccountApiContract _accountApi = widget.accountApi ?? AccountApi();

  @override
  void dispose() {
    if (widget.accountApi == null && _accountApi is AccountApi) {
      _accountApi.close();
    }
    super.dispose();
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _accountButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: isDestructive
          ? Theme.of(context).colorScheme.error
          : null,
      minimumSize: const Size.fromHeight(56),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      _accountButton(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        onPressed: () => _openPage(ProfilePage(accountApi: _accountApi)),
      ),
      const SizedBox(height: 12),
      _accountButton(
        icon: Icons.lock_outline_rounded,
        label: 'Change password',
        onPressed: () => _openPage(ChangePasswordPage(accountApi: _accountApi)),
      ),
      const SizedBox(height: 12),
      _accountButton(
        icon: Icons.logout_rounded,
        label: 'Log out',
        onPressed: widget.onLogout,
        isDestructive: true,
      ),
    ],
  );
}
