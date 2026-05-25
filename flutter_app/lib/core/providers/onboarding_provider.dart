import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingKey = 'onboarding_completed';

/// Notifier that holds the onboarding-completed flag in memory after the
/// initial SharedPreferences read. This avoids repeated async reads and
/// prevents isLoading flickers that cause redirect loops in the router.
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingKey) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
    state = const AsyncData(true);
  }
}

final onboardingCompletedProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// Call this from OnboardingScreen when the user taps "Get Started" / "Skip".
Future<void> completeOnboarding(WidgetRef ref) async {
  await ref.read(onboardingCompletedProvider.notifier).complete();
}