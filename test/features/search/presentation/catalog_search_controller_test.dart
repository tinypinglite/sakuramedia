import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';

import '../../../support/test_api_bundle.dart';
import 'catalog_search_harness.dart';

Map<String, dynamic> _movieItem({
  String movieNumber = 'ABP-123',
  bool isSubscribed = false,
}) => <String, dynamic>{
  'id': 11,
  'movie_number': movieNumber,
  'title': 'Movie 1',
  'cover_image': null,
  'release_date': null,
  'duration_minutes': 120,
  'is_subscribed': isSubscribed,
  'can_play': true,
};

Map<String, dynamic> _actorItem({int id = 1, bool isSubscribed = false}) =>
    <String, dynamic>{
      'id': id,
      'name': '三上悠亚',
      'alias_name': '三上悠亚 / 鬼头桃菜',
      'profile_image': null,
      'is_subscribed': isSubscribed,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items) =>
    <String, dynamic>{
      'items': items,
      'page': 1,
      'page_size': 50,
      'total': items.length,
    };

void _enqueueLocalSearch(
  TestApiBundle bundle, {
  List<Map<String, dynamic>> movies = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> actors = const <Map<String, dynamic>>[],
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies',
    body: _page(movies),
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/actors',
    body: _page(actors),
  );
}

