import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/recent_views/data/api/recent_views_api.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late RecentViewsApi recentViewsApi;

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
    recentViewsApi = RecentViewsApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('record posts entity payload and accepts 204', () async {
    adapter.enqueueJson(method: 'POST', path: '/view-history', statusCode: 204);

    await recentViewsApi.record(
      entityType: RecentViewEntityType.movie,
      entityId: 7,
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.body, <String, dynamic>{
      'entity_type': 'movie',
      'entity_id': 7,
    });
  });

  test(
    'list sends limit and parses full resources, skipping invalid rows',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/view-history',
        body: <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'entity_type': 'movie',
              'viewed_at': '2026-05-08T10:00:00',
              'movie': <String, dynamic>{
                'id': 11,
                'movie_number': 'ABC-001',
                'title': 'Movie 1',
                'cover_image': <String, dynamic>{
                  'id': 1,
                  'origin': '/covers/a.jpg',
                },
                'thin_cover_image': null,
                'release_date': '2026-05-01',
                'duration_minutes': 120,
                'heat': 88,
                'is_subscribed': true,
                'can_play': true,
                'media_items': <dynamic>[],
              },
              'actor': null,
            },
            <String, dynamic>{
              'entity_type': 'actor',
              'viewed_at': '2026-05-08T09:00:00',
              'actor': <String, dynamic>{
                'id': 3,
                'name': 'Actor A',
                'alias_name': '',
                'display_name': 'Actor A',
                'profile_image': null,
                'is_subscribed': false,
                'movie_count': 12,
              },
              'movie': null,
            },
            // 未知类型、非法时间戳、类型与主体不匹配的记录都应被丢弃。
            <String, dynamic>{
              'entity_type': 'video',
              'viewed_at': '2026-05-08T08:00:00',
            },
            <String, dynamic>{
              'entity_type': 'movie',
              'viewed_at': 'not-a-date',
              'movie': <String, dynamic>{'movie_number': 'X', 'title': 'x'},
            },
            <String, dynamic>{
              'entity_type': 'movie',
              'viewed_at': '2026-05-08T07:00:00',
              'actor': <String, dynamic>{'id': 9, 'display_name': 'B'},
            },
          ],
        },
      );

      final entries = await recentViewsApi.list();

      expect(adapter.requests.single.uri.queryParameters['limit'], '200');
      expect(entries, hasLength(2));
      expect(entries[0].entityType, RecentViewEntityType.movie);
      expect(entries[0].movie?.id, 11);
      expect(entries[0].movie?.movieNumber, 'ABC-001');
      expect(entries[0].movie?.heat, 88);
      expect(entries[0].movie?.isSubscribed, isTrue);
      expect(entries[0].movie?.canPlay, isTrue);
      expect(entries[1].entityType, RecentViewEntityType.actor);
      expect(entries[1].actor?.id, 3);
      expect(entries[1].actor?.displayName, 'Actor A');
      expect(entries[1].actor?.movieCount, 12);
    },
  );
}
