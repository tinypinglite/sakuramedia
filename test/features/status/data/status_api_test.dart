import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';

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
      },
    );

    final status = await statusApi.getStatus();

    expect(status.backendVersion, 'v0.2.0');
    expect(status.actors.femaleTotal, 12);
    expect(status.movies.total, 120);
    expect(status.mediaFiles.totalSizeBytes, 987654321);
    expect(status.mediaLibraries.total, 3);
    expect(status.toJson()['backend_version'], 'v0.2.0');
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
        'joytag': <String, dynamic>{'healthy': true, 'used_device': 'GPU'},
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
    expect(status.indexing.pendingThumbnails, 23);
    expect(status.indexing.failedThumbnails, 2);
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
      path: '/status/metadata-providers/dmm/test',
      statusCode: 200,
      body: <String, dynamic>{
        'healthy': false,
        'provider': 'dmm',
        'error': <String, dynamic>{'message': 'metadata request failed'},
      },
    );

    final result = await statusApi.testMetadataProvider('dmm');

    expect(result.healthy, isFalse);
    expect(result.provider, 'dmm');
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
          'message': 'Metadata provider must be javdb or dmm',
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
