import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/rankings_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';
import '../../../../support/riverpod_test_helpers.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  MovieSubscriptionEvents subscriptionBroadcaster() =>
      container.read(movieSubscriptionEventsProvider.notifier);

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        rankingsApiProvider.overrideWithValue(
          RankingsApi(apiClient: apiClient),
        ),
        moviesApiProvider.overrideWithValue(MoviesApi(apiClient: apiClient)),
      ],
      retry: (_, __) => null,
    );
    keepEventsProviderAlive(container, movieSubscriptionEventsProvider);
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void enqueueMetadata({
    String sourceKey = 'javdb',
    String boardKey = 'censored',
  }) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'source_key': sourceKey, 'name': 'JavDB'},
      ],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/$sourceKey/boards',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'source_key': sourceKey,
          'board_key': boardKey,
          'name': '有码',
          'supported_periods': <String>['daily', 'weekly'],
          'default_period': 'daily',
        },
      ],
    );
  }

  Future<void> prime(
    RankingSummaryScope scope, {
    List<Map<String, dynamic>>? items,
    int total = 1,
  }) {
    enqueueMetadata();
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _page(
        items: items ?? <Map<String, dynamic>>[_rankedMovie(1)],
        total: total,
      ),
    );
    container.listen(rankingSummaryProvider(scope), (_, __) {});
    return container.read(rankingSummaryProvider(scope).future);
  }

  test('初始按来源、榜单默认周期加载 24 条，未指定排序', () async {
    const scope = RankingSummaryScope.desktop();
    await prime(scope);

    final request = adapter.requests.last;
    expect(request.path, '/ranking-sources/javdb/boards/censored/items');
    expect(request.uri.queryParameters['period'], 'daily');
    expect(request.uri.queryParameters['page_size'], '24');
    expect(request.uri.queryParameters.containsKey('sort'), isFalse);
  });

  test('切换来源先加载新榜单，再以新默认周期重拉条目', () async {
    const scope = RankingSummaryScope.desktop();
    await prime(scope);
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/mock-source/boards',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'source_key': 'mock-source',
          'board_key': 'hot',
          'name': '热门',
          'supported_periods': <String>['weekly'],
          'default_period': 'weekly',
        },
      ],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/mock-source/boards/hot/items',
      body: _page(items: <Map<String, dynamic>>[_rankedMovie(2)], total: 1),
    );

    await container
        .read(rankingSummaryProvider(scope).notifier)
        .selectSource(
          const RankingSourceDto(sourceKey: 'mock-source', name: 'Mock Source'),
        );

    final state = container.read(rankingSummaryProvider(scope)).requireValue;
    expect(state.filters.selectedSource?.sourceKey, 'mock-source');
    expect(state.filters.selectedBoard?.boardKey, 'hot');
    expect(state.filters.selectedPeriod, 'weekly');
    expect(state.paged.items.single.movieNumber, 'ABC-002');
  });

  test('切换周期和排序同步更新控件，防抖后写入请求参数', () async {
    const scope = RankingSummaryScope.desktop();
    await prime(scope);
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _page(items: <Map<String, dynamic>>[_rankedMovie(2)], total: 1),
    );
    final periodUpdate = container
        .read(rankingSummaryProvider(scope).notifier)
        .selectPeriod('weekly');
    final pendingPeriod = container
        .read(rankingSummaryProvider(scope))
        .requireValue;
    expect(pendingPeriod.filters.selectedPeriod, 'weekly');
    expect(pendingPeriod.paged.filterUpdate.isWaiting, isTrue);
    expect(pendingPeriod.paged.items.single.movieNumber, 'ABC-001');
    expect(
      adapter.hitCount('GET', '/ranking-sources/javdb/boards/censored/items'),
      1,
    );

    await periodUpdate;
    expect(adapter.requests.last.uri.queryParameters['period'], 'weekly');

    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _page(items: <Map<String, dynamic>>[_rankedMovie(3)], total: 1),
    );
    final sortUpdate = container
        .read(rankingSummaryProvider(scope).notifier)
        .selectSort(RankingSortField.heat, SortDirection.asc);
    final pendingSort = container
        .read(rankingSummaryProvider(scope))
        .requireValue;
    expect(pendingSort.filters.selectedSortField, RankingSortField.heat);
    expect(pendingSort.paged.filterUpdate.isWaiting, isTrue);
    expect(pendingSort.paged.items.single.movieNumber, 'ABC-002');

    await sortUpdate;
    expect(adapter.requests.last.uri.queryParameters['sort'], 'heat:asc');
  });

  test('刷新成功替换首页，失败保留旧条目并返回文案', () async {
    const scope = RankingSummaryScope.desktop();
    await prime(
      scope,
      items: <Map<String, dynamic>>[_rankedMovie(1)],
      total: 2,
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _page(items: <Map<String, dynamic>>[_rankedMovie(99)], total: 1),
    );
    expect(
      await container.read(rankingSummaryProvider(scope).notifier).refresh(),
      isNull,
    );
    expect(
      container
          .read(rankingSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .movieNumber,
      'ABC-099',
    );

    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      statusCode: 500,
    );
    expect(
      await container.read(rankingSummaryProvider(scope).notifier).refresh(),
      isNotNull,
    );
    expect(
      container
          .read(rankingSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .movieNumber,
      'ABC-099',
    );
  });

  test('订阅广播和单条操作均就地修正榜单条目', () async {
    const scope = RankingSummaryScope.desktop();
    await prime(scope, items: <Map<String, dynamic>>[_rankedMovie(1)]);
    subscriptionBroadcaster().reportChange(
      movieNumber: 'ABC-001',
      isSubscribed: true,
    );
    await _settle();
    expect(
      container
          .read(rankingSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .isSubscribed,
      isTrue,
    );

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABC-001/subscription',
      statusCode: 204,
    );
    final result = await container
        .read(rankingSummaryProvider(scope).notifier)
        .toggleSubscription('ABC-001');
    expect(result.status.name, 'unsubscribed');
    expect(
      container
          .read(rankingSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .isSubscribed,
      isFalse,
    );
  });

  test('desktop/mobile family 与页面缓存生命周期隔离', () async {
    const desktop = RankingSummaryScope.desktop();
    const mobile = RankingSummaryScope.mobile();
    await prime(desktop, items: <Map<String, dynamic>>[_rankedMovie(1)]);
    await prime(mobile, items: <Map<String, dynamic>>[_rankedMovie(2)]);
    expect(
      container
          .read(rankingSummaryProvider(desktop))
          .requireValue
          .paged
          .items
          .single
          .movieNumber,
      'ABC-001',
    );
    expect(
      container
          .read(rankingSummaryProvider(mobile))
          .requireValue
          .paged
          .items
          .single
          .movieNumber,
      'ABC-002',
    );

    final cache = RiverpodPageCache();
    addTearDown(cache.dispose);
    final link = container
        .read(rankingSummaryProvider(desktop).notifier)
        .cacheLink;
    expect(link, isNotNull);
    cache.obtain(key: desktop.cacheKey, resolveLinks: () => [link!]);
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  required int total,
}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 24,
    'total': total,
  };
}

Map<String, dynamic> _rankedMovie(int rank) {
  return <String, dynamic>{
    'rank': rank,
    'javdb_id': 'javdb-$rank',
    'movie_number': 'ABC-${rank.toString().padLeft(3, '0')}',
    'title': 'Movie $rank',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'heat': 1,
    'is_subscribed': false,
    'can_play': true,
  };
}
