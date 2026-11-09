import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('性能提示默认未看过，落盘后重建仍为已看过', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    var store = await SharedPreferencesOnboardingStore.create();
    expect(store.hasSeenPerformanceHint, isFalse);

    await store.markPerformanceHintSeen();
    store = await SharedPreferencesOnboardingStore.create();
    expect(store.hasSeenPerformanceHint, isTrue);
  });

  test('内存实现记录是否已经看过性能提示', () async {
    final store = InMemoryOnboardingStore();
    expect(store.hasSeenPerformanceHint, isFalse);

    await store.markPerformanceHintSeen();
    expect(store.hasSeenPerformanceHint, isTrue);
  });
}
