import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';

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

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('订阅变更广播到达时就地补丁，不重拉列表', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/view-history',
      body: <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'entity_type': 'movie',
            'viewed_at': '2026-05-08T10:00:00',
            'movie': <String, dynamic>{
              'id': 11,
              'movie_number': 'ABC-001',
              'title': 'Movie 1',
              'cover_image': null,
              'thin_cover_image': null,
              'release_date': '2026-05-01',
              'duration_minutes': 120,
              'heat': 0,
              'is_subscribed': false,
              'can_play': false,
              'media_items': <dynamic>[],
            },
            'actor': null,
          },
          <String, dynamic>{
            'entity_type': 'actor',
            'viewed_at': '2026-05-08T09:00:00',
            'actor': <String, dynamic>{
              'id': 3,
              'name': 'Actor A',
              'alias_name': '',
              'display_name': 'Actor A',
              'profile_image': null,
              'is_subscribed': false,
              'movie_count': 1,
            },
            'movie': null,
          },
        ],
      },
    );
    final subscription = container.listen(
      recentViewsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final entries = await container.read(recentViewsProvider.future);
    expect(entries, hasLength(2));

    container
        .read(movieSubscriptionEventsProvider.notifier)
        .reportChange(movieNumber: 'ABC-001', isSubscribed: true);
    container
        .read(actorSubscriptionEventsProvider.notifier)
        .reportChange(actorId: 3, isSubscribed: true);
    await settle();

    final patched = container.read(recentViewsProvider).requireValue;
    expect(patched[0].movie?.isSubscribed, isTrue);
    expect(patched[1].actor?.isSubscribed, isTrue);
    // 就地补丁，不触发整页重拉。
    expect(bundle.adapter.hitCount('GET', '/view-history'), 1);
  });
}
