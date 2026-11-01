import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  OnboardingPreferences._();

  static const _completedKey = 'onboarding_completed';

  static Future<bool> hasCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_completedKey, true);
    if (!saved) {
      throw StateError('Could not save onboarding completion.');
    }
  }
}
