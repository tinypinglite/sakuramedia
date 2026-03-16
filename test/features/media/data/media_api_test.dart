import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaApi mediaApi;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    mediaApi = MediaApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getMediaPoints maps GET /media/{media_id}/points', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/points',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'point_id': 10,
          'media_id': 100,
          'thumbnail_id': 88,
          'offset_seconds': 120,
          'image': <String, dynamic>{
            'id': 9001,
            'origin': '/points/88-origin.webp',
            'small': '/points/88-small.webp',
            'medium': '/points/88-medium.webp',
            'large': '/points/88-large.webp',
          },
          'created_at': '2026-03-12T10:00:00Z',
        },
      ],
    );

    final points = await mediaApi.getMediaPoints(mediaId: 100);

    expect(points, hasLength(1));
    expect(points.single.pointId, 10);
    expect(points.single.mediaId, 100);
    expect(points.single.thumbnailId, 88);
    expect(points.single.offsetSeconds, 120);
    expect(points.single.image?.bestAvailableUrl, '/points/88-large.webp');
    expect(points.single.createdAt, DateTime.parse('2026-03-12T10:00:00Z'));
  });

  test('getGlobalMediaPoints maps GET /media-points with pagination', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'point_id': 10,
            'media_id': 100,
            'movie_number': 'ABC-001',
            'thumbnail_id': 88,
            'offset_seconds': 120,
            'image': <String, dynamic>{
              'id': 9001,
              'origin': '/points/88-origin.webp',
              'small': '/points/88-small.webp',
              'medium': '/points/88-medium.webp',
              'large': '/points/88-large.webp',
            },
            'created_at': '2026-03-12T10:00:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final page = await mediaApi.getGlobalMediaPoints(
      page: 1,
      pageSize: 20,
      sort: 'created_at:desc',
    );

    expect(page.items, hasLength(1));
    expect(page.items.single.pointId, 10);
    expect(page.items.single.mediaId, 100);
    expect(page.items.single.movieNumber, 'ABC-001');
    expect(page.items.single.thumbnailId, 88);
    expect(page.items.single.offsetSeconds, 120);
    expect(page.items.single.image?.bestAvailableUrl, '/points/88-large.webp');
    expect(page.items.single.createdAt, DateTime.parse('2026-03-12T10:00:00Z'));
    expect(page.total, 1);
    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'page': '1',
      'page_size': '20',
      'sort': 'created_at:desc',
    });
  });

  test('createMediaPoint maps POST /media/{media_id}/points', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/100/points',
      statusCode: 201,
      body: <String, dynamic>{
        'point_id': 20,
        'media_id': 100,
        'thumbnail_id': 66,
        'offset_seconds': 600,
        'image': <String, dynamic>{
          'id': 9901,
          'origin': '/points/66-origin.webp',
          'small': '/points/66-small.webp',
          'medium': '/points/66-medium.webp',
          'large': '/points/66-large.webp',
        },
        'created_at': '2026-03-12T14:00:00Z',
      },
    );

    final point = await mediaApi.createMediaPoint(
      mediaId: 100,
      thumbnailId: 66,
    );

    expect(point.pointId, 20);
    expect(point.thumbnailId, 66);
    expect(point.offsetSeconds, 600);
    expect(adapter.hitCount('POST', '/media/100/points'), 1);
    expect(adapter.requests.single.body, <String, dynamic>{'thumbnail_id': 66});
  });

  test(
    'deleteMediaPoint maps DELETE /media/{media_id}/points/{point_id}',
    () async {
      adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/100/points/20',
        statusCode: 204,
      );

      await mediaApi.deleteMediaPoint(mediaId: 100, pointId: 20);

      expect(adapter.hitCount('DELETE', '/media/100/points/20'), 1);
    },
  );
}
