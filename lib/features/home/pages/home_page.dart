import 'package:flutter/material.dart';

import '../../../core/storage/auth_session_storage.dart';
import '../../auth/pages/login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({this.sessionStorage, super.key});

  final AuthSessionStore? sessionStorage;

  Future<void> _logout(BuildContext context) async {
    await (sessionStorage ?? AuthSessionStorage()).clear();
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GlowScan'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.spa_outlined, size: 48),
                SizedBox(height: 16),
                Text(
                  'Welcome to GlowScan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'More features are on the way.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
