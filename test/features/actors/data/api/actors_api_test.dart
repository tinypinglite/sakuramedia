import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late ActorsApi actorsApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    actorsApi = ActorsApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getActors parses paginated actor response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 1,
            'name': '三上悠亚',
            'alias_name': '三上悠亚 / 鬼头桃菜',
            'profile_image': <String, dynamic>{'id': 10, 'origin': 'large.jpg'},
            'is_subscribed': true,
            'movie_count': 42,
            'age': 28,
            'birthday': '1998-05-03',
            'height_cm': 159,
            'bust_cm': 86,
            'waist_cm': 58,
            'hips_cm': 88,
            'cup': 'E',
          },
        ],
        'page': 2,
        'page_size': 24,
        'total': 25,
      },
    );

    final page = await actorsApi.getActors(
      page: 2,
      pageSize: 24,
      subscriptionStatus: ActorSubscriptionStatus.subscribed,
      gender: ActorGender.female,
    );

    expect(page.page, 2);
    expect(page.pageSize, 24);
    expect(page.total, 25);
    expect(page.items.single.id, 1);
    expect(page.items.single.displayName, '三上悠亚 / 鬼头桃菜');
    expect(page.items.single.profileImage?.origin, 'large.jpg');
    expect(page.items.single.movieCount, 42);
    expect(page.items.single.age, 28);
    expect(page.items.single.birthday, DateTime(1998, 5, 3));
    expect(page.items.single.heightCm, 159);
    expect(page.items.single.bustCm, 86);
    expect(page.items.single.waistCm, 58);
    expect(page.items.single.hipsCm, 88);
    expect(page.items.single.cup, 'E');

    final request = adapter.requests.single;
    expect(request.path, '/actors');
    expect(request.method, 'GET');
  });

  test('getActors sends backend filter query parameters', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );

    await actorsApi.getActors(
      subscriptionStatus: ActorSubscriptionStatus.unsubscribed,
      gender: ActorGender.male,
      hasPlayableMovies: true,
      sort: 'movie_count:desc',
      query: '三上',
      page: 1,
      pageSize: 24,
    );

    final request = adapter.requests.single;
    expect(request.path, '/actors');
    expect(request.method, 'GET');
    expect(request.uri.queryParameters['subscription_status'], 'unsubscribed');
    expect(request.uri.queryParameters['gender'], 'male');
    expect(request.uri.queryParameters['has_playable_movies'], 'true');
    expect(request.uri.queryParameters['sort'], 'movie_count:desc');
    expect(request.uri.queryParameters['query'], '三上');
    expect(request.uri.queryParameters['page'], '1');
    expect(request.uri.queryParameters['page_size'], '24');
  });

  test('getActors omits blank optional query parameters', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );

    await actorsApi.getActors(query: '', sort: '', cups: const <String>[]);

    final query = adapter.requests.single.uri.queryParameters;
    expect(query.containsKey('query'), isFalse);
    expect(query.containsKey('sort'), isFalse);
    expect(query.containsKey('cups'), isFalse);
    expect(query.containsKey('has_playable_movies'), isFalse);
  });

  test('getActors converts backend error to ApiException', () async {
    await sessionStore.clearSession();
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Unauthorized',
        },
      },
    );

    expect(
      () => actorsApi.getActors(),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'unauthorized',
        ),
      ),
    );
  });

  test('getActorDetail parses actor detail response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      statusCode: 200,
      body: <String, dynamic>{
        'id': 1,
        'name': '三上悠亚',
        'alias_name': '三上悠亚 / 鬼头桃菜',
        'profile_image': <String, dynamic>{'id': 10, 'origin': 'large.jpg'},
        'is_subscribed': true,
        'birthday': '1993-08-16',
        'age': 33,
        'height_cm': 159,
        'bust_cm': 84,
        'waist_cm': 58,
        'hips_cm': 88,
        'cup': ' F ',
        'birthplace': '出生地',
        'blood_type': 'O',
      },
    );

    final actor = await actorsApi.getActorDetail(actorId: 1);

    expect(actor.summary.id, 1);
    expect(actor.summary.displayName, '三上悠亚 / 鬼头桃菜');
    expect(actor.summary.profileImage?.origin, 'large.jpg');
    expect(actor.birthday, DateTime(1993, 8, 16));
    expect(actor.age, 33);
    expect(actor.heightCm, 159);
    expect([actor.bustCm, actor.waistCm, actor.hipsCm], [84, 58, 88]);
    expect(actor.cup, 'F');
    expect(actor.birthplace, '出生地');
    expect(actor.bloodType, 'O');
    expect(adapter.requests.single.path, '/actors/1');
  });

  test('getActorDetail converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/404',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'actor_not_found',
          'message': '演员不存在',
        },
      },
    );

    expect(
      () => actorsApi.getActorDetail(actorId: 404),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'actor_not_found',
        ),
      ),
    );
  });

  test('updateActor sends sparse PATCH with expected revision', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/actors/1',
      statusCode: 200,
      body: <String, dynamic>{
        ..._actorDetailResponse(),
        'display_name': '本地显示名',
        'display_name_override': '本地显示名',
        'mutation_revision': 1,
      },
    );

    final actor = await actorsApi.updateActor(
      actorId: 1,
      expectedRevision: 0,
      changes: <String, dynamic>{
        'display_name_override': '本地显示名',
        'height_cm': 160,
      },
    );

    expect(actor.summary.displayName, '本地显示名');
    expect(actor.mutationRevision, 1);
    expect(adapter.requests.single.body, {
      'expected_revision': 0,
      'display_name_override': '本地显示名',
      'height_cm': 160,
    });
  });

  test('profile image APIs use revision query and multipart upload', () async {
    final response = <String, dynamic>{
      ..._actorDetailResponse(),
      'has_profile_image_override': true,
      'mutation_revision': 1,
    };
    adapter.enqueueJson(
      method: 'PUT',
      path: '/actors/1/profile-image',
      body: response,
    );
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/actors/1/profile-image',
      body: <String, dynamic>{
        ..._actorDetailResponse(),
        'mutation_revision': 2,
      },
    );

    final uploaded = await actorsApi.uploadActorProfileImage(
      actorId: 1,
      expectedRevision: 0,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'avatar.png',
    );
    final cleared = await actorsApi.clearActorProfileImage(
      actorId: 1,
      expectedRevision: uploaded.mutationRevision,
    );

    expect(uploaded.hasProfileImageOverride, isTrue);
    expect(cleared.hasProfileImageOverride, isFalse);
    expect(adapter.requests[0].uri.queryParameters['expected_revision'], '0');
    expect(adapter.requests[0].body, isA<FormData>());
    expect(adapter.requests[1].uri.queryParameters['expected_revision'], '1');
  });

  test('getActorMovieIds parses movie id list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1/movie-ids',
      statusCode: 200,
      body: <int>[101, 102, 103],
    );

    final movieIds = await actorsApi.getActorMovieIds(actorId: 1);

    expect(movieIds, <int>[101, 102, 103]);
    expect(adapter.requests.single.path, '/actors/1/movie-ids');
  });

  test('getActorMovieIds converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/404/movie-ids',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'actor_not_found',
          'message': '演员不存在',
        },
      },
    );

    expect(
      () => actorsApi.getActorMovieIds(actorId: 404),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'actor_not_found',
        ),
      ),
    );
  });

  test('getActorMovieYears parses year count list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1/years',
      statusCode: 200,
      body: const <Map<String, dynamic>>[
        <String, dynamic>{'year': 2026, 'movie_count': 18},
        <String, dynamic>{'year': 2025, 'movie_count': 9},
      ],
    );

    final years = await actorsApi.getActorMovieYears(actorId: 1);

    expect(years.map((item) => item.year), <int>[2026, 2025]);
    expect(years.map((item) => item.movieCount), <int>[18, 9]);
    expect(adapter.requests.single.path, '/actors/1/years');
  });

  test('getActorTags parses tag counts scoped to the actor', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1/tags',
      statusCode: 200,
      body: const <Map<String, dynamic>>[
        <String, dynamic>{'tag_id': 3, 'name': '巨乳', 'movie_count': 12},
        <String, dynamic>{'tag_id': 5, 'name': '单体作品', 'movie_count': 8},
      ],
    );

    final tags = await actorsApi.getActorTags(actorId: 1);

    expect(tags.map((item) => item.tagId), <int>[3, 5]);
    expect(tags.map((item) => item.name), <String>['巨乳', '单体作品']);
    expect(tags.map((item) => item.movieCount), <int>[12, 8]);
    expect(adapter.requests.single.path, '/actors/1/tags');
  });

  test('searchActorCandidates parses GFriends candidates', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/gfriends/search',
      statusCode: 200,
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'candidate_id': 'candidate-a',
          'name': '三上悠亚',
          'alias_names': <String>['三上悠亜', '鬼头桃菜'],
          'avatar_url': 'https://cdn.example/actor.jpg',
          'existing_actor_id': 3,
        },
      ],
    );

    final candidates = await actorsApi.searchActorCandidates(query: '三上');

    expect(candidates, hasLength(1));
    expect(candidates.single.candidateId, 'candidate-a');
    expect(candidates.single.aliasNames, contains('鬼头桃菜'));
    expect(candidates.single.existingActorId, 3);
    expect(adapter.requests.single.path, '/actors/gfriends/search');
  });

  test('importActorCandidate imports one candidate', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/actors/gfriends/import',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 9,
        'name': '三上悠亚',
        'alias_name': '三上悠亚 / 鬼头桃菜',
        'display_name': '三上悠亚',
        'profile_image': null,
        'is_subscribed': false,
        'gender': 1,
      },
    );

    final actor = await actorsApi.importActorCandidate(
      candidateId: 'candidate-a',
    );

    expect(actor.summary.id, 9);
    expect(adapter.requests.single.body, <String, dynamic>{
      'candidate_id': 'candidate-a',
    });
  });

  test(
    'subscribeActor sends PUT request to actor subscription endpoint',
    () async {
      adapter.enqueueJson(
        method: 'PUT',
        path: '/actors/1/subscription',
        statusCode: 204,
      );

      await actorsApi.subscribeActor(actorId: 1);

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/actors/1/subscription');
      expect(request.uri.queryParameters, isEmpty);
    },
  );

  test(
    'unsubscribeActor sends DELETE request to actor subscription endpoint',
    () async {
      adapter.enqueueJson(
        method: 'DELETE',
        path: '/actors/1/subscription',
        statusCode: 204,
      );

      await actorsApi.unsubscribeActor(actorId: 1);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/actors/1/subscription');
      expect(request.uri.queryParameters, isEmpty);
    },
  );

  test('mergeActors posts source ids and parses merged detail', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/actors/1/merge',
      statusCode: 200,
      body: _actorDetailResponse(),
    );

    final detail = await actorsApi.mergeActors(
      actorId: 1,
      sourceActorIds: <int>[2, 3],
    );

    expect(detail.summary.id, 1);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/actors/1/merge');
    expect(request.body, <String, dynamic>{
      'source_actor_ids': <int>[2, 3],
    });
  });

  test(
    'createLocalActor posts trimmed identity and parses local detail',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/actors',
        statusCode: 201,
        body: <String, dynamic>{
          'id': 9,
          'name': '本地女优',
          'alias_name': '本地女优 / 别名A / 别名B',
          'display_name': '本地女优',
          'profile_image': null,
          'is_subscribed': false,
          'gender': 1,
          'mutation_revision': 0,
        },
      );

      final detail = await actorsApi.createLocalActor(
        name: ' 本地女优 ',
        aliasName: ' 别名A / 别名B ',
      );

      expect(detail.summary.id, 9);
      expect(detail.summary.displayName, '本地女优');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/actors');
      expect(request.body, <String, dynamic>{
        'name': '本地女优',
        'alias_name': '别名A / 别名B',
        'gender': 1,
      });
    },
  );
}

Map<String, dynamic> _actorDetailResponse() {
  return <String, dynamic>{
    'id': 1,
    'name': '来源名称',
    'alias_name': '',
    'display_name': '来源名称',
    'profile_image': null,
    'is_subscribed': false,
    'gender': 1,
    'mutation_revision': 0,
  };
}
