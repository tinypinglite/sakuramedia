import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaImportApi api;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    api = MediaImportApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('listEntries forwards only a non-empty path', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/filesystem/entries',
      body: <String, dynamic>{
        'path': '/mnt/incoming',
        'parent': '/mnt',
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'movie.mkv',
            'path': '/mnt/incoming/movie.mkv',
            'type': 'video',
            'size': 123,
            'is_video': true,
          },
        ],
      },
    );

    final listing = await api.listEntries(path: '/mnt/incoming');

    expect(listing.path, '/mnt/incoming');
    expect(listing.entries.single.isVideo, isTrue);
    expect(
      adapter.requests.single.uri.queryParameters['path'],
      '/mnt/incoming',
    );
  });

  test('createImport posts the unified local video contract', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/imports',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 42,
        'task_key': 'media_import',
        'state': 'accepted',
      },
    );

    final response = await api.createImport(
      mediaKind: 'video',
      libraryId: 1,
      source: const MediaImportSource.local(' /mnt/incoming '),
      transferMode: TransferMode.auto,
      collectionId: 9,
    );

    expect(response.taskRunId, 42);
    expect(response.taskKey, 'media_import');
    expect(response.state, 'accepted');
    expect(adapter.requests.single.body, <String, dynamic>{
      'media_kind': 'video',
      'backend': 'local',
      'library_id': 1,
      'source_path': '/mnt/incoming',
      'transfer_mode': 'auto',
      'collection_id': 9,
    });
  });

  test('createImport posts cloud115 JAV with cleanup-source', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/imports',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 43,
        'task_key': 'jav_import',
        'state': 'pending',
      },
    );

    await api.createImport(
      mediaKind: 'jav',
      libraryId: 2,
      source: const MediaImportSource.cloud115('cid-source'),
      transferMode: TransferMode.cleanupSource,
    );

    expect(adapter.requests.single.body, <String, dynamic>{
      'media_kind': 'jav',
      'backend': 'cloud115',
      'library_id': 2,
      'source_cid': 'cid-source',
      'transfer_mode': 'cleanup-source',
    });
  });

  test('createImport posts a cloud115 video FID', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/imports',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 44,
        'task_key': 'library_import',
        'state': 'pending',
      },
    );

    await api.createImport(
      mediaKind: 'video',
      libraryId: 2,
      source: const MediaImportSource.cloud115File('fid-video'),
      transferMode: TransferMode.cleanupSource,
      collectionId: 9,
    );

    expect(adapter.requests.single.body, <String, dynamic>{
      'media_kind': 'video',
      'backend': 'cloud115',
      'library_id': 2,
      'source_fid': 'fid-video',
      'transfer_mode': 'cleanup-source',
      'collection_id': 9,
    });
  });
}
