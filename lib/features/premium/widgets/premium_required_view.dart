import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PremiumRequiredView extends StatelessWidget {
  const PremiumRequiredView({
    required this.feature,
    this.compact = false,
    super.key,
  });

  final String feature;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 16 : 20),
    decoration: BoxDecoration(
      color: AppTheme.sand,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.softBorder),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.workspace_premium_outlined, color: AppTheme.deepRose),
        const SizedBox(height: 10),
        Text(
          'Premium access required',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'An active Premium subscription is needed to use $feature. Manage your subscription on the GlowScan website.',
        ),
      ],
    ),
  );
}
