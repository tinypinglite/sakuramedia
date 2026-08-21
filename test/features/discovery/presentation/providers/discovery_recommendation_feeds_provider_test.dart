import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_api_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_recommendation_feeds_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late DiscoveryApi discoveryApi;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-04T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    discoveryApi = DiscoveryApi(apiClient: apiClient);
    container = ProviderContainer(
      overrides: [discoveryApiProvider.overrideWithValue(discoveryApi)],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  group('DailyRecommendationFeed', () {
    test('loads first page with family pageSize and appends more', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/daily-recommendations',
        body: _dailyPage(page: 1, total: 25, start: 1, count: 24),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/daily-recommendations',
        body: _dailyPage(page: 2, total: 25, start: 25, count: 1),
      );

      final provider = dailyRecommendationFeedProvider(24);
      // autoDispose：挂监听者保活，避免两次 read 之间被释放重建。
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      await container.read(provider.notifier).loadMore();

      final paged = container.read(provider).requireValue;
      expect(paged.items, hasLength(25));
      expect(paged.total, 25);
      expect(paged.hasMore, isFalse);
      // family 参数透传为 page_size 查询参数。
      expect(adapter.requests.first.uri.queryParameters['page_size'], '24');
    });

    test('keeps loaded items after load more error', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/daily-recommendations',
        body: _dailyPage(page: 1, total: 25, start: 1, count: 24),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/daily-recommendations',
        statusCode: 500,
        body: <String, dynamic>{'detail': 'failed'},
      );

      final provider = dailyRecommendationFeedProvider(24);
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      await container.read(provider.notifier).loadMore();

      final paged = container.read(provider).requireValue;
      expect(paged.items, hasLength(24));
      expect(paged.loadMoreErrorMessage, '加载更多推荐影片失败，请点击重试');
      expect(paged.isLoadingMore, isFalse);
    });
  });

  group('MomentRecommendationFeed', () {
    test('adapts MomentRecommendationPageDto and appends more', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/moment-recommendations',
        body: _momentPage(page: 1, total: 19, start: 1, count: 18),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/moment-recommendations',
        body: _momentPage(page: 2, total: 19, start: 19, count: 1),
      );

      final provider = momentRecommendationFeedProvider(18);
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      await container.read(provider.notifier).loadMore();

      final paged = container.read(provider).requireValue;
      expect(paged.items, hasLength(19));
      expect(paged.items.first.recommendationId, 1);
      expect(paged.total, 19);
      expect(paged.hasMore, isFalse);
      expect(adapter.requests.first.uri.queryParameters['page_size'], '18');
    });
  });

  group('HotActressReleaseFeed', () {
    test('loads the paged new-release recommendations', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/hot-actress-releases',
        body: _hotActressPage(page: 1, total: 2, start: 1, count: 2),
      );

      final provider = hotActressReleaseFeedProvider(24);
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      final paged = container.read(provider).requireValue;
      expect(paged.items.map((item) => item.movie.movieNumber), [
        'HOT-001',
        'HOT-002',
      ]);
      expect(paged.items.first.hotActressName, '女优 1');
      expect(adapter.requests.single.uri.queryParameters['page_size'], '24');

      container
          .read(movieSubscriptionEventsProvider.notifier)
          .reportChange(movieNumber: 'HOT-001', isSubscribed: true);
      await pumpEventQueue();

      expect(
        container.read(provider).requireValue.items.first.movie.isSubscribed,
        isTrue,
      );
    });
  });
}

Map<String, dynamic> _dailyPage({
  required int page,
  required int total,
  required int start,
  required int count,
}) {
  return <String, dynamic>{
    'items': List<Map<String, dynamic>>.generate(count, (index) {
      final number = (start + index).toString().padLeft(3, '0');
      return <String, dynamic>{
        'javdb_id': 'abc-id-$number',
        'movie_number': 'ABC-$number',
        'title': 'Movie title $number',
        'is_subscribed': false,
        'can_play': true,
      };
    }),
    'page': page,
    'page_size': count,
    'total': total,
  };
}

Map<String, dynamic> _momentPage({
  required int page,
  required int total,
  required int start,
  required int count,
}) {
  return <String, dynamic>{
    'items': List<Map<String, dynamic>>.generate(count, (index) {
      final id = start + index;
      return <String, dynamic>{
        'recommendation_id': id,
        'rank': id,
        'score': 0.88,
        'strategy': 'visual',
        'reason': '与你收藏的时刻画面相似',
        'media_id': 100 + id,
        'thumbnail_id': 500 + id,
        'offset_seconds': 360,
        'image': null,
        'movie': <String, dynamic>{
          'javdb_id': 'abc-id-$id',
          'movie_number': 'ABC-$id',
          'title': 'Movie title $id',
          'is_subscribed': false,
          'can_play': true,
        },
      };
    }),
    'page': page,
    'page_size': count,
    'total': total,
    'generated_at': '2026-08-04T04:00:00',
  };
}

Map<String, dynamic> _hotActressPage({
  required int page,
  required int total,
  required int start,
  required int count,
}) {
  return <String, dynamic>{
    'items': List<Map<String, dynamic>>.generate(count, (index) {
      final id = start + index;
      final number = id.toString().padLeft(3, '0');
      return <String, dynamic>{
        'javdb_id': 'hot-id-$number',
        'movie_number': 'HOT-$number',
        'title': 'Hot movie $number',
        'is_subscribed': false,
        'can_play': false,
        'hot_actress': <String, dynamic>{'name': '女优 $id'},
      };
    }),
    'page': page,
    'page_size': count,
    'total': total,
  };
}
