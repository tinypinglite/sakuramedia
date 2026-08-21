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

  test('getImageSearchStatus parses joytag and indexing stats', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      statusCode: 200,
      body: <String, dynamic>{
        'healthy': true,
        'joytag': <String, dynamic>{
          'healthy': true,
          'used_device': 'GPU',
          'endpoint': 'http://joytag:8000',
        },
        'indexing': <String, dynamic>{
          'pending_thumbnails': 23,
          'failed_thumbnails': 2,
          'success_thumbnails': 15295,
        },
      },
    );

    final status = await statusApi.getImageSearchStatus();

    expect(status.healthy, isTrue);
    expect(status.joyTag.healthy, isTrue);
    expect(status.joyTag.usedDevice, 'GPU');
    expect(status.joyTag.endpoint, 'http://joytag:8000');
    expect(status.indexing.pendingThumbnails, 23);
    expect(status.indexing.failedThumbnails, 2);
  });

  test('getImageSearchStatus 保留 joytag 的失败原因', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      statusCode: 200,
      body: <String, dynamic>{
        'healthy': false,
        'joytag': <String, dynamic>{
          'healthy': false,
          'endpoint': 'http://joytag:8000',
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
    expect(status.joyTag.error, 'model file not found');
  });

  test(
    'testMetadataProvider parses structured error type and probe metadata',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/status/metadata-providers/javdb/test',
        statusCode: 200,
        body: <String, dynamic>{
          'healthy': false,
          'checked_at': '2026-07-11T08:00:00Z',
          'provider': 'javdb',
          'movie_number': 'SSNI-888',
          'elapsed_ms': 1234,
          'error': <String, dynamic>{
            'type': 'metadata_not_found',
            'message': 'movie not found: SSNI-888',
            'resource': 'movie',
            'lookup_value': 'SSNI-888',
          },
        },
      );

      final result = await statusApi.testMetadataProvider('javdb');

      expect(result.healthy, isFalse);
      expect(result.provider, 'javdb');
      expect(result.movieNumber, 'SSNI-888');
      expect(result.elapsedMs, 1234);
      // type 是分派依据，以前整个被丢掉，只留 message 供关键字猜测。
      expect(result.error?.type, 'metadata_not_found');
      expect(result.error?.resource, 'movie');
      expect(result.error?.lookupValue, 'SSNI-888');
    },
  );

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

  test(
    'getCloud115CookiesStatus parses summary and library statuses',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/status/media-libraries/cloud115',
        statusCode: 200,
        body: <String, dynamic>{
          'checked_at': '2026-07-14T10:00:00Z',
          'summary': <String, dynamic>{
            'total': 3,
            'alive': 1,
            'expired': 1,
            'unavailable': 1,
          },
          'libraries': <Map<String, dynamic>>[
            <String, dynamic>{
              'library_id': 1,
              'name': '115 主库',
              'cookie_status': 'alive',
            },
            <String, dynamic>{
              'library_id': 2,
              'name': '115 备用库',
              'cookie_status': 'expired',
            },
            <String, dynamic>{
              'library_id': 3,
              'name': '115 暂不可用库',
              'cookie_status': 'unavailable',
            },
          ],
        },
      );

      final result = await statusApi.getCloud115CookiesStatus();

      expect(result.checkedAt, DateTime.parse('2026-07-14T10:00:00Z'));
      expect(result.summary.total, 3);
      expect(result.summary.alive, 1);
      expect(result.summary.expired, 1);
      expect(result.summary.unavailable, 1);
      expect(
        result.libraries.map((item) => item.cookieStatus),
        <Cloud115CookieStatus>[
          Cloud115CookieStatus.alive,
          Cloud115CookieStatus.expired,
          Cloud115CookieStatus.unavailable,
        ],
      );
      expect(result.libraries.first.libraryId, 1);
      expect(result.libraries.first.name, '115 主库');
      expect(result.toJson()['summary'], <String, dynamic>{
        'total': 3,
        'alive': 1,
        'expired': 1,
        'unavailable': 1,
      });
    },
  );

  test('getCloud115CookiesStatus handles empty libraries', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      statusCode: 200,
      body: <String, dynamic>{
        'checked_at': '2026-07-14T10:00:00Z',
        'summary': <String, dynamic>{
          'total': 0,
          'alive': 0,
          'expired': 0,
          'unavailable': 0,
        },
        'libraries': <dynamic>[],
      },
    );

    final result = await statusApi.getCloud115CookiesStatus();

    expect(result.summary.total, 0);
    expect(result.libraries, isEmpty);
  });

  test('unknown cloud115 cookie status is treated as unavailable', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      statusCode: 200,
      body: <String, dynamic>{
        'checked_at': '2026-07-14T10:00:00Z',
        'summary': <String, dynamic>{
          'total': 1,
          'alive': 0,
          'expired': 0,
          'unavailable': 1,
        },
        'libraries': <Map<String, dynamic>>[
          <String, dynamic>{
            'library_id': 1,
            'name': '115 主库',
            'cookie_status': 'future-status',
          },
        ],
      },
    );

    final result = await statusApi.getCloud115CookiesStatus();

    expect(
      result.libraries.single.cookieStatus,
      Cloud115CookieStatus.unavailable,
    );
  });

  test(
    'getCloud115CookiesStatus converts backend error to ApiException',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/status/media-libraries/cloud115',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'server_error',
            'message': 'server error',
          },
        },
      );

      expect(
        () => statusApi.getCloud115CookiesStatus(),
        throwsA(
          isA<ApiException>().having(
            (ApiException error) => error.error?.code,
            'error.code',
            'server_error',
          ),
        ),
      );
    },
  );

  test('testMetadataProvider parses healthy result', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/metadata-providers/javdb/test',
      statusCode: 200,
      body: <String, dynamic>{
        'healthy': true,
        'provider': 'javdb',
        'error': null,
      },
    );

    final result = await statusApi.testMetadataProvider('javdb');

    expect(result.healthy, isTrue);
    expect(result.provider, 'javdb');
    expect(result.error, isNull);
  });

  test('testMetadataProvider parses unhealthy result', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/metadata-providers/javdb/test',
      statusCode: 200,
      body: <String, dynamic>{
        'healthy': false,
        'provider': 'javdb',
        'error': <String, dynamic>{'message': 'metadata request failed'},
      },
    );

    final result = await statusApi.testMetadataProvider('javdb');

    expect(result.healthy, isFalse);
    expect(result.provider, 'javdb');
    expect(result.error?.message, 'metadata request failed');
  });

  test('testMetadataProvider converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/metadata-providers/invalid/test',
      statusCode: 422,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_metadata_provider',
          'message': 'Metadata provider must be javdb',
        },
      },
    );

    expect(
      () => statusApi.testMetadataProvider('invalid'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'invalid_metadata_provider',
        ),
      ),
    );
  });
}
