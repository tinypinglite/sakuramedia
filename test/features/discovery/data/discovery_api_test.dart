import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late DiscoveryApi discoveryApi;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-05-08T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    discoveryApi = DiscoveryApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
  });

  test(
    'getDailyRecommendations sends paging query and parses extras',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/daily-recommendations',
        body: <String, dynamic>{
          'items': [
            <String, dynamic>{
              'movie_number': 'ABC-001',
              'title': 'Movie title',
              'cover_image': <String, dynamic>{'id': 1, 'origin': 'large.jpg'},
              'thin_cover_image': null,
              'release_date': '2026-05-01',
              'duration_minutes': 120,
              'heat': 88,
              'is_subscribed': false,
              'can_play': true,
              'snapshot_date': '2026-05-08',
              'generated_at': '2026-05-08T04:00:00',
              'rank': 3,
              'recommendation_score': 0.91,
              'reason_codes': ['popular'],
              'reason_texts': ['近期热度较高'],
              'signal_scores': <String, dynamic>{'heat': 0.8},
              'is_stale': true,
            },
          ],
          'page': 2,
          'page_size': 10,
          'total': 30,
        },
      );

      final page = await discoveryApi.getDailyRecommendations(
        page: 2,
        pageSize: 10,
      );

      final request = adapter.requests.single;
      expect(request.path, '/daily-recommendations');
      expect(request.uri.queryParameters['page'], '2');
      expect(request.uri.queryParameters['page_size'], '10');
      expect(page.total, 30);
      expect(page.items.single.movie.movieNumber, 'ABC-001');
      expect(page.items.single.movie.preferredTitle, 'Movie title');
      expect(page.items.single.rank, 3);
      expect(page.items.single.recommendationScore, 0.91);
      expect(page.items.single.reasonTexts, ['近期热度较高']);
      expect(page.items.single.signalScores['heat'], 0.8);
      expect(page.items.single.isStale, isTrue);
    },
  );

  test(
    'getMomentRecommendations parses generated time and nested movie',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/moment-recommendations',
        body: <String, dynamic>{
          'items': [
            <String, dynamic>{
              'recommendation_id': 1,
              'rank': 1,
              'score': 0.88,
              'strategy': 'visual',
              'reason': '与你收藏的时刻画面相似',
              'media_id': 100,
              'thumbnail_id': 500,
              'offset_seconds': 360,
              'image': <String, dynamic>{
                'id': 88,
                'origin': 'thumb-large.webp',
              },
              'movie': <String, dynamic>{
                'movie_number': 'ABC-001',
                'title': 'Movie title',
                'cover_image': null,
                'thin_cover_image': null,
                'release_date': null,
                'duration_minutes': 120,
                'heat': 10,
                'is_subscribed': false,
                'can_play': true,
              },
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
          'generated_at': '2026-05-08T04:00:00',
        },
      );

      final page = await discoveryApi.getMomentRecommendations();

      final request = adapter.requests.single;
      expect(request.path, '/moment-recommendations');
      expect(request.uri.queryParameters['page'], '1');
      expect(request.uri.queryParameters['page_size'], '20');
      expect(page.generatedAt, DateTime.parse('2026-05-08T04:00:00'));
      expect(page.items.single.recommendationId, 1);
      expect(page.items.single.strategy, 'visual');
      expect(page.items.single.reason, '与你收藏的时刻画面相似');
      expect(page.items.single.mediaId, 100);
      expect(page.items.single.thumbnailId, 500);
      expect(page.items.single.offsetSeconds, 360);
      expect(page.items.single.image?.origin, 'thumb-large.webp');
      expect(page.items.single.movie.movieNumber, 'ABC-001');
    },
  );

  test(
    'getHotActressReleases sends paging query and parses actress name',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/hot-actress-releases',
        body: <String, dynamic>{
          'items': [
            <String, dynamic>{
              'movie_number': 'HOT-001',
              'title': 'Hot movie',
              'cover_image': null,
              'thin_cover_image': null,
              'release_date': '2026-08-20',
              'duration_minutes': 120,
              'heat': 0,
              'is_subscribed': false,
              'can_play': false,
              'recommendation_score': 3.4,
              'hot_actress': <String, dynamic>{
                'id': 1,
                'name': '女优 A',
                'historical_movie_count': 4,
                'hotness_score': 3.4,
              },
            },
          ],
          'page': 2,
          'page_size': 10,
          'total': 30,
        },
      );

      final page = await discoveryApi.getHotActressReleases(
        page: 2,
        pageSize: 10,
      );

      final request = adapter.requests.single;
      expect(request.path, '/hot-actress-releases');
      expect(request.uri.queryParameters['page'], '2');
      expect(request.uri.queryParameters['page_size'], '10');
      expect(page.total, 30);
      expect(page.items.single.movie.movieNumber, 'HOT-001');
      expect(page.items.single.hotActressName, '女优 A');
    },
  );

  test('getTasteProfile parses ranked actresses and tags', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/taste-profile',
      body: _tasteProfileJson(),
    );

    final profile = await discoveryApi.getTasteProfile();

    expect(adapter.requests.single.path, '/taste-profile');
    expect(profile.sampleMovieCount, 42);
    expect(profile.subscribedActresses.single.actor.displayName, '女优 A');
    expect(profile.subscribedActresses.single.actor.isSubscribed, isTrue);
    expect(profile.subscribedActresses.single.matchedMovieCount, 12);
    expect(profile.unsubscribedActresses.single.actor.id, 2);
    expect(profile.tags.single.name, '剧情');
    expect(profile.tags.single.matchedMovieCount, 9);
  });
}

Map<String, dynamic> _tasteProfileJson() {
  return <String, dynamic>{
    'sample_movie_count': 42,
    'generated_at': '2026-10-23T04:00:00',
    'actresses': <dynamic>[
      <String, dynamic>{
        'actor': _actorJson(id: 1, name: '女优 A', isSubscribed: true),
        'matched_movie_count': 12,
        'score': 38.0,
      },
    ],
    'unsubscribed_actresses': <dynamic>[
      <String, dynamic>{
        'actor': _actorJson(id: 2, name: '女优 B', isSubscribed: false),
        'matched_movie_count': 5,
        'score': 11.0,
      },
    ],
    'tags': <dynamic>[
      <String, dynamic>{
        'tag_id': 7,
        'name': '剧情',
        'matched_movie_count': 9,
        'score': 21.0,
      },
    ],
  };
}

Map<String, dynamic> _actorJson({
  required int id,
  required String name,
  required bool isSubscribed,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'alias_name': '',
    'display_name': name,
    'profile_image': <String, dynamic>{'id': id, 'origin': 'actor-$id.jpg'},
    'is_subscribed': isSubscribed,
    'movie_count': 10,
  };
}