/// 等待某个请求真正发出；用于「先启动联网流、再发起新查询」的竞态用例。
Future<void> _waitForRequest(
  TestApiBundle bundle,
  String method,
  String path,
) async {
  for (var index = 0; index < 200; index += 1) {
    if (bundle.adapter.hitCount(method, path) > 0) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('$method $path was not requested');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late CatalogSearchHarness controller;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    controller = CatalogSearchHarness(
      moviesApi: bundle.moviesApi,
      actorsApi: bundle.actorsApi,
    );
  });

  tearDown(() {
    controller.dispose();
    bundle.dispose();
  });

  test('submit ignores blank query', () async {
    await controller.submit('   ', useOnlineSearch: false);

    expect(bundle.adapter.requests, isEmpty);
    expect(controller.query, '');
    expect(controller.isLoading, isFalse);
  });

  test('submit searches local movies and actors by keyword', () async {
    _enqueueLocalSearch(
      bundle,
      movies: <Map<String, dynamic>>[_movieItem()],
      actors: <Map<String, dynamic>>[_actorItem()],
    );

    await controller.submit('abp123', useOnlineSearch: false);

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 0);
    expect(bundle.adapter.hitCount('GET', '/movies'), 1);
    expect(bundle.adapter.hitCount('GET', '/actors'), 1);
    expect(controller.activeKind, CatalogSearchKind.movies);
    expect(controller.isOnlineSearchActive, isFalse);
    expect(controller.movieResults.single.movieNumber, 'ABP-123');
    expect(controller.actorResults.single.id, 1);
    expect(controller.errorMessage, isNull);
  });

  test('submit switches to actors tab when only local actors match', () async {
    _enqueueLocalSearch(bundle, actors: <Map<String, dynamic>>[_actorItem()]);

    await controller.submit('mikami', useOnlineSearch: false);

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 0);
    expect(bundle.adapter.hitCount('GET', '/movies'), 1);
    expect(bundle.adapter.hitCount('GET', '/actors'), 1);
    expect(controller.activeKind, CatalogSearchKind.actors);
    expect(controller.isOnlineSearchActive, isFalse);
    expect(controller.actorResults.single.id, 1);
    expect(controller.movieResults, isEmpty);
    expect(controller.errorMessage, isNull);
  });

  test('local search forwards movie filters and explicit sort', () async {
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies',
      body: _page(<Map<String, dynamic>>[_movieItem()]),
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/actors',
      body: _page(const <Map<String, dynamic>>[]),
    );

    await controller.submit('abp123', useOnlineSearch: false);
    await controller.applyMovieFilter(
      const MovieFilterState(
        status: MovieStatusFilter.playable,
        collectionType: MovieCollectionTypeFilter.all,
        years: <int>{2024},
      ),
    );
    await controller.setMovieSort(
      field: MovieSortField.heat,
      direction: SortDirection.desc,
    );

    final movieRequests = bundle.adapter.requests
        .where((request) => request.path == '/movies')
        .toList();
    expect(movieRequests, hasLength(3));
    expect(movieRequests.first.uri.queryParameters['collection_type'], 'all');
    final parameters = movieRequests.last.uri.queryParameters;
    expect(parameters['query'], 'abp123');
    expect(parameters['status'], 'playable');
    expect(parameters['collection_type'], 'all');
    expect(parameters['year'], '2024');
    expect(parameters['sort'], 'heat:desc');
  });

  test('setActiveKind only switches visible tab state', () async {
    _enqueueLocalSearch(bundle);

    await controller.submit('abp123', useOnlineSearch: false);
    controller.setActiveKind(CatalogSearchKind.actors);

    expect(controller.activeKind, CatalogSearchKind.actors);
    expect(bundle.adapter.requests.length, 2);
  });

  test('submit exposes error and clears results when request fails', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(const <Map<String, dynamic>>[]),
    );

    await controller.submit('abp123', useOnlineSearch: false);

    expect(controller.query, 'abp123');
    expect(controller.isLoading, isFalse);
    expect(controller.movieResults, isEmpty);
    expect(controller.actorResults, isEmpty);
    expect(controller.errorMessage, contains('boom'));
  });

  test('toggleMovieSubscription updates matched movie result state', () async {
    _enqueueLocalSearch(bundle, movies: <Map<String, dynamic>>[_movieItem()]);
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABP-123/subscription',
      statusCode: 204,
    );

    await controller.submit('abp123', useOnlineSearch: false);
    final result = await controller.toggleMovieSubscription(
      movieNumber: 'ABP-123',
    );

    expect(bundle.adapter.hitCount('PUT', '/movies/ABP-123/subscription'), 1);
    expect(result.status, MovieSubscriptionToggleStatus.subscribed);
    expect(controller.movieResults.single.isSubscribed, isTrue);
    expect(controller.isMovieSubscriptionUpdating('ABP-123'), isFalse);
  });

  test(
    'toggleMovieSubscription maps movie media conflict to blockedByMedia',
    () async {
      _enqueueLocalSearch(
        bundle,
        movies: <Map<String, dynamic>>[_movieItem(isSubscribed: true)],
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/movies/ABP-123/subscription',
        statusCode: 409,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'movie_subscription_has_media',
            'message': '影片存在媒体文件，若需取消订阅请传 delete_media=true',
          },
        },
      );

      await controller.submit('abp123', useOnlineSearch: false);
      final result = await controller.toggleMovieSubscription(
        movieNumber: 'ABP-123',
      );

      expect(result.status, MovieSubscriptionToggleStatus.blockedByMedia);
      expect(controller.movieResults.single.isSubscribed, isTrue);
      expect(controller.isMovieSubscriptionUpdating('ABP-123'), isFalse);
    },
  );

  test('toggleActorSubscription updates matched actor result state', () async {
    _enqueueLocalSearch(bundle, actors: <Map<String, dynamic>>[_actorItem()]);
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/actors/1/subscription',
      statusCode: 204,
    );

    await controller.submit('mikami', useOnlineSearch: false);
    final result = await controller.toggleActorSubscription(actorId: 1);

    expect(bundle.adapter.hitCount('PUT', '/actors/1/subscription'), 1);
    expect(result.status, ActorSubscriptionToggleStatus.subscribed);
    expect(controller.actorResults.single.isSubscribed, isTrue);
    expect(controller.isActorSubscriptionUpdating(1), isFalse);
  });

  test(
    'applyMovieSubscriptionChange updates matched movie result state',
    () async {
      _enqueueLocalSearch(bundle, movies: <Map<String, dynamic>>[_movieItem()]);

      await controller.submit('abp123', useOnlineSearch: false);
      controller.applyMovieSubscriptionChange(
        movieNumber: 'ABP-123',
        isSubscribed: true,
      );

      expect(controller.movieResults.single.isSubscribed, isTrue);
    },
  );

  test('applyMovieSubscriptionChange removes movie when requested', () async {
    _enqueueLocalSearch(
      bundle,
      movies: <Map<String, dynamic>>[_movieItem(isSubscribed: true)],
    );

    await controller.submit('abp123', useOnlineSearch: false);
    controller.applyMovieSubscriptionChange(
      movieNumber: 'ABP-123',
      isSubscribed: false,
      removeIfUnsubscribed: true,
    );

    expect(controller.movieResults, isEmpty);
  });

  test('submit searches online movies and exposes stream progress', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'abp123',
        'parsed': true,
        'movie_number': 'ABP-123',
        'reason': null,
      },
    );
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/movies/metadata-imports',
      chunks: <String>[
        'event: search_started\n'
            'data: {"movie_number":"ABP-123"}\n\n',
        'event: upsert_started\n'
            'data: {"total":1}\n\n',
        'event: completed\n'
            'data: {"success":true,"movies":[{"movie_number":"ABP-123","title":"Movie 1","cover_image":null,"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
      ],
    );

    await controller.submit('abp123', useOnlineSearch: true);

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
    expect(bundle.adapter.hitCount('POST', '/movies/metadata-imports'), 1);
    expect(controller.isOnlineSearchActive, isTrue);
    expect(controller.streamStatus?.message, '在线搜索已完成');
    expect(controller.movieResults.single.movieNumber, 'ABP-123');
    expect(controller.errorMessage, isNull);
  });

  test(
    'submit re-runs online movie search when called twice with same query',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        body: <String, dynamic>{
          'query': 'abp123',
          'parsed': true,
          'movie_number': 'ABP-123',
          'reason': null,
        },
      );
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/movies/metadata-imports',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"movies":[],"failed_items":[],"stats":{"total":0,"created_count":0,"already_exists_count":0,"failed_count":0}}\n\n',
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        body: <String, dynamic>{
          'query': 'abp123',
          'parsed': true,
          'movie_number': 'ABP-123',
          'reason': null,
        },
      );
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/movies/metadata-imports',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"movies":[{"movie_number":"ABP-123","title":"Movie 1","cover_image":null,"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
        ],
      );

      await controller.submit('abp123', useOnlineSearch: true);
      await controller.submit('abp123', useOnlineSearch: true);

      expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 2);
      expect(bundle.adapter.hitCount('POST', '/movies/metadata-imports'), 2);
      expect(controller.movieResults.single.movieNumber, 'ABP-123');
    },
  );

  test('submit searches GFriends actor candidates', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'mikami',
        'parsed': false,
        'movie_number': null,
        'reason': 'movie_number_not_found',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/gfriends/search',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'candidate_id': 'candidate-a',
          'name': '三上悠亚',
          'alias_names': <String>['三上悠亜'],
          'avatar_url': 'https://cdn.example/actor.jpg',
          'existing_actor_id': null,
        },
      ],
    );

    await controller.submit('mikami', useOnlineSearch: true);

    expect(bundle.adapter.hitCount('GET', '/actors/gfriends/search'), 1);
    expect(controller.isOnlineSearchActive, isTrue);
    expect(controller.actorResults, isEmpty);
    expect(controller.actorCandidates.single.candidateId, 'candidate-a');
    expect(controller.errorMessage, isNull);
  });

  test('importActorCandidate marks the candidate as existing', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'mikami',
        'parsed': false,
        'movie_number': null,
        'reason': 'movie_number_not_found',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/gfriends/search',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'candidate_id': 'candidate-a',
          'name': '三上悠亚',
          'alias_names': <String>['三上悠亜'],
          'avatar_url': 'https://cdn.example/actor.jpg',
          'existing_actor_id': null,
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/actors/gfriends/import',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 9,
        'name': '三上悠亚',
        'alias_name': '三上悠亚 / 三上悠亜',
        'profile_image': null,
        'is_subscribed': false,
      },
    );

    await controller.submit('mikami', useOnlineSearch: true);
    final actor = await controller.importActorCandidate('candidate-a');

    expect(actor?.summary.id, 9);
    expect(controller.actorCandidates.single.existingActorId, 9);
    expect(controller.importingActorCandidateIds, isEmpty);
  });

  test(
    'submit cancels stale online search when a new local query starts',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        body: <String, dynamic>{
          'query': 'abp123',
          'parsed': true,
          'movie_number': 'ABP-123',
          'reason': null,
        },
      );
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/movies/metadata-imports',
        chunks: <String>[
          'event: search_started\n'
              'data: {"movie_number":"ABP-123"}\n\n',
        ],
        keepOpen: true,
      );
      _enqueueLocalSearch(bundle, actors: <Map<String, dynamic>>[_actorItem()]);

      unawaited(controller.submit('abp123', useOnlineSearch: true));
      await _waitForRequest(bundle, 'POST', '/movies/metadata-imports');

      await controller.submit('mikami', useOnlineSearch: false);

      expect(controller.query, 'mikami');
      expect(controller.activeKind, CatalogSearchKind.actors);
      expect(controller.isOnlineSearchActive, isFalse);
      expect(controller.actorResults.single.id, 1);
      expect(controller.errorMessage, isNull);
      expect(bundle.adapter.hitCount('GET', '/movies'), 1);
      expect(bundle.adapter.hitCount('GET', '/actors'), 1);
    },
  );

  test('submit exposes online stream errors as search failure', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'abp123',
        'parsed': true,
        'movie_number': 'ABP-123',
        'reason': null,
      },
    );
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/movies/metadata-imports',
      chunks: <String>[
        'event: completed\n'
            'data: not-json\n\n',
      ],
    );

    await controller.submit('abp123', useOnlineSearch: true);

    expect(controller.movieResults, isEmpty);
    expect(controller.actorResults, isEmpty);
    expect(controller.errorMessage, isNotNull);
  });
}
