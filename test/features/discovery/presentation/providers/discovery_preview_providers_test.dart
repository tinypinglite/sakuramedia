import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_api_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_preview_providers.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
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
    container = ProviderContainer(
      overrides: [
        discoveryApiProvider.overrideWithValue(
          DiscoveryApi(apiClient: apiClient),
        ),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void keepAlive() {
    // autoDispose：挂监听者保活。
    final daily = container.listen(
      discoveryDailyPreviewProvider(6),
      (_, __) {},
    );
    final moment = container.listen(
      discoveryMomentPreviewProvider(8),
      (_, __) {},
    );
    addTearDown(daily.close);
    addTearDown(moment.close);
  }

  /// 等 build 里 microtask 触发的初始 load 完成（含 dio 假适配器的多跳异步）。
  Future<void> settle() => pumpEventQueue();

  test(
    'build kicks off load and fills both legs with page 1 previews',
    () async {
      _enqueueDaily(adapter, movieNumbers: ['ABC-001'], total: 12);
      _enqueueMoments(adapter, recommendationIds: [1, 2], total: 20);

      keepAlive();
      // 首帧即 loading 态(对齐旧 `..load()` 时序)。
      expect(
        container.read(discoveryDailyPreviewProvider(6)).isLoading,
        isTrue,
      );
      await settle();

      final daily = container.read(discoveryDailyPreviewProvider(6));
      final moment = container.read(discoveryMomentPreviewProvider(8));
      expect(daily.items.map((item) => item.movie.movieNumber), ['ABC-001']);
      expect(daily.total, 12);
      expect(daily.isLoading, isFalse);
      expect(daily.errorMessage, isNull);
      expect(moment.items.map((item) => item.recommendationId), [1, 2]);
      expect(moment.total, 20);
      expect(moment.errorMessage, isNull);
      // family 参数透传为 page_size。
      expect(
        adapter.requests
            .firstWhere((r) => r.uri.path.contains('daily'))
            .uri
            .queryParameters['page_size'],
        '6',
      );
    },
  );

  test('refresh failure with existing items keeps them silently', () async {
    _enqueueDaily(adapter, movieNumbers: ['ABC-001'], total: 12);
    _enqueueMoments(adapter, recommendationIds: [1], total: 20);
    keepAlive();
    await settle();

    adapter.enqueueJson(
      method: 'GET',
      path: '/daily-recommendations',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-recommendations',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );

    await Future.wait(<Future<void>>[
      container.read(discoveryDailyPreviewProvider(6).notifier).refresh(),
      container.read(discoveryMomentPreviewProvider(8).notifier).refresh(),
    ]);

    // 有旧数据时静默保留：不清列表、不置错误。
    final daily = container.read(discoveryDailyPreviewProvider(6));
    final moment = container.read(discoveryMomentPreviewProvider(8));
    expect(daily.items.map((item) => item.movie.movieNumber), ['ABC-001']);
    expect(daily.errorMessage, isNull);
    expect(moment.items.map((item) => item.recommendationId), [1]);
    expect(moment.errorMessage, isNull);
  });

  test('one leg failing does not break the other', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/daily-recommendations',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    _enqueueMoments(adapter, recommendationIds: [1], total: 20);

    keepAlive();
    await settle();

    final daily = container.read(discoveryDailyPreviewProvider(6));
    final moment = container.read(discoveryMomentPreviewProvider(8));
    expect(daily.items, isEmpty);
    expect(daily.errorMessage, '今日推荐加载失败，请稍后重试');
    expect(moment.items.map((item) => item.recommendationId), [1]);
    expect(moment.errorMessage, isNull);
  });

  test('hot actress preview loads its own recommendation source', () async {
    _enqueueHotActress(adapter, movieNumbers: ['HOT-001'], total: 12);
    final subscription = container.listen(
      discoveryHotActressReleasePreviewProvider(6),
      (_, __) {},
    );
    addTearDown(subscription.close);

    await settle();

    final hotActress = container.read(
      discoveryHotActressReleasePreviewProvider(6),
    );
    expect(hotActress.items.single.movie.movieNumber, 'HOT-001');
    expect(hotActress.items.single.hotActressName, '女优 A');
    expect(hotActress.total, 12);

    container
        .read(movieSubscriptionEventsProvider.notifier)
        .reportChange(movieNumber: 'HOT-001', isSubscribed: true);
    await settle();

    expect(
      container
          .read(discoveryHotActressReleasePreviewProvider(6))
          .items
          .single
          .movie
          .isSubscribed,
      isTrue,
    );
  });
}

void _enqueueDaily(
  FakeHttpClientAdapter adapter, {
  required List<String> movieNumbers,
  required int total,
}) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/daily-recommendations',
    body: <String, dynamic>{
      'items': movieNumbers
          .map(
            (movieNumber) => <String, dynamic>{
              'javdb_id': 'id-$movieNumber',
              'movie_number': movieNumber,
              'title': 'Movie $movieNumber',
              'is_subscribed': false,
              'can_play': true,
            },
          )
          .toList(),
      'page': 1,
      'page_size': movieNumbers.length,
      'total': total,
    },
  );
}

void _enqueueMoments(
  FakeHttpClientAdapter adapter, {
  required List<int> recommendationIds,
  required int total,
}) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/moment-recommendations',
    body: <String, dynamic>{
      'items': recommendationIds
          .map(
            (id) => <String, dynamic>{
              'recommendation_id': id,
              'rank': id,
              'score': 0.88,
              'strategy': 'visual',
              'reason': 'similar',
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
            },
          )
          .toList(),
      'page': 1,
      'page_size': recommendationIds.length,
      'total': total,
      'generated_at': '2026-08-04T04:00:00',
    },
  );
}

void _enqueueHotActress(
  FakeHttpClientAdapter adapter, {
  required List<String> movieNumbers,
  required int total,
}) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/hot-actress-releases',
    body: <String, dynamic>{
      'items': movieNumbers
          .map(
            (movieNumber) => <String, dynamic>{
              'javdb_id': 'id-$movieNumber',
              'movie_number': movieNumber,
              'title': 'Movie $movieNumber',
              'is_subscribed': false,
              'can_play': false,
              'hot_actress': <String, dynamic>{'name': '女优 A'},
            },
          )
          .toList(),
      'page': 1,
      'page_size': movieNumbers.length,
      'total': total,
    },
  );
}
