import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';

import 'test_api_bundle.dart';

/// 0-2 快速回归：TestApiBundle.riverpodOverrides() 补齐的 override
/// 必须全部可读且不抛——widget 测试树里凡是读这些 provider 的消费方都不再
/// 撞 UnimplementedError。
///
/// 批 8 后：四个 mutation broadcaster 本体化为 Riverpod class Notifier
/// (`xxxEventsProvider`)、不再由 bundle 注入实例，故本回归不再覆盖它们。
void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  test('riverpodOverrides 补齐的 provider 均可用且身份唯一', () {
    final container = ProviderContainer(overrides: bundle.riverpodOverrides());
    addTearDown(container.dispose);

    // externalPlayerPreference 已迁 AsyncNotifier 且不再由 bundle 注入,
    // 无 SharedPreferences mock 时读盘异常被吞、降级为「未选择」。
    expect(
      container.read(collectionPlaybackHandoffProvider),
      same(bundle.collectionPlaybackHandoff),
    );
  });
}
