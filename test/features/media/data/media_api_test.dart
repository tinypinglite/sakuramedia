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

  test('getInvalidMedia maps pagination and movie cover images', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 100,
            'movie_number': 'ABC-001',
            'movie_title': 'Movie 1',
            'cover_image': <String, dynamic>{
              'id': 10,
              'origin': '/covers/abc-001-origin.webp',
              'small': '/covers/abc-001-small.webp',
              'medium': '/covers/abc-001-medium.webp',
              'large': '/covers/abc-001-large.webp',
            },
            'thin_cover_image': <String, dynamic>{
              'id': 11,
              'origin': '/covers/abc-001-thin-origin.webp',
              'small': '/covers/abc-001-thin-small.webp',
              'medium': '/covers/abc-001-thin-medium.webp',
              'large': '/covers/abc-001-thin-large.webp',
            },
            'path': '/library/main/abc-001.mp4',
            'library_id': 1,
            'library_name': 'Main Library',
            'file_size_bytes': 2147483648,
            'updated_at': '2026-05-12T03:00:00Z',
          },
        ],
        'page': 2,
        'page_size': 10,
        'total': 21,
      },
    );

    final page = await mediaApi.getInvalidMedia(page: 2, pageSize: 10);

    expect(page.page, 2);
    expect(page.pageSize, 10);
    expect(page.total, 21);
    expect(page.items, hasLength(1));
    final item = page.items.single;
    expect(item.id, 100);
    expect(item.movieNumber, 'ABC-001');
    expect(item.movieTitle, 'Movie 1');
    expect(item.coverImage?.bestAvailableUrl, '/covers/abc-001-large.webp');
    expect(
      item.thinCoverImage?.bestAvailableUrl,
      '/covers/abc-001-thin-large.webp',
    );
    expect(item.preferredCoverUrl, '/covers/abc-001-thin-large.webp');
    expect(item.usesThinCover, isTrue);
    expect(item.path, '/library/main/abc-001.mp4');
    expect(item.libraryId, 1);
    expect(item.libraryName, 'Main Library');
    expect(item.fileSizeBytes, 2147483648);
    expect(item.updatedAt, DateTime.parse('2026-05-12T03:00:00Z'));
    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'page': '2',
      'page_size': '10',
    });
  });

  test('getInvalidMedia accepts null cover images', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 101,
            'movie_number': 'ABC-002',
            'movie_title': null,
            'cover_image': null,
            'thin_cover_image': null,
            'path': '/library/main/abc-002.mp4',
            'library_id': null,
            'library_name': null,
            'file_size_bytes': 0,
            'updated_at': '2026-05-13T03:00:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final page = await mediaApi.getInvalidMedia();

    expect(page.items.single.coverImage, isNull);
    expect(page.items.single.thinCoverImage, isNull);
    expect(page.items.single.preferredCoverUrl, isNull);
    expect(page.items.single.displayTitle, '未命名影片');
  });

  test(
    'checkMediaValidity maps POST /media/{media_id}/validity-check',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/media/100/validity-check',
        body: <String, dynamic>{
          'id': 100,
          'path': '/library/main/abc-001.mp4',
          'file_exists': true,
          'valid_before': false,
          'valid_after': true,
          'updated': true,
          'invalidated': false,
          'revived': true,
          'checked_at': '2026-05-13T12:00:00Z',
        },
      );

      final result = await mediaApi.checkMediaValidity(mediaId: 100);

      expect(result.id, 100);
      expect(result.path, '/library/main/abc-001.mp4');
      expect(result.fileExists, isTrue);
      expect(result.validBefore, isFalse);
      expect(result.validAfter, isTrue);
      expect(result.updated, isTrue);
      expect(result.invalidated, isFalse);
      expect(result.revived, isTrue);
      expect(result.checkedAt, DateTime.parse('2026-05-13T12:00:00Z'));
      expect(adapter.hitCount('POST', '/media/100/validity-check'), 1);
    },
  );

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
