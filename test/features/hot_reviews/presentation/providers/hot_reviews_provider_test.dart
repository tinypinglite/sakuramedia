import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/providers/hot_reviews_api_provider.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/providers/hot_reviews_provider.dart';

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
        hotReviewsApiProvider.overrideWithValue(
          HotReviewsApi(apiClient: apiClient),
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

  ProviderSubscription<AsyncValue<Object?>> keepAlive() {
    // autoDispose：挂监听者保活，避免两次 read 之间被释放重建。
    final subscription = container.listen(hotReviewsProvider, (_, __) {});
    addTearDown(subscription.close);
    return subscription;
  }

  test('refresh replaces first page items', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewPage(reviewIds: [1], total: 2),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewPage(reviewIds: [99], total: 1),
    );

    keepAlive();
    await container.read(hotReviewsProvider.future);
    final errorMessage =
        await container.read(hotReviewsProvider.notifier).refresh();

    expect(errorMessage, isNull);
    final state = container.read(hotReviewsProvider).requireValue;
    expect(state.paged.items.single.reviewId, 99);
    expect(state.paged.total, 1);
    expect(state.paged.hasMore, isFalse);
  });

  test('refresh returns error message and keeps existing items on failure',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewPage(reviewIds: [1], total: 2),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );

    keepAlive();
    await container.read(hotReviewsProvider.future);
    final errorMessage =
        await container.read(hotReviewsProvider.notifier).refresh();

    expect(errorMessage, isNotNull);
    final state = container.read(hotReviewsProvider).requireValue;
    expect(state.paged.items.single.reviewId, 1);
    expect(state.paged.total, 2);
  });

  test('applyFilterState dedupes same period and reloads with the new one',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewPage(reviewIds: [1], total: 1),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewPage(reviewIds: [2], total: 1),
    );

    keepAlive();
    await container.read(hotReviewsProvider.future);
    final notifier = container.read(hotReviewsProvider.notifier);

    // 同值去重：不发请求。
    await notifier.applyFilterState(HotReviewPeriod.weekly);
    expect(adapter.requests, hasLength(1));

    // 换周期：清列表重拉，新请求携带新 period。
    await notifier.applyFilterState(HotReviewPeriod.monthly);
    expect(adapter.requests, hasLength(2));
    expect(
      adapter.requests.last.uri.queryParameters['period'],
      'monthly',
    );
    final state = container.read(hotReviewsProvider).requireValue;
    expect(state.period, HotReviewPeriod.monthly);
    expect(state.paged.items.single.reviewId, 2);
    expect(notifier.period, HotReviewPeriod.monthly);
  });
}

Map<String, dynamic> _hotReviewPage({
  required List<int> reviewIds,
  required int total,
}) {
  return <String, dynamic>{
    'items': reviewIds
        .map(
          (reviewId) => <String, dynamic>{
            'rank': 1,
            'review_id': reviewId,
            'score': 5,
            'content': 'Review $reviewId',
            'created_at': '2026-03-12T10:00:00Z',
            'username': 'user',
            'like_count': 10,
            'watch_count': 20,
            'movie': <String, dynamic>{
              'javdb_id': 'movie-$reviewId',
              'movie_number': 'ABC-${reviewId.toString().padLeft(3, '0')}',
              'title': 'Movie $reviewId',
              'is_subscribed': false,
              'can_play': true,
            },
          },
        )
        .toList(),
    'page': 1,
    'page_size': 20,
    'total': total,
  };
}
