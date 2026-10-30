import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  final zh = AppLocalizationsZh();
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

  for (final video in [false, true]) {
    test(
      'orphan point keeps its ${video ? 'video' : 'JAV'} classification',
      () async {
        adapter.enqueueJson(
          method: 'GET',
          path: '/media-points',
          body: {
            'items': [
              {
                'point_id': 20,
                'media_id': null,
                'thumbnail_id': null,
                'movie_number': video ? null : 'ABC-001',
                'video_item_id': video ? 7 : null,
                'offset_seconds': 90,
                'image': {'id': 5, 'origin': '/saved.webp'},
              },
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          },
        );
        final page = await mediaApi.getGlobalMediaPoints(
          kind: video ? 'video' : 'jav',
        );
        final point = page.items.single;
        expect(point.mediaId, 0);
        expect(point.thumbnailId, 0);
        expect(point.isVideo, video);
        expect(point.image?.origin, '/saved.webp');
        adapter.enqueueJson(
          method: 'DELETE',
          path: '/media-points/20',
          statusCode: 204,
          body: null,
        );
        await mediaApi.deleteMediaPoint(pointId: point.pointId);
        expect(adapter.hitCount('DELETE', '/media-points/20'), 1);
      },
    );
  }

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
            'origin': '/points/88-large.webp',
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
    expect(points.single.image?.origin, '/points/88-large.webp');
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
              'origin': '/points/88-large.webp',
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
    expect(page.items.single.image?.origin, '/points/88-large.webp');
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
                'origin': '/points/v18-large.webp',
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

  test('getGlobalMediaPoints passes keyword and exclude_collection_id', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: <String, dynamic>{
        'items': <dynamic>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );

    await mediaApi.getGlobalMediaPoints(
      page: 1,
      pageSize: 24,
      kind: 'all',
      keyword: '  日落  ',
      excludeCollectionId: 7,
    );

    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'page': '1',
      'page_size': '24',
      'sort': 'created_at:desc',
      'kind': 'all',
      'keyword': '日落',
      'exclude_collection_id': '7',
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
              'origin': '/covers/abc-001-large.webp',
            },
            'thin_cover_image': <String, dynamic>{
              'id': 11,
              'origin': '/covers/abc-001-thin-large.webp',
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
    expect(item.coverImage?.origin, '/covers/abc-001-large.webp');
    expect(
      item.thinCoverImage?.origin,
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
    expect(page.items.single.displayTitle(zh), '未命名媒体');
  });

  test('getDuplicateMediaGroups maps grouped media and kind query', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'kind': 'jav',
            'media_count': 2,
            'media_items': [
              _duplicateMediaItemJson(id: 100),
              _duplicateMediaItemJson(id: 101),
            ],
          },
        ],
        'page': 2,
        'page_size': 20,
        'total': 3,
      },
    );

    final page = await mediaApi.getDuplicateMediaGroups(kind: 'jav', page: 2);

    expect(page.page, 2);
    expect(page.total, 3);
    expect(page.items, hasLength(1));
    expect(page.items.single.kind.name, 'jav');
    expect(page.items.single.mediaCount, 2);
    expect(page.items.single.mediaItems.map((item) => item.id), [100, 101]);
    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'kind': 'jav',
      'page': '2',
      'page_size': '20',
    });
  });

  test('getDuplicateMediaGroups maps video collection refs', () async {
    final videoItem = _duplicateMediaItemJson(id: 100)
      ..['kind'] = 'video'
      ..['movie_number'] = null
      ..['video_item_id'] = 10
      ..['collections'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 3, 'name': '收藏'},
        <String, dynamic>{'id': 8, 'name': '稍后再看'},
      ];
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'kind': 'video',
            'media_count': 1,
            'media_items': [videoItem],
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final page = await mediaApi.getDuplicateMediaGroups(kind: 'video');

    expect(
      page.items.single.mediaItems.single.collections.map((item) => item.id),
      [3, 8],
    );
    expect(
      page.items.single.mediaItems.single.collections.map((item) => item.name),
      ['收藏', '稍后再看'],
    );
  });

  test('createMediaPoint maps POST /media-points', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media-points',
      statusCode: 201,
      body: <String, dynamic>{
        'point_id': 20,
        'media_id': 100,
        'thumbnail_id': 66,
        'offset_seconds': 600,
        'image': <String, dynamic>{
          'id': 9901,
          'origin': '/points/66-large.webp',
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
    expect(adapter.hitCount('POST', '/media-points'), 1);
    expect(adapter.requests.single.body, <String, dynamic>{
      'media_id': 100,
      'thumbnail_id': 66,
    });
  });

  test(
    'deleteMediaPoint maps DELETE /media-points/{point_id}',
    () async {
      adapter.enqueueJson(
        method: 'DELETE',
        path: '/media-points/20',
        statusCode: 204,
      );

      await mediaApi.deleteMediaPoint(pointId: 20);

      expect(adapter.hitCount('DELETE', '/media-points/20'), 1);
    },
  );

  test(
    'media transfer candidates and submission use provider-neutral payloads',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/media-transfers/candidates',
        body: <String, dynamic>{
          'source_library': <String, dynamic>{'id': 3, 'name': '影视库'},
          'targets': <Map<String, dynamic>>[
            <String, dynamic>{'id': 8, 'name': '归档库'},
          ],
        },
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/media-transfers',
        statusCode: 202,
        body: <String, dynamic>{
          'task_run_id': 91,
          'task_key': 'media_storage_transfer',
          'state': 'pending',
        },
      );

      final candidates = await mediaApi.getMediaTransferCandidates(
        mediaIds: const <int>[10, 11],
      );
      final accepted = await mediaApi.createMediaTransfer(
        mediaIds: const <int>[10, 11],
        targetLibraryId: candidates.targets.single.id,
      );

      expect(candidates.sourceLibrary.name, '影视库');
      expect(candidates.targets.single.name, '归档库');
      expect(accepted.taskRunId, 91);
      expect(adapter.requests[0].body, <String, dynamic>{
        'media_ids': <int>[10, 11],
      });
      expect(adapter.requests[1].body, <String, dynamic>{
        'media_ids': <int>[10, 11],
        'target_library_id': 8,
      });
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
        search: '  mixed.case  ',
        thumbnailGenerationState: 'terminal',
        sort: 'heat:desc',
      );

      expect(adapter.requests.single.uri.queryParameters, <String, String>{
        'page': '2',
        'page_size': '30',
        'kind': 'jav',
        'library_id': '5',
        'actor_ids': '12,34',
        'search': 'mixed.case',
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

  test('resetMediaThumbnails posts selected media IDs without force', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 2},
    );

    final resetCount = await mediaApi.resetMediaThumbnails(mediaIds: [12, 34]);

    expect(resetCount, 2);
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/media/thumbnails/reset');
    expect(adapter.requests.single.body, <String, dynamic>{
      'media_ids': <int>[12, 34],
      'force': false,
    });
  });

  test('resetMediaThumbnails posts force when regenerating', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 1},
    );

    final resetCount = await mediaApi.resetMediaThumbnails(
      mediaIds: [12],
      force: true,
    );

    expect(resetCount, 1);
    expect(adapter.requests.single.body, <String, dynamic>{
      'media_ids': <int>[12],
      'force': true,
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
              'origin': '/covers/abc-001-large.webp',
            },
            'thin_cover_image': null,
            'library_id': 1,
            'library_name': 'Main',
            'file_name': 'abc-001.mp4',
            'file_size_bytes': 2147483648,
            'duration_seconds': 5400,
            'resolution': '1920x1080',
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
    expect(jav.displayHeading(zh), 'ABC-001');
    expect(jav.displaySubtitle, 'Movie 1');
    expect(jav.heat, 320);
    final video = page.items.last;
    expect(video.isVideo, isTrue);
    expect(video.videoItemId, 999);
    expect(video.valid, isFalse);
    expect(video.heat, isNull);
    expect(video.displayHeading(zh), 'Short video');
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

Map<String, dynamic> _duplicateMediaItemJson({required int id}) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'DUP-$id',
    'video_item_id': null,
    'title': 'Duplicate $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main',
    'file_name': 'duplicate-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'valid': true,
    'thumbnail_generation_state': 'succeeded',
    'thumbnail_last_error_code': null,
    'heat': 100,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}
