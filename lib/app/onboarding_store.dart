import 'package:shared_preferences/shared_preferences.dart';

/// 一次性上手提示的本地状态。
abstract class OnboardingStore {
  bool get hasSeenPerformanceHint;

  Future<void> markPerformanceHintSeen();
}

class SharedPreferencesOnboardingStore implements OnboardingStore {
  SharedPreferencesOnboardingStore(this._preferences);

  static const String performanceHintSeenKey =
      'onboarding.performance_hint_seen';

  final SharedPreferences _preferences;

  static Future<OnboardingStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesOnboardingStore(preferences);
  }

  @override
  bool get hasSeenPerformanceHint =>
      _preferences.getBool(performanceHintSeenKey) ?? false;

  @override
  Future<void> markPerformanceHintSeen() async {
    try {
      await _preferences.setBool(performanceHintSeenKey, true);
    } catch (_) {
      // 持久化失败不阻塞提示展示；最坏情况下下次登录再提示一次。
    }
  }
}

class InMemoryOnboardingStore implements OnboardingStore {
  InMemoryOnboardingStore([this._hasSeenPerformanceHint = false]);

  bool _hasSeenPerformanceHint;

  @override
  bool get hasSeenPerformanceHint => _hasSeenPerformanceHint;

  @override
  Future<void> markPerformanceHintSeen() async {
    _hasSeenPerformanceHint = true;
  }
}
