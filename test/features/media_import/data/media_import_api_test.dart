import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/data/import_failed_item_dto.dart';
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

  test('browseSources posts the library and opaque parent reference', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/import-sources/browse',
      body: <String, dynamic>{
        'library_id': 7,
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'source_ref': <String, dynamic>{'id': 'folder-1'},
            'name': 'Movies',
            'entry_type': 'directory',
            'size_bytes': null,
            'modified_at': null,
            'is_video': false,
          },
        ],
        'next_cursor': 'next-page',
      },
    );

    final page = await api.browseSources(
      libraryId: 7,
      parentRef: <String, dynamic>{'id': 'root'},
      cursor: 'cursor-1',
      limit: 25,
    );

    expect(page.libraryId, 7);
    expect(page.entries.single.sourceRef, <String, dynamic>{'id': 'folder-1'});
    expect(page.entries.single.isDirectory, isTrue);
    expect(page.nextCursor, 'next-page');
    expect(adapter.requests.single.body, <String, dynamic>{
      'library_id': 7,
      'parent_ref': <String, dynamic>{'id': 'root'},
      'cursor': 'cursor-1',
      'limit': 25,
    });
  });

  test('createImport posts provider-neutral video contract', () async {
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
      source: const MediaImportSource(
        sourceRef: <String, dynamic>{'provider_id': 'file-1'},
      ),
      sourceDisposition: SourceDisposition.keep,
      collectionId: 9,
    );

    expect(response.taskRunId, 42);
    expect(adapter.requests.single.body, <String, dynamic>{
      'media_kind': 'video',
      'library_id': 1,
      'source_ref': <String, dynamic>{'provider_id': 'file-1'},
      'source_disposition': 'keep',
      'collection_id': 9,
    });
  });

  test(
    'createImport supports delete_after_commit without provider fields',
    () async {
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
        source: const MediaImportSource(
          sourceRef: <String, dynamic>{'opaque': true},
        ),
        sourceDisposition: SourceDisposition.deleteAfterCommit,
      );

      expect(adapter.requests.single.body, <String, dynamic>{
        'media_kind': 'jav',
        'library_id': 2,
        'source_ref': <String, dynamic>{'opaque': true},
        'source_disposition': 'delete_after_commit',
      });
    },
  );

  test('createImport sends the in_place disposition', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/imports',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 44,
        'task_key': 'jav_import',
        'state': 'pending',
      },
    );

    await api.createImport(
      mediaKind: 'jav',
      libraryId: 2,
      source: const MediaImportSource(
        sourceRef: <String, dynamic>{'opaque': true},
      ),
      sourceDisposition: SourceDisposition.inPlace,
    );

    expect(adapter.requests.single.body, <String, dynamic>{
      'media_kind': 'jav',
      'library_id': 2,
      'source_ref': <String, dynamic>{'opaque': true},
      'source_disposition': 'in_place',
    });
  });

  test('getFailedItems reads the task-scoped failed file list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/imports/42/failed-items',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'failure-1',
          'relative_path': 'release/ABC.unknown.mp4',
          'size_bytes': 1024,
          'is_video': true,
          'reason': 'movie_number_not_found',
          'detail': '无法从文件名识别番号',
          'kind': 'file',
          'state': 'pending',
          'retry_task_run_id': null,
          'resolved_movie_id': null,
          'resolved_media_id': null,
          'last_retry_error': null,
          'can_manual_search': true,
        },
      ],
    );

    final items = await api.getFailedItems(taskRunId: 42);

    expect(items.single.id, 'failure-1');
    expect(items.single.fileName, 'ABC.unknown.mp4');
    expect(items.single.sizeBytes, 1024);
    expect(items.single.kind, 'file');
    expect(items.single.isSkipped, isFalse);
    expect(items.single.state, ImportFailedItemState.pending);
    expect(items.single.canManualSearch, isTrue);
    expect(items.single.lastRetryError, isNull);
  });

  test(
    'searchMetadataCandidates queries the number and parses candidates',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/imports/42/failed-items/failure-1/metadata-candidates',
        body: <String, dynamic>{
          'movie_number': 'ABC-001',
          'candidates': <Map<String, dynamic>>[
            <String, dynamic>{
              'candidate_id': 'plugin:demo:ABC-001',
              'plugin_id': 'demo',
              'source_name': 'Demo Metadata',
              'source_id': null,
              'movie_number': 'ABC-001',
              'title': 'Demo 标题',
              'cover_url': '/files/images/metadata-search/a/0.jpg',
              'release_date': '2026-09-01',
              'duration_minutes': 120,
            },
          ],
          'source_errors': <Map<String, dynamic>>[
            <String, dynamic>{
              'source': 'metadata_two',
              'source_name': 'Metadata Two',
              'reason': 'metadata_request_error',
              'detail': 'plugin offline',
            },
          ],
        },
      );

      final response = await api.searchMetadataCandidates(
        taskRunId: 42,
        itemId: 'failure-1',
        movieNumber: 'ABC-001',
      );

      expect(response.candidates.single.title, 'Demo 标题');
      expect(
        response.candidates.single.coverUrl,
        '/files/images/metadata-search/a/0.jpg',
      );
      expect(response.sourceErrors.single.source, 'metadata_two');
      expect(response.sourceErrors.single.reason, 'metadata_request_error');
      expect(response.sourceErrors.single.detail, 'plugin offline');
      expect(response.sourceErrors.single.sourceName, 'Metadata Two');
      expect(
        adapter.requests.single.uri.queryParameters['movie_number'],
        'ABC-001',
      );
    },
  );

  test(
    'retryFailedItem posts the candidate and returns the accepted run',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/imports/42/failed-items/failure-1/retry',
        statusCode: 202,
        body: <String, dynamic>{
          'task_run_id': 77,
          'task_key': 'library_import',
          'state': 'pending',
        },
      );

      final response = await api.retryFailedItem(
        taskRunId: 42,
        itemId: 'failure-1',
        candidateId: 'plugin:demo:ABC-001',
      );

      expect(response.taskRunId, 77);
      expect(adapter.requests.single.body, <String, dynamic>{
        'candidate_id': 'plugin:demo:ABC-001',
      });
    },
  );
}
