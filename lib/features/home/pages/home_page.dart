import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_session_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/pages/account_page.dart';
import '../../auth/pages/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({this.sessionStorage, super.key});

  final AuthSessionStore? sessionStorage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _titles = ['Home', 'Analysis', 'Camera', 'Routine', 'Account'];
  int _selectedIndex = 0;

  Future<void> _logout() async {
    final sessionStorage = widget.sessionStorage ?? AuthSessionStorage();
    final messenger = ScaffoldMessenger.of(context);
    String? logoutWarning;
    final apiClient = ApiClient();
    try {
      final refreshToken = await sessionStorage.readRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await apiClient.post(
          ApiEndpoints.logout,
          json: {'refreshToken': refreshToken},
          accessToken: await sessionStorage.readAccessToken(),
          requiresAuth: true,
        );
      }
    } catch (error) {
      logoutWarning = 'Server sign-out failed: $error';
    } finally {
      apiClient.close();
      await sessionStorage.clear();
    }

    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
    if (logoutWarning != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Signed out on this device. $logoutWarning')),
      );
    }
  }

  Widget _bodyForSelectedTab() => switch (_selectedIndex) {
    0 => const _HomeOverview(),
    1 => const _ComingSoonPage(
      icon: Icons.face_retouching_natural_outlined,
      title: 'Analysis',
      description: 'Photo analysis and skin history will be available when the backend workflow is ready.',
    ),
    2 => const _ComingSoonPage(
      icon: Icons.camera_alt_outlined,
      title: 'Camera',
      description:
          'Camera-based skin analysis is planned, but is not available yet.',
    ),
    3 => const _ComingSoonPage(
      icon: Icons.spa_outlined,
      title: 'Your routine',
      description: 'Morning and evening routines will appear here when routine tracking is available.',
    ),
    4 => AccountPage(onLogout: _logout),
    _ => const _HomeOverview(),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_titles[_selectedIndex]),
      centerTitle: _selectedIndex == 0,
    ),
    body: SafeArea(child: _bodyForSelectedTab()),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.face_retouching_natural_outlined),
          selectedIcon: Icon(Icons.face_retouching_natural),
          label: 'Analysis',
        ),
        NavigationDestination(
          icon: _CameraTabIcon(selected: false),
          selectedIcon: _CameraTabIcon(selected: true),
          label: 'Camera',
        ),
        NavigationDestination(
          icon: Icon(Icons.spa_outlined),
          selectedIcon: Icon(Icons.spa_rounded),
          label: 'Routine',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Account',
        ),
      ],
    ),
  );
}

class _CameraTabIcon extends StatelessWidget {
  const _CameraTabIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: selected ? AppTheme.deepRose : AppTheme.rose,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.camera_alt_rounded,
      color: AppTheme.paper,
      size: 22,
    ),
  );
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    children: [
      Text(
        'Care that starts with understanding.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      Text(
        'Your personal space for learning about your skin and building a thoughtful routine.',
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AppTheme.mutedText),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.sand,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.softBorder),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined, color: AppTheme.deepRose),
            SizedBox(height: 14),
            Text(
              'Your skin journey',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'GlowScan is building tools to help you understand your skin, explore personalized care, and follow your progress.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text('Coming into focus', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const _HomeFeatureRow(
        icon: Icons.face_retouching_natural_outlined,
        title: 'Skin analysis',
        subtitle: 'Understand your skin and track changes over time.',
      ),
      const SizedBox(height: 12),
      const _HomeFeatureRow(
        icon: Icons.spa_outlined,
        title: 'Personal routines',
        subtitle: 'Build simple morning and evening care habits.',
      ),
      const SizedBox(height: 12),
      const _HomeFeatureRow(
        icon: Icons.shopping_bag_outlined,
        title: 'Product discoveries',
        subtitle: 'Explore recommendations shaped around your skin profile.',
      ),
      const SizedBox(height: 16),
      Text(
        'These skincare features are not available yet.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _HomeFeatureRow extends StatelessWidget {
  const _HomeFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDFD),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.softBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.deepRose),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.deepRose),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
