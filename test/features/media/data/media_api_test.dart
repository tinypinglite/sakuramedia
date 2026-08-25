import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';

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
    expect(page.items.single.videoItemId, isNull);
    expect(page.items.single.isVideo, isFalse);
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

  test(
    'getGlobalMediaPoints passes kind and parses video item moments',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media-points',
        body: <String, dynamic>{
          'items': [
            <String, dynamic>{
              'point_id': 11,
              'media_id': 200,
              'movie_number': null,
              'video_item_id': 999,
              'thumbnail_id': 18,
              'offset_seconds': 360,
              'image': <String, dynamic>{
                'id': 9100,
                'origin': '/points/v18-origin.webp',
                'small': '/points/v18-small.webp',
                'medium': '/points/v18-medium.webp',
                'large': '/points/v18-large.webp',
              },
              'created_at': '2026-03-12T11:00:00Z',
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
        kind: 'video',
      );

      expect(page.items.single.movieNumber, isNull);
      expect(page.items.single.videoItemId, 999);
      expect(page.items.single.isVideo, isTrue);
      expect(adapter.requests.single.uri.queryParameters, <String, String>{
        'page': '1',
        'page_size': '20',
        'sort': 'created_at:desc',
        'kind': 'video',
      });
    },
  );

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
            'file_name': 'abc-001.mp4',
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
    expect(item.fileName, 'abc-001.mp4');
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
            'file_name': 'abc-002.mp4',
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
    expect(page.items.single.displayTitle, '未命名媒体');
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

  test(
    'getMediaList sends backend-supported filters and sort params',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media',
        body: <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
      );

      await mediaApi.getMediaList(
        page: 2,
        pageSize: 30,
        kind: 'jav',
        libraryId: 5,
        actorIds: const <int>[12, 34],
        thumbnailGenerationState: 'terminal',
        sort: 'heat:desc',
      );

      expect(adapter.requests.single.uri.queryParameters, <String, String>{
        'page': '2',
        'page_size': '30',
        'kind': 'jav',
        'library_id': '5',
        'actor_ids': '12,34',
        'thumbnail_generation_state': 'terminal',
        'sort': 'heat:desc',
      });
    },
  );

  test('getMediaList omits optional query params when not provided', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );

    await mediaApi.getMediaList();

    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'page': '1',
      'page_size': '20',
    });
  });

  test('getMediaList parses jav and video items', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 100,
            'kind': 'jav',
            'movie_number': 'ABC-001',
            'video_item_id': null,
            'title': 'Movie 1',
            'cover_image': <String, dynamic>{
              'id': 88,
              'origin': '/covers/abc-001-origin.webp',
              'small': '/covers/abc-001-small.webp',
              'medium': '/covers/abc-001-medium.webp',
              'large': '/covers/abc-001-large.webp',
            },
            'thin_cover_image': null,
            'library_id': 1,
            'library_name': 'Main',
            'file_name': 'abc-001.mp4',
            'file_size_bytes': 2147483648,
            'duration_seconds': 5400,
            'resolution': '1920x1080',
            'special_tags': '普通',
            'valid': true,
            'thumbnail_generation_state': 'terminal',
            'thumbnail_last_error_code': 'thumbnail_backend_failed',
            'heat': 320,
            'created_at': '2026-03-12T10:20:00Z',
            'updated_at': '2026-03-12T10:20:00Z',
          },
          <String, dynamic>{
            'id': 200,
            'kind': 'video',
            'movie_number': null,
            'video_item_id': 999,
            'title': 'Short video',
            'cover_image': null,
            'thin_cover_image': null,
            'library_id': 2,
            'library_name': null,
            'file_name': 'episode.mp4',
            'file_size_bytes': 100,
            'duration_seconds': 0,
            'resolution': null,
            'special_tags': '',
            'valid': false,
            'thumbnail_generation_state': 'succeeded',
            'heat': null,
            'created_at': '2026-03-12T10:20:00Z',
            'updated_at': '2026-03-12T10:20:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 2,
      },
    );

    final page = await mediaApi.getMediaList();

    expect(page.items, hasLength(2));
    final jav = page.items.first;
    expect(jav.isJav, isTrue);
    expect(jav.movieNumber, 'ABC-001');
    expect(jav.displayHeading, 'ABC-001');
    expect(jav.displaySubtitle, 'Movie 1');
    expect(jav.heat, 320);
    final video = page.items.last;
    expect(video.isVideo, isTrue);
    expect(video.videoItemId, 999);
    expect(video.valid, isFalse);
    expect(video.heat, isNull);
    expect(video.displayHeading, 'Short video');
    expect(video.displaySubtitle, isNull);
    expect(
      jav.thumbnailGenerationState,
      MediaThumbnailGenerationState.terminal,
    );
    expect(jav.thumbnailLastErrorCode, 'thumbnail_backend_failed');
    expect(
      video.thumbnailGenerationState,
      MediaThumbnailGenerationState.succeeded,
    );
  });
}
