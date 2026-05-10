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
              'javdb_id': 'abc-id',
              'movie_number': 'ABC-001',
              'title': 'Movie title',
              'title_zh': '中文标题',
              'cover_image': <String, dynamic>{
                'id': 1,
                'origin': 'origin.jpg',
                'small': 'small.jpg',
                'medium': 'medium.jpg',
                'large': 'large.jpg',
              },
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
      expect(page.items.single.movie.preferredTitle, '中文标题');
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
                'origin': 'thumb-origin.webp',
                'small': 'thumb-small.webp',
                'medium': 'thumb-medium.webp',
                'large': 'thumb-large.webp',
              },
              'movie': <String, dynamic>{
                'javdb_id': 'abc-id',
                'movie_number': 'ABC-001',
                'title': 'Movie title',
                'title_zh': '',
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
      expect(page.items.single.image?.bestAvailableUrl, 'thumb-large.webp');
      expect(page.items.single.movie.movieNumber, 'ABC-001');
    },
  );
}
