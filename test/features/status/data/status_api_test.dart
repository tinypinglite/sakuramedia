import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late StatusApi statusApi;
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
    statusApi = StatusApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getStatus parses nested stats', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 200,
      body: <String, dynamic>{
        'backend_version': 'v0.2.0',
        'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
        'movies': <String, dynamic>{
          'total': 120,
          'subscribed': 35,
          'playable': 88,
        },
        'media_files': <String, dynamic>{
          'total': 156,
          'total_size_bytes': 987654321,
        },
        'media_libraries': <String, dynamic>{'total': 3},
        'thumbnails': <String, dynamic>{
          'pending_media': 24,
          'retry_wait_media': 6,
          'terminal_failed_media': 2,
          'total': 132,
        },
      },
    );

    final status = await statusApi.getStatus();

    expect(status.backendVersion, 'v0.2.0');
    expect(status.actors.femaleTotal, 12);
    expect(status.movies.total, 120);
    expect(status.mediaFiles.totalSizeBytes, 987654321);
    expect(status.mediaLibraries.total, 3);
    expect(status.thumbnails.pendingMedia, 24);
    expect(status.thumbnails.retryWaitMedia, 6);
    expect(status.thumbnails.terminalFailedMedia, 2);
    expect(status.thumbnails.total, 132);
    expect(status.toJson()['thumbnails'], <String, dynamic>{
      'pending_media': 24,
      'retry_wait_media': 6,
      'terminal_failed_media': 2,
      'total': 132,
    });
    expect(status.toJson()['backend_version'], 'v0.2.0');
  });

  test('getStatus defaults missing thumbnails to zero', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 200,
      body: <String, dynamic>{
        'backend_version': 'v0.2.0',
        'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
        'movies': <String, dynamic>{
          'total': 120,
          'subscribed': 35,
          'playable': 88,
        },
        'media_files': <String, dynamic>{
          'total': 156,
          'total_size_bytes': 987654321,
        },
        'media_libraries': <String, dynamic>{'total': 3},
      },
    );

    final status = await statusApi.getStatus();

    expect(status.thumbnails.pendingMedia, 0);
    expect(status.thumbnails.retryWaitMedia, 0);
    expect(status.thumbnails.terminalFailedMedia, 0);
    expect(status.thumbnails.total, 0);
  });

  test('getStatus defaults missing backend version to empty string', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 200,
      body: <String, dynamic>{
        'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
        'movies': <String, dynamic>{
          'total': 120,
          'subscribed': 35,
          'playable': 88,
        },
        'media_files': <String, dynamic>{
          'total': 156,
          'total_size_bytes': 987654321,
        },
        'media_libraries': <String, dynamic>{'total': 3},
      },
    );

    final status = await statusApi.getStatus();

    expect(status.backendVersion, isEmpty);
    expect(status.toJson()['backend_version'], isEmpty);
  });

  test('getStatus converts backend error to ApiException', () async {
    await sessionStore.clearSession();
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Unauthorized',
        },
      },
    );

    expect(
      () => statusApi.getStatus(),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'unauthorized',
        ),
      ),
    );
  });

  test(
    'checks the latest backend release without sending the login token',
    () async {
      const releaseUrl =
          'https://api.github.com/repos/tinypinglite/sakuramediabe/releases/latest';
      adapter.enqueueJson(
        method: 'GET',
        path: releaseUrl,
        body: <String, dynamic>{'tag_name': 'v0.2.1'},
      );

      final updateVersion = await statusApi.checkBackendUpdate('v0.2.0');

      expect(updateVersion, 'v0.2.1');
      final request = adapter.requests.single;
      expect(request.path, releaseUrl);
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.connectTimeout, const Duration(seconds: 10));
      expect(request.receiveTimeout, const Duration(seconds: 10));
    },
  );

  test(
    'checks the latest frontend release without sending the login token',
    () async {
      const releaseUrl =
          'https://api.github.com/repos/tinypinglite/sakuramedia/releases/latest';
      adapter.enqueueJson(
        method: 'GET',
        path: releaseUrl,
        body: <String, dynamic>{'tag_name': 'v0.2.4'},
      );

      final updateVersion = await statusApi.checkFrontendUpdate('0.2.3');

      expect(updateVersion, 'v0.2.4');
      final request = adapter.requests.single;
      expect(request.path, releaseUrl);
      expect(request.headers.containsKey('Authorization'), isFalse);
    },
  );

  test('skips the release request for a local backend version', () async {
    final updateVersion = await statusApi.checkBackendUpdate('dev-local');

    expect(updateVersion, isNull);
    expect(adapter.requests, isEmpty);
  });

  test('offers the stable release to a client running a beta', () async {
    const releaseUrl =
        'https://api.github.com/repos/tinypinglite/sakuramedia/releases/latest';
    adapter.enqueueJson(
      method: 'GET',
      path: releaseUrl,
      body: <String, dynamic>{'tag_name': 'v0.10.0'},
    );

    final updateVersion = await statusApi.checkFrontendUpdate('0.10.0-beta.1');

    expect(updateVersion, 'v0.10.0');
  });

  test('treats an invalid release tag as no update', () async {
    const releaseUrl =
        'https://api.github.com/repos/tinypinglite/sakuramediabe/releases/latest';
    adapter.enqueueJson(
      method: 'GET',
      path: releaseUrl,
      body: <String, dynamic>{'tag_name': 'nightly'},
    );

    final updateVersion = await statusApi.checkBackendUpdate('v0.2.0');

    expect(updateVersion, isNull);
  });

  test('getCapabilities parses both switches', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/capabilities',
      statusCode: 200,
      body: <String, dynamic>{'movie_similarity': true, 'image_search': false},
    );

    final capabilities = await statusApi.getCapabilities();

    expect(capabilities.movieSimilarity, isTrue);
    expect(capabilities.imageSearch, isFalse);
  });

  test(
    'getImageSearchStatus parses embedding service and indexing stats',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/status/image-search',
        statusCode: 200,
        body: <String, dynamic>{
          'healthy': true,
          'embedding_service': <String, dynamic>{
            'healthy': true,
            'endpoint': 'http://embedding:8000',
            'space_id': 'clip-vit-l-14',
            'dimension': 768,
            'modalities': <String>['image', 'text'],
          },
          'indexing': <String, dynamic>{
            'pending_thumbnails': 23,
            'failed_thumbnails': 2,
          },
          'index_space': <String, dynamic>{
            'state': 'ready',
            'indexed_space_id': 'clip-vit-l-14',
            'current_space_id': 'clip-vit-l-14',
            'is_rebuilding': true,
          },
        },
      );

      final status = await statusApi.getImageSearchStatus();

      expect(status.healthy, isTrue);
      expect(status.embeddingService.healthy, isTrue);
      expect(status.embeddingService.spaceId, 'clip-vit-l-14');
      expect(status.embeddingService.dimension, 768);
      expect(status.embeddingService.endpoint, 'http://embedding:8000');
      expect(status.indexing.pendingThumbnails, 23);
      expect(status.indexing.failedThumbnails, 2);
      expect(status.indexSpace.state, 'ready');
      expect(status.indexSpace.indexedSpaceId, 'clip-vit-l-14');
      expect(status.indexSpace.currentSpaceId, 'clip-vit-l-14');
      expect(status.indexSpace.isRebuilding, isTrue);
    },
  );

  test('getImageSearchStatus 保留嵌入服务的失败原因', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      statusCode: 200,
      body: <String, dynamic>{
        'healthy': false,
        'embedding_service': <String, dynamic>{
          'healthy': false,
          'endpoint': 'http://embedding:8000',
          'error': 'model file not found',
        },
        'indexing': <String, dynamic>{
          'pending_thumbnails': 0,
          'failed_thumbnails': 0,
        },
      },
    );

    final status = await statusApi.getImageSearchStatus();

    // 诊断页要拿它当状态短句，比前端硬编码的"模型未就绪"有用。
    expect(status.embeddingService.error, 'model file not found');
  });

  test('resetImageSearch posts reset request', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/reset',
      body: <String, dynamic>{'status': 'accepted'},
    );

    await statusApi.resetImageSearch();

    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/image-search/reset');
  });

  test('getImageSearchStatus converts backend error to ApiException', () async {
    await sessionStore.clearSession();
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Unauthorized',
        },
      },
    );

    expect(
      () => statusApi.getImageSearchStatus(),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'unauthorized',
        ),
      ),
    );
  });

  test('getInsights parses storage and collection stats', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/insights',
      statusCode: 200,
      body: <String, dynamic>{
        'download_tasks': <String, dynamic>{
          'downloading': 3,
          'importing': 2,
          'imported': 64,
          'import_failed': 1,
          'skipped': 4,
          'download_failed': 1,
          'total': 75,
        },
        'media_libraries': <dynamic>[
          <String, dynamic>{
            'library_id': 1,
            'name': '主媒体库',
            'provider_key': 'local',
            'file_count': 1420,
            'total_size_bytes': 6400000000000,
          },
          <String, dynamic>{
            'library_id': 2,
            'name': '备份库',
            'provider_key': 'cloud115',
            'file_count': 700,
            'total_size_bytes': 2300000000000,
          },
        ],
        'collections': <String, dynamic>{
          'playlists': <String, dynamic>{'count': 5, 'item_count': 42},
          'video_collections': <String, dynamic>{'count': 2, 'item_count': 8},
          'clip_collections': <String, dynamic>{'count': 0, 'item_count': 0},
          'moment_collections': <String, dynamic>{'count': 1, 'item_count': 3},
        },
      },
    );

    final insights = await statusApi.getInsights();

    expect(insights.mediaLibraries, hasLength(2));
    expect(insights.mediaLibraries.first.name, '主媒体库');
    expect(insights.downloadTasks.downloading, 3);
    expect(insights.downloadTasks.importing, 2);
    expect(insights.downloadTasks.imported, 64);
    expect(insights.downloadTasks.total, 75);
    expect(insights.collections.playlists.count, 5);
    expect(insights.collections.isEmpty, isFalse);
    expect(insights.toJson()['download_tasks'], <String, dynamic>{
      'downloading': 3,
      'importing': 2,
      'imported': 64,
      'import_failed': 1,
      'skipped': 4,
      'download_failed': 1,
      'total': 75,
    });
  });

  test('getInsights defaults missing sections to empty', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/insights',
      statusCode: 200,
      body: <String, dynamic>{},
    );

    final insights = await statusApi.getInsights();

    expect(insights.mediaLibraries, isEmpty);
    expect(insights.collections.isEmpty, isTrue);
    expect(insights.downloadTasks.total, 0);
    expect(insights.downloadTasks.downloading, 0);
  });

  test('getWatchTrend sends range and parses buckets', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/watch-trend',
      statusCode: 200,
      body: <String, dynamic>{
        'range': '7d',
        'granularity': 'day',
        'watched_movie_count': 3,
        'buckets': <dynamic>[
          <String, dynamic>{'period': '2026-09-14', 'count': 0},
          <String, dynamic>{'period': '2026-09-15', 'count': 2},
          <String, dynamic>{'period': '2026-09-16', 'count': 1},
        ],
      },
    );

    final trend = await statusApi.getWatchTrend(WatchTrendRange.last7Days);

    expect(trend.range, WatchTrendRange.last7Days);
    expect(trend.granularity, 'day');
    expect(trend.watchedMovieCount, 3);
    expect(trend.buckets, hasLength(3));
    expect(trend.buckets[1].count, 2);
    expect(adapter.requests.last.uri.queryParameters['range'], '7d');
  });

  test('getWatchTrend falls back to 30d for an unknown range', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/watch-trend',
      statusCode: 200,
      body: <String, dynamic>{
        'range': 'unknown-range',
        'granularity': 'day',
        'buckets': <dynamic>[],
      },
    );

    final trend = await statusApi.getWatchTrend(WatchTrendRange.all);

    expect(trend.range, WatchTrendRange.last30Days);
    expect(trend.buckets, isEmpty);
  });
}
