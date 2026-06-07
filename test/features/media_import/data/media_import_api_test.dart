import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/data/filesystem_entry_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';

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

  test('listEntries parses listing and omits empty path query', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/filesystem/entries',
      body: <String, dynamic>{
        'path': '/mnt/incoming',
        'parent': '/mnt',
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'movies',
            'path': '/mnt/incoming/movies',
            'type': 'dir',
            'size': 0,
            'is_video': false,
          },
          <String, dynamic>{
            'name': 'ABP-123.mp4',
            'path': '/mnt/incoming/ABP-123.mp4',
            'type': 'video',
            'size': 2147483648,
            'is_video': true,
          },
        ],
      },
    );

    final listing = await api.listEntries();

    expect(listing.path, '/mnt/incoming');
    expect(listing.parent, '/mnt');
    expect(listing.isRootsOverview, isFalse);
    expect(listing.entries, hasLength(2));
    expect(listing.entries.first.type, FilesystemEntryType.dir);
    expect(listing.entries.first.isDirectory, isTrue);
    expect(listing.entries[1].type, FilesystemEntryType.video);
    expect(listing.entries[1].size, 2147483648);

    final request = adapter.requests.single;
    expect(request.uri.queryParameters.containsKey('path'), isFalse);
  });

  test('listEntries forwards path query when provided', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/filesystem/entries',
      body: <String, dynamic>{
        'path': '/mnt/incoming/movies',
        'parent': '/mnt/incoming',
        'entries': <Map<String, dynamic>>[],
      },
    );

    await api.listEntries(path: '/mnt/incoming/movies');

    expect(
      adapter.requests.single.uri.queryParameters['path'],
      '/mnt/incoming/movies',
    );
  });

  test('createImportJob sends transfer_mode wire value and parses response',
      () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs',
      statusCode: 202,
      body: <String, dynamic>{
        'import_job_id': 7,
        'task_run_id': 42,
        'status': 'pending',
      },
    );

    final response = await api.createImportJob(
      libraryId: 1,
      sourcePath: '/mnt/incoming/movies',
      transferMode: TransferMode.cleanupSource,
    );

    expect(response.importJobId, 7);
    expect(response.taskRunId, 42);
    expect(response.status, 'pending');

    final body = adapter.requests.single.body as Map;
    expect(body['library_id'], 1);
    expect(body['source_path'], '/mnt/incoming/movies');
    expect(body['transfer_mode'], 'cleanup-source');
  });

  test('createImportJob surfaces 409 conflict as ApiException', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'media_import_conflict',
          'message': '同库同源正在导入',
        },
      },
    );

    await expectLater(
      api.createImportJob(libraryId: 1, sourcePath: '/mnt/x'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.error?.code, 'code', 'media_import_conflict'),
      ),
    );
  });

  test('listImportJobs parses paginated jobs', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'source_path': '/mnt/incoming/movies',
            'library_id': 1,
            'task_run_id': 42,
            'state': 'running',
            'transfer_mode': 'auto',
            'imported_count': 2,
            'skipped_count': 1,
            'failed_count': 0,
            'created_at': '2026-06-07 10:00:00',
            'updated_at': '2026-06-07 10:01:00',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final page = await api.listImportJobs();

    expect(page.total, 1);
    expect(page.items, hasLength(1));
    final job = page.items.single;
    expect(job.id, 3);
    expect(job.taskRunId, 42);
    expect(job.state, 'running');
    expect(job.transferMode, TransferMode.auto);
    expect(job.isTerminal, isFalse);
    expect(job.importedCount, 2);
  });

  test('getImportJob parses failed files with kinds', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/3',
      body: _jobDetailBody(),
    );

    final job = await api.getImportJob(3);

    expect(job.id, 3);
    expect(job.state, 'completed');
    expect(job.isTerminal, isTrue);
    expect(job.failedFiles, hasLength(3));
    expect(job.failedFiles[0].kind, FailedFileKind.file);
    expect(job.failedFiles[0].isActionable, isTrue);
    expect(job.failedFiles[1].kind, FailedFileKind.skipped);
    expect(job.failedFiles[1].isActionable, isFalse);
    expect(job.failedFiles[2].kind, FailedFileKind.warning);
    expect(job.actionableFailedFiles, hasLength(1));
  });

  test('retryFailedFiles posts selected files', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs/3/retry',
      statusCode: 202,
      body: <String, dynamic>{
        'import_job_id': 9,
        'task_run_id': 50,
        'status': 'pending',
      },
    );

    final response = await api.retryFailedFiles(
      3,
      files: <String>['/mnt/incoming/movies/ABP-123.mp4'],
    );

    expect(response.importJobId, 9);
    final body = adapter.requests.single.body as Map;
    expect(body['files'], <String>['/mnt/incoming/movies/ABP-123.mp4']);
  });

  test('retryFailedFiles omits files key when null (retry all)', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs/3/retry',
      statusCode: 202,
      body: <String, dynamic>{
        'import_job_id': 9,
        'task_run_id': 50,
        'status': 'pending',
      },
    );

    await api.retryFailedFiles(3);

    final body = adapter.requests.single.body as Map;
    expect(body.containsKey('files'), isFalse);
  });

  test('deleteFailedFile sends path and parses updated job', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/import-jobs/3/failed-files',
      body: _jobDetailBody(),
    );

    final job = await api.deleteFailedFile(
      3,
      path: '/mnt/incoming/movies/ABP-123.mp4',
    );

    expect(job.id, 3);
    final body = adapter.requests.single.body as Map;
    expect(body['path'], '/mnt/incoming/movies/ABP-123.mp4');
  });

  test('renameFailedFile sends path and new_name', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs/3/failed-files/rename',
      body: _jobDetailBody(),
    );

    await api.renameFailedFile(
      3,
      path: '/mnt/incoming/movies/raw.mp4',
      newName: 'ABP-123.mp4',
    );

    final body = adapter.requests.single.body as Map;
    expect(body['path'], '/mnt/incoming/movies/raw.mp4');
    expect(body['new_name'], 'ABP-123.mp4');
  });

  test('renameFailedFile surfaces 422 invalid_new_name', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs/3/failed-files/rename',
      statusCode: 422,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_new_name',
          'message': '文件名非法',
        },
      },
    );

    await expectLater(
      api.renameFailedFile(3, path: '/mnt/x', newName: '../evil'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.error?.code, 'code', 'invalid_new_name'),
      ),
    );
  });
}

Map<String, dynamic> _jobDetailBody() {
  return <String, dynamic>{
    'id': 3,
    'source_path': '/mnt/incoming/movies',
    'library_id': 1,
    'task_run_id': 42,
    'state': 'completed',
    'transfer_mode': 'auto',
    'imported_count': 5,
    'skipped_count': 1,
    'failed_count': 2,
    'created_at': '2026-06-07 10:00:00',
    'updated_at': '2026-06-07 10:05:00',
    'failed_files': <Map<String, dynamic>>[
      <String, dynamic>{
        'path': '/mnt/incoming/movies/ABP-123.mp4',
        'reason': 'movie_number_not_found',
        'detail': '',
        'kind': 'file',
      },
      <String, dynamic>{
        'path': '/mnt/incoming/movies/sample.mp4',
        'reason': 'file_too_small',
        'detail': '',
        'kind': 'skipped',
      },
      <String, dynamic>{
        'path': '/mnt/incoming/movies/ABP-999.mp4',
        'reason': 'source_delete_failed',
        'detail': '',
        'kind': 'warning',
      },
    ],
  };
}
