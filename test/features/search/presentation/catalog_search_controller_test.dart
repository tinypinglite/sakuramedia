import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_controller.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late CatalogSearchController controller;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    controller = CatalogSearchController(
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

  test('submit searches movies when parse succeeds', () async {
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
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/search/local',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABP-123',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': null,
          'duration_minutes': 120,
          'is_subscribed': false,
          'can_play': true,
        },
      ],
    );

    await controller.submit('abp123', useOnlineSearch: false);

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
    expect(bundle.adapter.hitCount('GET', '/movies/search/local'), 1);
    expect(bundle.adapter.hitCount('GET', '/actors/search/local'), 0);
    expect(controller.activeKind, CatalogSearchKind.movies);
    expect(controller.movieResults.single.movieNumber, 'ABP-123');
    expect(controller.actorResults, isEmpty);
    expect(controller.errorMessage, isNull);
  });

  test('submit forces online actor search when parse fails', () async {
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
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/actors/search/javdb/stream',
      chunks: <String>[
        'event: completed\n'
            'data: {"success":true,"actors":[{"id":1,"javdb_id":"ActorA1","name":"三上悠亚","alias_name":"三上悠亚 / 鬼头桃菜","profile_image":null,"is_subscribed":false}]}\n\n',
      ],
    );

    await controller.submit('mikami', useOnlineSearch: false);

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
    expect(bundle.adapter.hitCount('GET', '/movies/search/local'), 0);
    expect(bundle.adapter.hitCount('POST', '/actors/search/javdb/stream'), 1);
    expect(controller.activeKind, CatalogSearchKind.actors);
    expect(controller.isOnlineSearchActive, isTrue);
    expect(controller.actorResults.single.id, 1);
    expect(controller.movieResults, isEmpty);
    expect(controller.errorMessage, isNull);
  });

  test('setActiveKind only switches visible tab state', () async {
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
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/search/local',
      body: <Map<String, dynamic>>[],
    );

    await controller.submit('abp123', useOnlineSearch: false);
    controller.setActiveKind(CatalogSearchKind.actors);

    expect(controller.activeKind, CatalogSearchKind.actors);
    expect(bundle.adapter.hitCount('GET', '/actors/search/local'), 0);
    expect(bundle.adapter.requests.length, 2);
  });

  test('submit exposes error and clears results when request fails', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    await controller.submit('abp123', useOnlineSearch: false);

    expect(controller.query, 'abp123');
    expect(controller.isLoading, isFalse);
    expect(controller.movieResults, isEmpty);
    expect(controller.actorResults, isEmpty);
    expect(controller.errorMessage, contains('boom'));
  });

  test('toggleMovieSubscription updates matched movie result state', () async {
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
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/search/local',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABP-123',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': null,
          'duration_minutes': 120,
          'is_subscribed': false,
          'can_play': true,
        },
      ],
    );
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
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/search/local',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'javdb_id': 'MovieA1',
            'movie_number': 'ABP-123',
            'title': 'Movie 1',
            'cover_image': null,
            'release_date': null,
            'duration_minutes': 120,
            'is_subscribed': true,
            'can_play': true,
          },
        ],
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
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/actors/search/javdb/stream',
      chunks: <String>[
        'event: completed\n'
            'data: {"success":true,"actors":[{"id":1,"javdb_id":"ActorA1","name":"三上悠亚","alias_name":"三上悠亚 / 鬼头桃菜","profile_image":null,"is_subscribed":false}]}\n\n',
      ],
    );
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
      path: '/movies/search/javdb/stream',
      chunks: <String>[
        'event: search_started\n'
            'data: {"movie_number":"ABP-123"}\n\n',
        'event: upsert_started\n'
            'data: {"total":1}\n\n',
        'event: completed\n'
            'data: {"success":true,"movies":[{"javdb_id":"MovieA1","movie_number":"ABP-123","title":"Movie 1","cover_image":null,"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
      ],
    );

    await controller.submit('abp123', useOnlineSearch: true);

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
    expect(bundle.adapter.hitCount('POST', '/movies/search/javdb/stream'), 1);
    expect(controller.isOnlineSearchActive, isTrue);
    expect(controller.lastResolvedKind, CatalogSearchKind.movies);
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
        path: '/movies/search/javdb/stream',
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
        path: '/movies/search/javdb/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"movies":[{"javdb_id":"MovieA1","movie_number":"ABP-123","title":"Movie 1","cover_image":null,"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
        ],
      );

      await controller.submit('abp123', useOnlineSearch: true);
      await controller.submit('abp123', useOnlineSearch: true);

      expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 2);
      expect(bundle.adapter.hitCount('POST', '/movies/search/javdb/stream'), 2);
      expect(controller.movieResults.single.movieNumber, 'ABP-123');
    },
  );

  test(
    'submit searches online actors and keeps not-found as empty state',
    () async {
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
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/actors/search/javdb/stream',
        chunks: <String>[
          'event: search_started\n'
              'data: {"actor_name":"mikami"}\n\n',
          'event: completed\n'
              'data: {"success":false,"reason":"actor_not_found","actors":[]}\n\n',
        ],
      );

      await controller.submit('mikami', useOnlineSearch: true);

      expect(bundle.adapter.hitCount('POST', '/actors/search/javdb/stream'), 1);
      expect(controller.isOnlineSearchActive, isTrue);
      expect(controller.lastResolvedKind, CatalogSearchKind.actors);
      expect(controller.actorResults, isEmpty);
      expect(controller.errorMessage, isNull);
      expect(controller.streamStatus?.message, '在线搜索已完成');
      expect(controller.streamStatus?.isFailure, isFalse);
    },
  );

  test(
    'submit re-runs online actor search when called twice with same query',
    () async {
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
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/actors/search/javdb/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":false,"reason":"actor_not_found","actors":[]}\n\n',
        ],
      );
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
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/actors/search/javdb/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"actors":[{"id":1,"javdb_id":"ActorA1","name":"三上悠亚","alias_name":"三上悠亚 / 鬼头桃菜","profile_image":null,"is_subscribed":false}]}\n\n',
        ],
      );

      await controller.submit('mikami', useOnlineSearch: true);
      await controller.submit('mikami', useOnlineSearch: true);

      expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 2);
      expect(bundle.adapter.hitCount('POST', '/actors/search/javdb/stream'), 2);
      expect(controller.actorResults.single.id, 1);
    },
  );

  test(
    'submit cancels stale online search results when a new query starts',
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
        path: '/movies/search/javdb/stream',
        chunks: <String>[
          'event: search_started\n'
              'data: {"movie_number":"ABP-123"}\n\n',
        ],
      );
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
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/actors/search/javdb/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"actors":[{"id":1,"javdb_id":"ActorA1","name":"三上悠亚","alias_name":"三上悠亚 / 鬼头桃菜","profile_image":null,"is_subscribed":false}]}\n\n',
        ],
      );

      await controller.submit('abp123', useOnlineSearch: true);
      await controller.submit('mikami', useOnlineSearch: false);

      expect(controller.query, 'mikami');
      expect(controller.activeKind, CatalogSearchKind.actors);
      expect(bundle.adapter.hitCount('POST', '/actors/search/javdb/stream'), 1);
      expect(controller.actorResults.single.id, 1);
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
      path: '/movies/search/javdb/stream',
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
