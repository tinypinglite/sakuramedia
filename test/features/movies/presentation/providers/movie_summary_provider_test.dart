import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
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
    keepEventsProviderAlive(container, movieMediaEventsProvider);
    keepEventsProviderAlive(container, actorSubscriptionEventsProvider);
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
      MovieSummarySource.recentlySubscribed => '/movies',
      MovieSummarySource.blacklisted => '/movies',
      MovieSummarySource.actor => '/movies',
      MovieSummarySource.playlist => '/playlists/${scope.resourceId}/movies',
      MovieSummarySource.series => '/movies/by-series',
      MovieSummarySource.rated => '/movies',
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

  test('分辨率筛选发送参数，退出可播放后清空并回到第一页', () async {
    const scope = MovieSummaryScope.actor(actorId: 8, pageSize: 1);
    await prime(scope, [_movie('ABC-001')]);
    final notifier = container.read(movieSummaryProvider(scope).notifier);
    final filter = MovieFilterState.initial.copyWith(
      status: MovieStatusFilter.playable,
      resolution: PlaylistResolutionFilter.k4k,
    );
    for (final next in [
      filter,
      filter.copyWith(status: MovieStatusFilter.all),
      filter
          .copyWith(status: MovieStatusFilter.all)
          .copyWith(status: MovieStatusFilter.playable),
    ]) {
      adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _page(items: [_movie('ABC-002')], total: 1, pageSize: 1),
      );
      await notifier.applyMovieFilter(next);
      expect(
        adapter.requests.last.uri.queryParameters['resolution'],
        next.resolution?.apiValue,
      );
      expect(adapter.requests.last.uri.queryParameters['page'], '1');
    }
  });

  test('媒体变更同步女优影片状态，保留已加载分页且不重拉列表', () async {
    const scope = MovieSummaryScope.actor(actorId: 8, pageSize: 1);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: {
        'items': [_movie('ABC-001')],
        'page': 1,
        'page_size': 1,
        'total': 3,
      },
    );
    container.listen(movieSummaryProvider(scope), (_, __) {});
    await container.read(movieSummaryProvider(scope).future);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: {
        'items': [_movie('ABC-002')],
        'page': 2,
        'page_size': 1,
        'total': 3,
      },
    );
    await container.read(movieSummaryProvider(scope).notifier).loadMore();
    final before = container.read(movieSummaryProvider(scope)).requireValue;
    container
        .read(movieMediaEventsProvider.notifier)
        .reportChange(
          const MovieMediaChange(
            movieNumber: 'ABC-002',
            canPlay: false,
            isSubscribed: true,
          ),
        );
    await _settleEvents();
    final after = container.read(movieSummaryProvider(scope)).requireValue;
    expect(after.paged.items.map((item) => item.movieNumber), [
      'ABC-001',
      'ABC-002',
    ]);
    expect(after.paged.items.first.canPlay, isTrue);
    expect(after.paged.items.last.canPlay, isFalse);
    expect(after.paged.items.last.isSubscribed, isTrue);
    expect(after.paged.currentPage, 2);
    expect(after.paged.total, 3);
    expect(after.paged.hasMore, isTrue);
    expect(after.paged.syncedAt, before.paged.syncedAt);
    expect(adapter.requests.length, 2);
  });

  for (final status in [
    MovieStatusFilter.playable,
    MovieStatusFilter.subscribed,
    MovieStatusFilter.unsubscribed,
  ]) {
    test('媒体变更移除不符合女优影片 ${status.apiValue} 筛选的条目', () async {
      const scope = MovieSummaryScope.actor(actorId: 8);
      final subscribed = status != MovieStatusFilter.unsubscribed;
      final movies = [
        _movie('ABC-001', isSubscribed: subscribed),
        _movie('ABC-002', isSubscribed: subscribed),
      ];
      await prime(scope, movies);
      adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _page(items: movies, total: 2),
      );
      await container
          .read(movieSummaryProvider(scope).notifier)
          .applyMovieFilter(MovieFilterState(status: status));
      final event = MovieMediaChange(
        movieNumber: 'ABC-001',
        canPlay: false,
        isSubscribed: !subscribed,
      );
      container.read(movieMediaEventsProvider.notifier).reportChange(event);
      await _settleEvents();
      container.read(movieMediaEventsProvider.notifier).reportChange(event);
      await _settleEvents();
      final state = container.read(movieSummaryProvider(scope)).requireValue;
      expect(state.paged.items.single.movieNumber, 'ABC-002');
      expect(state.paged.total, 1);
      expect(state.paged.hasMore, isFalse);
      expect(state.filter.movie.status, status);
      expect(adapter.requests.length, 2);
    });
  }

  test('女优已订阅筛选在强制取消的批量广播后移除影片', () async {
    const scope = MovieSummaryScope.actor(actorId: 8);
    final movies = [_movie('ABC-001', isSubscribed: true)];
    await prime(scope, movies);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: movies, total: 1),
    );
    await container
        .read(movieSummaryProvider(scope).notifier)
        .applyMovieFilter(
          const MovieFilterState(status: MovieStatusFilter.subscribed),
        );
    container
        .read(movieMediaEventsProvider.notifier)
        .reportChange(
          const MovieMediaChange(
            movieNumber: 'ABC-001',
            canPlay: false,
            isSubscribed: true,
          ),
        );
    await _settleEvents();
    expect(
      container
          .read(movieSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .canPlay,
      isFalse,
    );
    subscriptionBroadcaster().reportBatch(<MovieSubscriptionChange>[
      const MovieSubscriptionChange(
        movieNumber: 'ABC-001',
        isSubscribed: false,
        fromBatch: true,
      ),
    ]);
    await _settleEvents();
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items, isEmpty);
    expect(state.paged.total, 0);
  });

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
          MovieFilterState(
            status: MovieStatusFilter.subscribed,
            years: const <int>{2023, 2024},
            interaction: MovieInteractionFilter.initial
                .withRange(MovieInteractionMetric.heat, min: 1000, max: 20000)
                .withRange(MovieInteractionMetric.score, min: 8.0),
          ),
        );

    final state = container.read(movieSummaryProvider(actorScope)).requireValue;
    expect(state.paged.items.single.movieNumber, 'ABC-002');
    expect(state.filter.movie.status, MovieStatusFilter.subscribed);
    final secondRequest = adapter.requests.last;
    expect(secondRequest.uri.queryParameters['status'], 'subscribed');
    expect(secondRequest.uri.queryParameters['year'], '2024,2023');
    // 女优详情也走 /catalog/movies 接口，互动数范围与 actor_id 可组合过滤。
    expect(secondRequest.uri.queryParameters['heat_min'], '1000');
    expect(secondRequest.uri.queryParameters['heat_max'], '20000');
    expect(secondRequest.uri.queryParameters['score_min'], '8.0');
  });

  test('出演年龄筛选写入请求参数，清空后不再发送', () async {
    const scope = MovieSummaryScope.movies(cacheKey: 'desktop:movies:list');
    await prime(scope, <Map<String, dynamic>>[_movie('ABC-001')]);

    final initial = adapter.requests.single.uri.queryParameters;
    expect(initial.containsKey('actor_age_min'), isFalse);
    expect(initial.containsKey('actor_age_max'), isFalse);

    final notifier = container.read(movieSummaryProvider(scope).notifier);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-002')], total: 1),
    );
    await notifier.applyMovieFilter(
      const MovieFilterState(actorAgeMin: 20, actorAgeMax: 35),
    );

    final applied = adapter.requests.last.uri.queryParameters;
    expect(applied['actor_age_min'], '20');
    expect(applied['actor_age_max'], '35');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-003')], total: 1),
    );
    await notifier.applyMovieFilter(const MovieFilterState());

    final cleared = adapter.requests.last.uri.queryParameters;
    expect(cleared.containsKey('actor_age_min'), isFalse);
    expect(cleared.containsKey('actor_age_max'), isFalse);
  });

  test('普通影片列表 scope 标签筛选写入请求参数，可与影片筛选组合并清空', () async {
    const scope = MovieSummaryScope.movies(cacheKey: 'desktop:movies:list');
    await prime(scope, <Map<String, dynamic>>[_movie('ABC-001')]);

    final initial = adapter.requests.single.uri.queryParameters;
    expect(initial.containsKey('tag_ids'), isFalse);
    expect(initial.containsKey('tag_match'), isFalse);

    final notifier = container.read(movieSummaryProvider(scope).notifier);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-002')], total: 1),
    );
    await notifier.applyTagFilter(
      tagIds: <int>[3, 5],
      tagMatch: TagMatchMode.and,
    );

    final tagged = adapter.requests.last.uri.queryParameters;
    expect(tagged['tag_ids'], '3,5');
    expect(tagged['tag_match'], 'and');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-003')], total: 1),
    );
    await notifier.applyMovieFilter(
      const MovieFilterState(actorAgeMin: 20, actorAgeMax: 35),
    );

    final combined = adapter.requests.last.uri.queryParameters;
    expect(combined['tag_ids'], '3,5');
    expect(combined['actor_age_min'], '20');
    expect(combined['actor_age_max'], '35');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-004')], total: 1),
    );
    await notifier.clearTagFilter();

    final cleared = adapter.requests.last.uri.queryParameters;
    expect(cleared.containsKey('tag_ids'), isFalse);
    expect(cleared.containsKey('tag_match'), isFalse);
    expect(cleared['actor_age_min'], '20');
  });

  test('媒体文件标签筛选写入请求参数并随重置清空', () async {
    const scope = MovieSummaryScope.movies(cacheKey: 'desktop:movies:list');
    await prime(scope, <Map<String, dynamic>>[_movie('ABC-001')]);

    final notifier = container.read(movieSummaryProvider(scope).notifier);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-002')], total: 1),
    );
    await notifier.applyMovieFilter(
      const MovieFilterState(
        mediaTagIds: <int>[4, 9],
        mediaTagMatch: TagMatchMode.and,
      ),
    );

    final tagged = adapter.requests.last.uri.queryParameters;
    expect(tagged['media_tag_ids'], '4,9');
    expect(tagged['media_tag_match'], 'and');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-003')], total: 1),
    );
    await notifier.applyMovieFilter(
      const MovieFilterState(
        mediaTagIds: <int>[4, 9],
        mediaTagMatch: TagMatchMode.and,
      ).resetFilters(),
    );

    final cleared = adapter.requests.last.uri.queryParameters;
    expect(cleared.containsKey('media_tag_ids'), isFalse);
    expect(cleared.containsKey('media_tag_match'), isFalse);
  });

  test('标签列表 scope 出演年龄与标签条件组合，未设置时不发送', () async {
    const scope = MovieSummaryScope.tags(instanceKey: 'desktop:tags:list');
    container.listen(movieSummaryProvider(scope), (_, __) {});
    await container.read(movieSummaryProvider(scope).future);

    final notifier = container.read(movieSummaryProvider(scope).notifier);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-001')], total: 1),
    );
    await notifier.applyTagFilter(
      tagIds: <int>[3, 5],
      tagMatch: TagMatchMode.and,
    );
    final tagged = adapter.requests.last.uri.queryParameters;
    expect(tagged['tag_ids'], '3,5');
    expect(tagged.containsKey('actor_age_min'), isFalse);

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-002')], total: 1),
    );
    await notifier.applyMovieFilter(
      const MovieFilterState(actorAgeMin: 20, actorAgeMax: 35),
    );
    final withAge = adapter.requests.last.uri.queryParameters;
    expect(withAge['tag_ids'], '3,5');
    expect(withAge['actor_age_min'], '20');
    expect(withAge['actor_age_max'], '35');
  });

  test('带预选标签的标签 scope 首拉即请求，同值同步不重复请求', () async {
    const scope = MovieSummaryScope.tags(
      instanceKey: 'mobile:tags:detail:7',
      initialTagIds: <int>[7],
      initialTagMatch: TagMatchMode.and,
    );
    await prime(scope, <Map<String, dynamic>>[_movie('ABC-001')]);

    final first = adapter.requests.last.uri.queryParameters;
    expect(first['tag_ids'], '7');
    expect(first['tag_match'], 'and');
    expect(adapter.requests.length, 1);

    // 页面首帧后的 post-frame 同步条件相同，应短路、不产生第二次请求。
    await container
        .read(movieSummaryProvider(scope).notifier)
        .applyTagFilter(tagIds: <int>[7], tagMatch: TagMatchMode.and);
    expect(adapter.requests.length, 1);
  });

  test('无预选标签的标签 scope 首建不请求，选择后才首拉', () async {
    const scope = MovieSummaryScope.tags(instanceKey: 'desktop:tags:list');
    container.listen(movieSummaryProvider(scope), (_, _) {});
    final state = await container.read(movieSummaryProvider(scope).future);

    expect(adapter.requests, isEmpty);
    expect(state.paged.currentPage, 0);
    expect(state.paged.items, isEmpty);

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-001')], total: 1),
    );
    await container
        .read(movieSummaryProvider(scope).notifier)
        .applyTagFilter(tagIds: <int>[7], tagMatch: TagMatchMode.or);
    final tagged = adapter.requests.last.uri.queryParameters;
    expect(tagged['tag_ids'], '7');
    expect(tagged['tag_match'], 'or');
  });

  test('女优作品叠加标签筛选，清空标签后请求不再带 tag_ids', () async {
    const actorScope = MovieSummaryScope.actor(actorId: 8);
    await prime(actorScope, <Map<String, dynamic>>[_movie('ABC-001')]);
    final notifier = container.read(movieSummaryProvider(actorScope).notifier);

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-002')], total: 1),
    );
    await notifier.applyTagFilter(
      tagIds: <int>[3, 5],
      tagMatch: TagMatchMode.and,
    );
    final tagged = adapter.requests.last.uri.queryParameters;
    expect(tagged['actor_id'], '8');
    expect(tagged['tag_ids'], '3,5');
    expect(tagged['tag_match'], 'and');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: <Map<String, dynamic>>[_movie('ABC-003')], total: 1),
    );
    await notifier.clearTagFilter();
    final cleared = adapter.requests.last.uri.queryParameters;
    expect(cleared['actor_id'], '8');
    expect(cleared.containsKey('tag_ids'), isFalse);
    expect(cleared.containsKey('tag_match'), isFalse);
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

  test('屏蔽影片 scope 只请求已屏蔽影片，取消屏蔽后就地移除条目', () async {
    const scope = MovieSummaryScope.blacklisted();
    await prime(scope, <Map<String, dynamic>>[
      _movie('ABC-001'),
      _movie('ABC-002'),
    ]);

    final listRequest = adapter.requests.single;
    expect(listRequest.path, '/movies');
    expect(listRequest.uri.queryParameters['blacklisted'], 'true');
    expect(
      listRequest.uri.queryParameters.containsKey('collection_type'),
      isFalse,
    );

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/blacklist',
      statusCode: 204,
    );
    await container
        .read(movieSummaryProvider(scope).notifier)
        .unblacklistMovie(movieNumber: 'ABC-001');

    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-002',
    ]);
    expect(state.paged.total, 1);
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.body, <String, dynamic>{
      'movie_numbers': <String>['ABC-001'],
    });
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

  test('状态筛选视图单条翻转保留行并就地更新', () async {
    // subscribed 视图：取消订阅的影片保留在列表中，只翻转订阅态。
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
      'ABC-001',
      'ABC-002',
    ]);
    expect(state.paged.items.first.isSubscribed, isFalse);
    expect(state.paged.total, 2);

    // unsubscribed 视图：订阅的影片同样保留，只翻转订阅态。
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
      'ABC-002',
    ]);
    expect(state.paged.items.last.isSubscribed, isTrue);
    expect(state.paged.total, 2);
  });

  test('状态筛选视图批量翻转即时移除不再满足条件的行', () async {
    const scope = MovieSummaryScope.movies(cacheKey: 'desktop:movies:list');
    await prime(scope, <Map<String, dynamic>>[
      _movie('ABC-001', isSubscribed: true),
      _movie('ABC-002', isSubscribed: true),
    ]);
    await container
        .read(movieSummaryProvider(scope).notifier)
        .applyMovieFilter(
          const MovieFilterState(status: MovieStatusFilter.subscribed),
        );

    subscriptionBroadcaster().reportBatch(<MovieSubscriptionChange>[
      const MovieSubscriptionChange(
        movieNumber: 'ABC-001',
        isSubscribed: false,
        fromBatch: true,
      ),
    ]);
    await _settleEvents();
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-002',
    ]);
    expect(state.paged.total, 1);
  });

  test('最近订阅视图按订阅时间倒序请求，取消订阅即移除条目', () async {
    const scope = MovieSummaryScope.recentlySubscribed();
    await prime(scope, <Map<String, dynamic>>[
      _movie('ABC-001', isSubscribed: true),
      _movie('ABC-002', isSubscribed: true),
    ]);

    final request = adapter.requests.single;
    expect(request.path, '/movies');
    expect(request.uri.queryParameters['status'], 'subscribed');
    expect(request.uri.queryParameters['sort'], 'subscribed_at:desc');

    subscriptionBroadcaster().reportChange(
      movieNumber: 'ABC-001',
      isSubscribed: false,
    );
    await _settleEvents();
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-002',
    ]);
    expect(state.paged.total, 1);
  });

  test('已翻页的最近订阅收到订阅广播时保留后续页并前插新片', () async {
    const scope = MovieSummaryScope.recentlySubscribed();
    // 第一页 2 条 / total 4：hasMore 为真，可以翻页。
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(
        items: <Map<String, dynamic>>[
          _movie('ABC-001', isSubscribed: true),
          _movie('ABC-002', isSubscribed: true),
        ],
        total: 4,
        pageSize: scope.pageSize,
      ),
    );
    container.listen(movieSummaryProvider(scope), (_, __) {});
    await container.read(movieSummaryProvider(scope).future);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(
        items: <Map<String, dynamic>>[
          _movie('ABC-003', isSubscribed: true),
          _movie('ABC-004', isSubscribed: true),
        ],
        total: 4,
        pageSize: scope.pageSize,
        page: 2,
      ),
    );
    await container.read(movieSummaryProvider(scope).notifier).loadMore();
    expect(
      container
          .read(movieSummaryProvider(scope))
          .requireValue
          .paged
          .currentPage,
      2,
    );

    // 广播暖刷新返回带新片的第一页。
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(
        items: <Map<String, dynamic>>[
          _movie('ABC-005', isSubscribed: true),
          _movie('ABC-001', isSubscribed: true),
        ],
        total: 5,
        pageSize: scope.pageSize,
      ),
    );
    subscriptionBroadcaster().reportChange(
      movieNumber: 'ABC-005',
      isSubscribed: true,
    );
    // 等暖刷新真正落到状态上：只等请求发起会在负载下读到旧列表。
    await _waitFor(
      () =>
          container
              .read(movieSummaryProvider(scope))
              .value
              ?.paged
              .items
              .any((item) => item.movieNumber == 'ABC-005') ??
          false,
    );
    await _settleEvents();

    final state = container.read(movieSummaryProvider(scope)).requireValue;
    // 新片前插、与已加载条目去重，且第 2 页不因暖刷新被丢掉。
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'ABC-005',
      'ABC-001',
      'ABC-002',
      'ABC-003',
      'ABC-004',
    ]);
    expect(state.paged.currentPage, 2);
    expect(state.paged.total, 5);
  });

  test('女优上新收到女优订阅广播后重拉列表', () async {
    const scope = MovieSummaryScope.subscribedActorsLatest();
    await prime(scope, <Map<String, dynamic>>[_movie('ABC-001')]);

    // 女优退订后重拉：该女优的影片不再返回。
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      body: _page(
        items: const <Map<String, dynamic>>[],
        total: 0,
        pageSize: scope.pageSize,
      ),
    );

    container
        .read(actorSubscriptionEventsProvider.notifier)
        .reportChange(actorId: 3, isSubscribed: false);
    await _waitFor(
      () =>
          container
              .read(movieSummaryProvider(scope))
              .value
              ?.paged
              .items
              .isEmpty ??
          false,
    );
    await _settleEvents();

    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items, isEmpty);
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

    final broadcastChanges = <MovieSubscriptionChange>[];
    final subscription = container.listen(movieSubscriptionEventsProvider, (
      _,
      next,
    ) {
      if (next.hasValue) {
        broadcastChanges.addAll(next.requireValue);
      }
    });
    addTearDown(subscription.close);
    final result = await container
        .read(movieSummaryProvider(scope).notifier)
        .batchToggleSubscription(
          movieNumbers: const <String>['ABC-001', 'ABC-002'],
          subscribe: false,
        );

    expect(result.updatedCount, 1);
    expect(result.skippedHasMediaNumbers, <String>['ABC-002']);
    // 批量路径广播必须携带来源标记，状态筛选视图据此即时移除。
    expect(broadcastChanges.single.movieNumber, 'ABC-001');
    expect(broadcastChanges.single.fromBatch, isTrue);
    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.isSubscribed), <bool>[
      false,
      true,
    ]);
  });

  test('我的评分 scope 请求 rated=true 与总分排序', () async {
    const scope = MovieSummaryScope.ratedList;
    await prime(scope, <Map<String, dynamic>>[
      <String, dynamic>{..._movie('ABC-001'), 'my_score': 4.5},
    ]);

    final request = adapter.requests.last;
    expect(request.method, 'GET');
    expect(request.uri.path, '/movies');
    expect(request.uri.queryParameters['rated'], 'true');
    expect(request.uri.queryParameters['sort'], 'my_score:desc');

    final state = container.read(movieSummaryProvider(scope)).requireValue;
    expect(state.paged.items.single.myScore, 4.5);
  });

  test('我的评分 scope 不自行保活，无监听者后释放', () async {
    const scope = MovieSummaryScope.ratedList;
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page(items: [_movie('ABC-001')], total: 1),
    );
    final subscription = container.listen(
      movieSummaryProvider(scope),
      (_, _) {},
    );
    await container.read(movieSummaryProvider(scope).future);
    expect(container.exists(movieSummaryProvider(scope)), isTrue);

    subscription.close();
    await container.pump();
    expect(container.exists(movieSummaryProvider(scope)), isFalse);
  });
}

Future<void> _settleEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  required int total,
  int pageSize = 24,
  int page = 1,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
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
