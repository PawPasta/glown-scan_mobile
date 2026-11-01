import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onCompleted, super.key});

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  static const _pages = [
    _OnboardingContent(
      eyebrow: 'CARE STARTS WITH UNDERSTANDING',
      title: 'Listen to your skin',
      description: 'GlowScan is building a more personal skincare experience, starting with your profile and the things that matter to you.',
      icon: Icons.face_3_outlined,
      accent: Color(0xFFF3DBE3),
      decorations: [
        _IconDecoration(Icons.auto_awesome, AppTheme.rose),
        _IconDecoration(Icons.favorite_border, AppTheme.roseHover),
        _IconDecoration(Icons.spa_outlined, AppTheme.deepRose),
      ],
      label: 'YOUR SKIN, YOUR STORY',
    ),
    _OnboardingContent(
      eyebrow: 'A LITTLE PROGRESS, EVERY DAY',
      title: 'Follow your skin journey',
      description: 'Upcoming analysis and tracking features will help you reflect on how your skin changes over time.',
      icon: Icons.monitor_heart_outlined,
      accent: Color(0xFFF3DBE3),
      decorations: [
        _IconDecoration(Icons.water_drop_outlined, AppTheme.roseHover),
        _IconDecoration(Icons.calendar_month_outlined, AppTheme.deepRose),
        _IconDecoration(Icons.auto_awesome, AppTheme.rose),
      ],
      label: 'A JOURNEY, NOT A RACE',
    ),
    _OnboardingContent(
      eyebrow: 'MAKE YOUR ROUTINE SIMPLER',
      title: 'Care with intention',
      description: 'Explore routines and product recommendations when these features arrive in GlowScan.',
      icon: Icons.spa_outlined,
      accent: Color(0xFFF3DBE3),
      decorations: [
        _IconDecoration(Icons.water_drop_outlined, AppTheme.rose),
        _IconDecoration(Icons.wb_sunny_outlined, AppTheme.roseHover),
        _IconDecoration(Icons.favorite_border, AppTheme.deepRose),
      ],
      label: 'CARE WITH CONFIDENCE',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      await widget.onCompleted();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save your choice: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  void _goToNextPage() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.spa_outlined, size: 25),
                  const SizedBox(width: 8),
                  Text(
                    'GlowScan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isCompleting ? null : _completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return _OnboardingSlide(content: _pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        width: index == _currentPage ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isCompleting ? null : _goToNextPage,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(156, 52),
                    ),
                    child: _isCompleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'Get started'
                                    : 'Continue',
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.content});

  final _OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationHeight = (constraints.maxHeight * 0.48)
            .clamp(210.0, 330.0)
            .toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingIllustration(
                content: content,
                height: illustrationHeight,
              ),
              const SizedBox(height: 32),
              Text(
                content.eyebrow,
                style: textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content.title,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content.description,
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.content, required this.height});

  final _OnboardingContent content;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: content.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -50,
            right: -24,
            child: _DecorativeCircle(
              size: 150,
              color: AppTheme.paper.withValues(alpha: 0.24),
            ),
          ),
          Positioned(
            left: -48,
            bottom: -70,
            child: _DecorativeCircle(
              size: 190,
              color: AppTheme.rose.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              color: AppTheme.paper.withValues(alpha: 0.88),
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, size: 92, color: colorScheme.primary),
          ),
          Positioned(
            top: height * 0.16,
            left: 30,
            child: _FloatingIcon(decoration: content.decorations[0]),
          ),
          Positioned(
            top: height * 0.2,
            right: 30,
            child: _FloatingIcon(decoration: content.decorations[1]),
          ),
          Positioned(
            bottom: height * 0.24,
            left: 42,
            child: _FloatingIcon(decoration: content.decorations[2], size: 40),
          ),
          Positioned(
            right: 34,
            bottom: height * 0.23,
            child: Icon(
              Icons.bubble_chart_outlined,
              size: 28,
              color: AppTheme.roseHover,
            ),
          ),
          Positioned(
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.paper.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                content.label,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.decoration, this.size = 46});

  final _IconDecoration decoration;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.paper.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: Icon(decoration.icon, color: decoration.color, size: size * 0.48),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.decorations,
    required this.label,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final List<_IconDecoration> decorations;
  final String label;
}

class _IconDecoration {
  const _IconDecoration(this.icon, this.color);

  final IconData icon;
  final Color color;
}
