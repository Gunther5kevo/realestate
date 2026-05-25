import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/onboarding_provider.dart';

// Must be a ConsumerStatefulWidget so we have access to `ref` for
// calling completeOnboarding() before navigating away.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _isCompleting = false;

  final _pages = [
    const _OnboardPage(
      emoji: '🏡',
      title: 'Find Your Dream Home',
      subtitle:
          'Browse thousands of verified properties across Kenya with advanced search and filters.',
      bg: AppTheme.primarySurface,
    ),
    const _OnboardPage(
      emoji: '📍',
      title: 'Map-Based Search',
      subtitle:
          'Explore properties on an interactive map and discover your ideal neighbourhood.',
      bg: AppTheme.accentSurface,
    ),
    const _OnboardPage(
      emoji: '🔑',
      title: 'Book & Pay Securely',
      subtitle:
          'Schedule viewings, make reservations, and pay via M-Pesa or card — all in one place.',
      bg: AppTheme.warningSurface,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Persists the onboarding-completed flag then navigates to login.
  /// The flag must be saved BEFORE navigating — otherwise the router's
  /// redirect fires with hasSeenOnboarding = false and immediately sends
  /// the user back to /onboarding.
  Future<void> _finish() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await completeOnboarding(ref);
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button top right
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: _page < _pages.length - 1
                    ? TextButton(
                        onPressed: _isCompleting ? null : _finish,
                        child: Text(
                          'Skip',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      )
                    : const SizedBox(height: 40),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      dotColor: AppTheme.border,
                      activeDotColor: AppTheme.primary,
                      dotHeight: 6,
                      dotWidth: 6,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCompleting
                          ? null
                          : () {
                              if (_page < _pages.length - 1) {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.ease,
                                );
                              } else {
                                _finish();
                              }
                            },
                      child: _isCompleting && _page == _pages.length - 1
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _page < _pages.length - 1 ? 'Next' : 'Get Started',
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isCompleting ? null : _finish,
                    child: const Text('Already have an account? Sign in'),
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

class _OnboardPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bg;

  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 60)),
            ),
          )
              .animate()
              .scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 48),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }
}