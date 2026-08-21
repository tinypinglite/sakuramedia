import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';
import '../../../../support/riverpod_test_helpers.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  MovieSubscriptionEvents subscriptionBroadcaster() =>
      container.read(movieSubscriptionEventsProvider.notifier);
  MovieCollectionTypeEvents collectionBroadcaster() =>
      container.read(movieCollectionTypeEventsProvider.notifier);

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
        moviesApiProvider.overrideWithValue(MoviesApi(apiClient: apiClient)),
        playlistsApiProvider.overrideWithValue(
          PlaylistsApi(apiClient: apiClient),
        ),
      ],
      retry: (_, __) => null,
    );
    keepEventsProviderAlive(container, movieSubscriptionEventsProvider);
    keepEventsProviderAlive(container, movieCollectionTypeEventsProvider);
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  Future<void> prime(
    MovieSummaryScope scope,
    List<Map<String, dynamic>> items,
  ) {
    final path = switch (scope.source) {
      MovieSummarySource.latest => '/movies/latest',
      MovieSummarySource.movies => '/movies',
      MovieSummarySource.tags => '/movies',
      MovieSummarySource.subscribedActorsLatest =>
        '/movies/subscribed-actors/latest',
      MovieSummarySource.actor => '/movies',
      MovieSummarySource.playlist => '/playlists/${scope.resourceId}/movies',
      MovieSummarySource.series => '/movies/by-series',
    };
    final method = scope.source == MovieSummarySource.series ? 'POST' : 'GET';
    adapter.enqueueJson(
      method: method,
      path: path,
      body: _page(items: items, total: items.length, pageSize: scope.pageSize),
    );
    container.listen(movieSummaryProvider(scope), (_, __) {});
    return container.read(movieSummaryProvider(scope).future);
  }

  test('按 scope 调用对应端点，actor 筛选写入请求参数', () async {
    const actorScope = MovieSummaryScope.actor(actorId: 8);
    await prime(actorScope, <Map<String, dynamic>>[_movie('ABC-001')]);

    final firstRequest = adapter.requests.single;
    expect(firstRequest.path, '/movies');
    expect(firstRequest.uri.queryParameters['actor_id'], '8');
    expect(firstRequest.uri.queryParameters['collection_type'], 'single');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-002')], total: 1),
    );
    await container
        .read(movieSummaryProvider(actorScope).notifier)
        .applyMovieFilter(
          const MovieFilterState(
            status: MovieStatusFilter.subscribed,
            year: 2024,
            heatMin: 1000,
            heatMax: 20000,
          ),
        );

    final state = container.read(movieSummaryProvider(actorScope)).requireValue;
    expect(state.paged.items.single.movieNumber, 'ABC-002');
    expect(state.filter.movie.status, MovieStatusFilter.subscribed);
    final secondRequest = adapter.requests.last;
    expect(secondRequest.uri.queryParameters['status'], 'subscribed');
    expect(secondRequest.uri.queryParameters['year'], '2024');
    // 女优详情也走 /catalog/movies 接口，热度范围与 actor_id 可组合过滤。
    expect(secondRequest.uri.queryParameters['heat_min'], '1000');
    expect(secondRequest.uri.queryParameters['heat_max'], '20000');
  });

  test('普通影片列表 scope 走 /movies，合集变更就地移除单体条目', () async {
    const scope = MovieSummaryScope.movies(cacheKey: 'desktop:movies:list');
    await prime(scope, <Map<String, dynamic>>[
      _movie('ABC-001'),
      _movie('ABC-002'),
    ]);

    final request = adapter.requests.single;
    expect(request.path, '/movies');
    expect(request.uri.queryParameters['collection_type'], 'single');

    collectionBroadcaster().reportChange(
      movieNumber: 'ABC-002',
      targetType: MovieCollectionType.collection,
    );
    await _settleEvents();
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-001',
    ]);
    expect(state.paged.total, 1);
  });

  test('播放列表和系列各自保持 family 实例隔离', () async {
    const playlistScope = MovieSummaryScope.playlist(playlistId: 7);
    const seriesScope = MovieSummaryScope.series(seriesId: 9);
    await prime(playlistScope, <Map<String, dynamic>>[_movie('PLAY-001')]);
    await prime(seriesScope, <Map<String, dynamic>>[_movie('SERIES-001')]);

    expect(
      container
          .read(movieSummaryProvider(playlistScope))
          .requireValue
          .paged
          .items
          .single
          .movieNumber,
      'PLAY-001',
    );
    expect(
      container
          .read(movieSummaryProvider(seriesScope))
          .requireValue
          .paged
          .items
          .single
          .movieNumber,
      'SERIES-001',
    );
    expect(
      adapter.requests.map((request) => request.path),
      containsAll(<String>['/playlists/7/movies', '/movies/by-series']),
    );
  });

  test('订阅广播就地修正条目，合集广播按来源移除单体列表中的条目', () async {
    const scope = MovieSummaryScope.subscribedActorsLatest();
    await prime(scope, <Map<String, dynamic>>[
      _movie('ABC-001', isSubscribed: false),
      _movie('ABC-002', isSubscribed: true),
    ]);

    subscriptionBroadcaster().reportChange(
      movieNumber: 'ABC-001',
      isSubscribed: true,
    );
    await _settleEvents();
    expect(
      container
          .read(movieSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .first
          .isSubscribed,
      isTrue,
    );

    collectionBroadcaster().reportChange(
      movieNumber: 'ABC-002',
      targetType: MovieCollectionType.collection,
    );
    await _settleEvents();
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-001',
    ]);
    expect(state.paged.total, 1);
  });

  test('subscribed 视图取消订阅即移除，unsubscribed 视图订阅即移除', () async {
    // subscribed 视图：取消订阅的影片不再满足筛选条件。
    const subscribedScope = MovieSummaryScope.movies(
      cacheKey: 'desktop:movies:list',
    );
    await prime(subscribedScope, <Map<String, dynamic>>[
      _movie('ABC-001', isSubscribed: true),
      _movie('ABC-002', isSubscribed: true),
    ]);
    await container
        .read(movieSummaryProvider(subscribedScope).notifier)
        .applyMovieFilter(
          const MovieFilterState(status: MovieStatusFilter.subscribed),
        );

    subscriptionBroadcaster().reportChange(
      movieNumber: 'ABC-001',
      isSubscribed: false,
    );
    await _settleEvents();
    var state = container
        .read(movieSummaryProvider(subscribedScope))
        .requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-002',
    ]);
    expect(state.paged.total, 1);

    // unsubscribed 视图：订阅的影片不再满足筛选条件，同样就地移除。
    const unsubscribedScope = MovieSummaryScope.movies(
      cacheKey: 'desktop:movies:list',
    );
    await prime(unsubscribedScope, <Map<String, dynamic>>[
      _movie('ABC-001', isSubscribed: false),
      _movie('ABC-002', isSubscribed: false),
    ]);
    await container
        .read(movieSummaryProvider(unsubscribedScope).notifier)
        .applyMovieFilter(
          const MovieFilterState(status: MovieStatusFilter.unsubscribed),
        );

    subscriptionBroadcaster().reportChange(
      movieNumber: 'ABC-002',
      isSubscribed: true,
    );
    await _settleEvents();
    state = container
        .read(movieSummaryProvider(unsubscribedScope))
        .requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-001',
    ]);
    expect(state.paged.total, 1);
  });

  test('单条订阅成功后更新本地条目并清除 busy 状态', () async {
    const scope = MovieSummaryScope.latest();
    await prime(scope, <Map<String, dynamic>>[_movie('ABC-001')]);
    adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/subscription',
      statusCode: 204,
    );

    final result = await container
        .read(movieSummaryProvider(scope).notifier)
        .toggleSubscription('ABC-001');

    expect(result.status.name, 'subscribed');
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.single.isSubscribed, isTrue);
    expect(state.isSubscriptionUpdating('ABC-001'), isFalse);
  });

  test('屏蔽成功后从当前影片列表移除对应条目', () async {
    const scope = MovieSummaryScope.latest();
    await prime(scope, <Map<String, dynamic>>[
      _movie('ABC-001'),
      _movie('ABC-002'),
    ]);
    adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/blacklist',
      statusCode: 204,
    );

    await container
        .read(movieSummaryProvider(scope).notifier)
        .blacklistMovies(movieNumbers: const <String>['ABC-002']);

    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-001',
    ]);
    expect(state.paged.total, 1);
  });

  test('批量取消订阅精确回滚 skipped 条目且只保留已接受变更', () async {
    const scope = MovieSummaryScope.latest();
    await prime(scope, <Map<String, dynamic>>[
      _movie('ABC-001', isSubscribed: true),
      _movie('ABC-002', isSubscribed: true),
    ]);
    adapter.enqueueJson(
      method: 'POST',
      path: '/movies/unsubscriptions',
      body: <String, dynamic>{
        'requested_count': 2,
        'updated_count': 1,
        'skipped_count': 1,
        'skipped': <Map<String, dynamic>>[
          <String, dynamic>{'movie_number': 'ABC-002', 'reason': 'has_media'},
        ],
      },
    );

    final result = await container
        .read(movieSummaryProvider(scope).notifier)
        .batchToggleSubscription(
          movieNumbers: const <String>['ABC-001', 'ABC-002'],
          subscribe: false,
        );

    expect(result.updatedCount, 1);
    expect(result.skippedHasMediaNumbers, <String>['ABC-002']);
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.isSubscribed), <bool>[
      false,
      true,
    ]);
  });
}

Future<void> _settleEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  required int total,
  int pageSize = 24,
}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _movie(String movieNumber, {bool isSubscribed = false}) {
  return <String, dynamic>{
    'javdb_id': 'javdb-$movieNumber',
    'movie_number': movieNumber,
    'title': 'Movie $movieNumber',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'heat': 1,
    'is_subscribed': isSubscribed,
    'can_play': true,
  };
}
