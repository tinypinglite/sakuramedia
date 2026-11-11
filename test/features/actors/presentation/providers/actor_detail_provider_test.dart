import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_detail_provider.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: bundle.riverpodOverrides(),
      retry: null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
  });

  test('refresh updates actor detail after initial load', () async {
    bundle.adapter
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorJson('Old actor'),
      )
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorJson('New actor'),
      );
    final subscription = container.listen(
      actorDetailProvider(1),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      (await container.read(actorDetailProvider(1).future)).actor?.summary.name,
      'Old actor',
    );
    await _waitForViewHistoryPosts(bundle, 1);
    // 首载上报一次浏览（fire-and-forget）。
    expect(bundle.adapter.hitCount('POST', '/view-history'), 1);
    final notifier = container.read(actorDetailProvider(1).notifier);
    await notifier.refresh();

    expect(
      container.read(actorDetailProvider(1)).requireValue.actor?.summary.name,
      'New actor',
    );
    // refresh 自身不上报（与 movie 详情一致）：后台同步也走 refresh，
    // 上报会污染「最近浏览」。页面手势刷新成功后显式调 reportView()。
    expect(bundle.adapter.hitCount('POST', '/view-history'), 1);

    notifier.reportView();
    await _waitForViewHistoryPosts(bundle, 2);
    expect(bundle.adapter.hitCount('POST', '/view-history'), 2);
    expect(bundle.adapter.requests.last.body, <String, dynamic>{
      'entity_type': 'actor',
      'entity_id': 1,
    });
  });

  test('refresh rethrows and keeps existing actor on failure', () async {
    bundle.adapter
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorJson('Old actor'),
      )
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        statusCode: 500,
        body: <String, dynamic>{'error': 'server_error'},
      );
    final subscription = container.listen(
      actorDetailProvider(1),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(actorDetailProvider(1).future);

    await expectLater(
      container.read(actorDetailProvider(1).notifier).refresh(),
      throwsA(isA<Object>()),
    );

    expect(
      container.read(actorDetailProvider(1)).requireValue.actor?.summary.name,
      'Old actor',
    );
  });
}

Future<void> _waitForViewHistoryPosts(
  TestApiBundle bundle,
  int expected,
) async {
  for (
    var attempt = 0;
    attempt < 100 &&
        bundle.adapter.hitCount('POST', '/view-history') < expected;
    attempt++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Map<String, dynamic> _actorJson(String name) => <String, dynamic>{
  'id': 1,
  'name': name,
  'alias_name': '',
  'profile_image': null,
  'is_subscribed': false,
};
