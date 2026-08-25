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
}
