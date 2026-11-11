import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore session;
  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime(2099),
    );
    bundle = await createTestApiBundle(session);
    container = ProviderContainer(overrides: bundle.riverpodOverrides());
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    session.dispose();
  });

  test('loads taste profile and patches subscription in place', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/taste-profile',
      body: _profileJson(),
    );

    final profile = await container.read(tasteProfileProvider.future);

    expect(profile.sampleMovieCount, 42);
    expect(profile.unsubscribedActresses.single.actor.id, 2);

    container
        .read(tasteProfileProvider.notifier)
        .applySubscription(actorId: 2, isSubscribed: true);

    final patched = container.read(tasteProfileProvider).requireValue;
    expect(patched.unsubscribedActresses.single.actor.id, 2);
    expect(patched.unsubscribedActresses.single.actor.isSubscribed, isTrue);
    expect(patched.subscribedActresses.single.actor.id, 1);
    expect(bundle.adapter.hitCount('GET', '/taste-profile'), 1);
  });

  test('subscription events patch the profile without a refetch', () async {
    // 页面上的面板会 watch 这个 provider；没有监听者时 Riverpod 会暂停它。
    container.listen(tasteProfileProvider, (_, __) {});
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/taste-profile',
      body: _profileJson(),
    );
    await container.read(tasteProfileProvider.future);

    container
        .read(actorSubscriptionEventsProvider.notifier)
        .reportChange(actorId: 2, isSubscribed: true);
    await pumpEventQueue();

    final patched = container.read(tasteProfileProvider).requireValue;
    expect(patched.unsubscribedActresses.single.actor.id, 2);
    expect(patched.unsubscribedActresses.single.actor.isSubscribed, isTrue);
    expect(patched.subscribedActresses.single.actor.id, 1);
    expect(bundle.adapter.hitCount('GET', '/taste-profile'), 1);
  });

  test('refresh keeps previous data when the request fails', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/taste-profile',
      body: _profileJson(),
    );
    final loaded = await container.read(tasteProfileProvider.future);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/taste-profile',
      statusCode: 500,
      body: <String, dynamic>{'message': 'boom'},
    );

    final error = await container.read(tasteProfileProvider.notifier).refresh();

    expect(error, isNotNull);
    expect(container.read(tasteProfileProvider).requireValue, same(loaded));
  });
}

Map<String, dynamic> _profileJson() {
  return <String, dynamic>{
    'sample_movie_count': 42,
    'actresses': <dynamic>[
      _actressJson(id: 1, name: '女优 A', isSubscribed: true),
      _actressJson(id: 2, name: '女优 B', isSubscribed: false),
    ],
    'unsubscribed_actresses': <dynamic>[
      _actressJson(id: 2, name: '女优 B', isSubscribed: false),
    ],
    'tags': <dynamic>[
      <String, dynamic>{'tag_id': 7, 'name': '剧情', 'matched_movie_count': 9},
    ],
  };
}

Map<String, dynamic> _actressJson({
  required int id,
  required String name,
  required bool isSubscribed,
}) {
  return <String, dynamic>{
    'actor': <String, dynamic>{
      'id': id,
      'name': name,
      'alias_name': '',
      'display_name': name,
      'is_subscribed': isSubscribed,
    },
    'matched_movie_count': id == 1 ? 12 : 5,
  };
}
