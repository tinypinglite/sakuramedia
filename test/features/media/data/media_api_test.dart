import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';

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

  test('getGlobalMediaPoints passes kind and parses video item moments', () async {
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

  test('getMediaList sends kind/library/actor/rapid-upload/sort query params',
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
      rapidUploadStatus: 'in_progress',
      sort: 'heat:desc',
    );

    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'page': '2',
      'page_size': '30',
      'kind': 'jav',
      'library_id': '5',
      'actor_ids': '12,34',
      'rapid_upload_status': 'in_progress',
      'sort': 'heat:desc',
    });
  });

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
            'path': '/library/main/abc-001.mp4',
            'file_size_bytes': 2147483648,
            'duration_seconds': 5400,
            'resolution': '1920x1080',
            'special_tags': '普通',
            'valid': true,
            'heat': 320,
            'last_rapid_upload_status': 'in_progress',
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
            'path': 'cloud115:episode.mp4',
            'file_size_bytes': 100,
            'duration_seconds': 0,
            'resolution': null,
            'special_tags': '',
            'valid': false,
            'heat': null,
            'last_rapid_upload_status': null,
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
    expect(jav.lastRapidUploadStatus, LastRapidUploadStatus.inProgress);
    expect(video.lastRapidUploadStatus, isNull);
  });

  test('LastRapidUploadStatus.fromWire maps all public backend values', () {
    // 后端对外值域见 src/service/transfers/media_rapid_upload_service.py 的
    // PUBLIC_STATUS_* 常量；缺席/null → null，未识别 → unknown（UI 当无状态处理）。
    expect(LastRapidUploadStatusX.fromWire(null), isNull);
    expect(
      LastRapidUploadStatusX.fromWire('not_hit'),
      LastRapidUploadStatus.notHit,
    );
    expect(
      LastRapidUploadStatusX.fromWire('failed'),
      LastRapidUploadStatus.failed,
    );
    expect(
      LastRapidUploadStatusX.fromWire('cleanup_failed'),
      LastRapidUploadStatus.cleanupFailed,
    );
    expect(
      LastRapidUploadStatusX.fromWire('in_progress'),
      LastRapidUploadStatus.inProgress,
    );
    expect(
      LastRapidUploadStatusX.fromWire('some_future_state'),
      LastRapidUploadStatus.unknown,
    );
  });

  test('createMediaRapidUpload posts media_ids + target_library_id', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/rapid-uploads',
      statusCode: 202,
      body: <String, dynamic>{
        'rapid_upload_batch_id': 42,
        'task_run_id': 99,
        'status': 'accepted',
      },
    );

    final response = await mediaApi.createMediaRapidUpload(
      mediaIds: const <int>[10, 20, 30],
      targetLibraryId: 8,
    );

    expect(response.batchId, 42);
    expect(response.taskRunId, 99);
    expect(response.status, 'accepted');
    expect(adapter.requests.single.body, <String, dynamic>{
      'media_ids': <int>[10, 20, 30],
      'target_library_id': 8,
    });
  });

  test('getMediaRapidUploads returns a paginated batch list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 42,
            'target_library_id': 8,
            'retry_of_batch_id': null,
            'task_run_id': 99,
            'state': 'completed',
            'total_count': 3,
            'succeeded_count': 3,
            'failed_count': 0,
            'cleanup_failed_count': 0,
            'started_at': '2026-03-12T10:00:00Z',
            'finished_at': '2026-03-12T10:05:00Z',
            'created_at': '2026-03-12T09:59:00Z',
            'updated_at': '2026-03-12T10:05:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final page = await mediaApi.getMediaRapidUploads();

    expect(page.total, 1);
    expect(page.items.single.id, 42);
    expect(page.items.single.hasRetryable, isFalse);
    expect(page.items.single.pendingCount, 0);
  });

  test('getMediaRapidUpload returns a batch with items', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads/42',
      body: <String, dynamic>{
        'id': 42,
        'target_library_id': 8,
        'retry_of_batch_id': null,
        'task_run_id': 99,
        'state': 'completed_with_errors',
        'total_count': 3,
        'succeeded_count': 2,
        'failed_count': 1,
        'cleanup_failed_count': 0,
        'started_at': '2026-03-12T10:00:00Z',
        'finished_at': '2026-03-12T10:05:00Z',
        'created_at': '2026-03-12T09:59:00Z',
        'updated_at': '2026-03-12T10:05:00Z',
        'items': [
          <String, dynamic>{
            'id': 1,
            'media_id': 10,
            'action': 'rapid_upload',
            'state': 'succeeded',
            'source_path': '/library/main/a.mp4',
            'source_size_bytes': 100,
            'source_sha1': 'abcdef',
            'target_fid': 'fid-1',
            'target_pickcode': 'pc-1',
            'target_name': 'a.mp4',
            'error_message': null,
            'started_at': '2026-03-12T10:00:00Z',
            'finished_at': '2026-03-12T10:01:00Z',
            'created_at': '2026-03-12T09:59:00Z',
            'updated_at': '2026-03-12T10:01:00Z',
          },
          <String, dynamic>{
            'id': 2,
            'media_id': 20,
            'action': 'rapid_upload',
            'state': 'failed',
            'source_path': '/library/main/b.mp4',
            'source_size_bytes': 200,
            'source_sha1': null,
            'target_fid': null,
            'target_pickcode': null,
            'target_name': null,
            'error_message': 'boom',
            'started_at': '2026-03-12T10:00:00Z',
            'finished_at': '2026-03-12T10:01:00Z',
            'created_at': '2026-03-12T09:59:00Z',
            'updated_at': '2026-03-12T10:01:00Z',
          },
        ],
      },
    );

    final batch = await mediaApi.getMediaRapidUpload(batchId: 42);

    expect(batch.id, 42);
    expect(batch.state.label, '部分完成');
    expect(batch.hasRetryable, isTrue);
    expect(batch.items, hasLength(2));
    expect(batch.items.first.state.isTerminal, isTrue);
    expect(batch.items.last.state.isRetryable, isTrue);
    expect(batch.items.last.errorMessage, 'boom');
  });

  test('retryMediaRapidUpload posts to /retry endpoint', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/rapid-uploads/42/retry',
      statusCode: 202,
      body: <String, dynamic>{
        'rapid_upload_batch_id': 43,
        'task_run_id': 100,
        'status': 'accepted',
      },
    );

    final response = await mediaApi.retryMediaRapidUpload(batchId: 42);

    expect(response.batchId, 43);
    expect(adapter.hitCount('POST', '/media/rapid-uploads/42/retry'), 1);
  });
}
