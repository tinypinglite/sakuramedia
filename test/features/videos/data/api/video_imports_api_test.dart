import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/videos/data/dto/video_import_job_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_imports_api.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late VideoImportsApi api;

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
    api = VideoImportsApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('createVideoImport sends library, transfer_mode and collection', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-imports',
      statusCode: 202,
      body: <String, dynamic>{
        'video_import_job_id': 7,
        'task_run_id': 42,
        'status': 'accepted',
      },
    );

    final response = await api.createVideoImport(
      libraryId: 1,
      source: const MediaImportSource.local('/mnt/incoming/videos'),
      transferMode: TransferMode.cleanupSource,
      collectionId: 9,
    );

    expect(response.videoImportJobId, 7);
    expect(response.taskRunId, 42);
    expect(response.status, 'accepted');

    final body = adapter.requests.single.body as Map;
    expect(body['library_id'], 1);
    expect(body['source_path'], '/mnt/incoming/videos');
    expect(body.containsKey('source_cid'), isFalse);
    expect(body['transfer_mode'], 'cleanup-source');
    expect(body['collection_id'], 9);
  });

  test('createVideoImport with cloud115 source sends source_cid + copy mode',
      () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-imports',
      statusCode: 202,
      body: <String, dynamic>{
        'video_import_job_id': 8,
        'task_run_id': 43,
        'status': 'accepted',
      },
    );

    await api.createVideoImport(
      libraryId: 2,
      source: const MediaImportSource.cloud115('cid-source'),
      transferMode: TransferMode.copy,
      collectionId: 9,
    );

    final body = adapter.requests.single.body as Map;
    expect(body['library_id'], 2);
    expect(body['source_cid'], 'cid-source');
    expect(body.containsKey('source_path'), isFalse);
    expect(body['transfer_mode'], 'copy');
    expect(body['collection_id'], 9);
  });

  test('createVideoImport omits collection_id when null', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-imports',
      statusCode: 202,
      body: <String, dynamic>{
        'video_import_job_id': 7,
        'task_run_id': 42,
        'status': 'accepted',
      },
    );

    await api.createVideoImport(
      libraryId: 1,
      source: const MediaImportSource.local('/mnt/x'),
      transferMode: TransferMode.auto,
    );

    final body = adapter.requests.single.body as Map;
    expect(body.containsKey('collection_id'), isFalse);
    expect(body['transfer_mode'], 'auto');
  });

  test('createVideoImport surfaces 409 conflict as ApiException', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-imports',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'video_import_conflict',
          'message': '同库同源正在导入',
        },
      },
    );

    await expectLater(
      api.createVideoImport(
        libraryId: 1,
        source: const MediaImportSource.local('/mnt/x'),
        transferMode: TransferMode.auto,
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.error?.code, 'code', 'video_import_conflict'),
      ),
    );
  });

  test('listVideoImportJobs parses paginated jobs with collection', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-imports',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'source_path': '/mnt/incoming/videos',
            'library_id': 1,
            'collection_id': 9,
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

    final page = await api.listVideoImportJobs();

    expect(page.total, 1);
    expect(page.items, hasLength(1));
    final job = page.items.single;
    expect(job.id, 3);
    expect(job.collectionId, 9);
    expect(job.taskRunId, 42);
    expect(job.state, 'running');
    expect(job.transferMode, TransferMode.auto);
    expect(job.isTerminal, isFalse);
    expect(job.importedCount, 2);
    expect(job.sourceCid, isNull);
    expect(job.isCloud115, isFalse);
  });

  test('listVideoImportJobs marks cloud115 jobs via source_cid', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-imports',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 5,
            'source_path': '115 网盘 / 来源目录',
            'source_cid': 'cid-source',
            'library_id': 2,
            'collection_id': 9,
            'task_run_id': 44,
            'state': 'completed',
            'transfer_mode': 'copy',
            'imported_count': 3,
            'skipped_count': 0,
            'failed_count': 0,
            'created_at': '2026-07-14 10:00:00',
            'updated_at': '2026-07-14 10:05:00',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final page = await api.listVideoImportJobs();
    final job = page.items.single;
    expect(job.sourceCid, 'cid-source');
    expect(job.isCloud115, isTrue);
    expect(job.transferMode, TransferMode.copy);
    expect(job.canMutateFailedSource, isFalse);
  });

  test('getVideoImportJob parses failed files with kinds', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-imports/3',
      body: _jobDetailBody(),
    );

    final job = await api.getVideoImportJob(3);

    expect(job.id, 3);
    expect(job.collectionId, 9);
    expect(job.state, 'completed');
    expect(job.isTerminal, isTrue);
    expect(job.failedFiles, hasLength(2));
    expect(job.failedFiles[0].kind, FailedFileKind.file);
    expect(job.failedFiles[0].isActionable, isTrue);
    expect(job.failedFiles[1].kind, FailedFileKind.skipped);
    expect(job.actionableFailedFiles, hasLength(1));
  });

  test('retryFailedFiles posts selected files', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-imports/3/retry',
      statusCode: 202,
      body: <String, dynamic>{
        'video_import_job_id': 9,
        'task_run_id': 50,
        'status': 'accepted',
      },
    );

    final response = await api.retryFailedFiles(
      3,
      files: <String>['/mnt/incoming/videos/clip.mp4'],
    );

    expect(response.videoImportJobId, 9);
    final body = adapter.requests.single.body as Map;
    expect(body['files'], <String>['/mnt/incoming/videos/clip.mp4']);
  });

  test('retryFailedFiles omits files key when null (retry all)', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-imports/3/retry',
      statusCode: 202,
      body: <String, dynamic>{
        'video_import_job_id': 9,
        'task_run_id': 50,
        'status': 'accepted',
      },
    );

    await api.retryFailedFiles(3);

    final body = adapter.requests.single.body as Map;
    expect(body.containsKey('files'), isFalse);
  });

}

Map<String, dynamic> _jobDetailBody() {
  return <String, dynamic>{
    'id': 3,
    'source_path': '/mnt/incoming/videos',
    'library_id': 1,
    'collection_id': 9,
    'task_run_id': 42,
    'state': 'completed',
    'transfer_mode': 'auto',
    'imported_count': 5,
    'skipped_count': 1,
    'failed_count': 1,
    'created_at': '2026-06-07 10:00:00',
    'updated_at': '2026-06-07 10:05:00',
    'failed_files': <Map<String, dynamic>>[
      <String, dynamic>{
        'path': '/mnt/incoming/videos/clip.mp4',
        'reason': 'media_import_failed',
        'detail': '',
        'kind': 'file',
      },
      <String, dynamic>{
        'path': '/mnt/incoming/videos/sample.mp4',
        'reason': 'duplicate_fingerprint',
        'detail': '',
        'kind': 'skipped',
      },
    ],
  };
}
