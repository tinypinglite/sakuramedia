import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  group('downloads api', () {
    test('searchCandidates sends movie number query and parses list', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        body: [
          {
            'source': 'torznab',
            'indexer_name': 'mteam',
            'indexer_kind': 'pt',
            'resolved_client_id': 2,
            'resolved_client_name': 'qb-main',
            'resolved_client_kind': 'qbittorrent',
            'download_clients': [
              {'id': 2, 'name': 'qb-main', 'kind': 'qbittorrent'},
              {'id': 3, 'name': '115-main', 'kind': 'cloud115'},
            ],
            'movie_number': 'ABC-001',
            'title': 'ABC-001 4K 中文字幕',
            'size_bytes': 12884901888,
            'seeders': 18,
            'magnet_url': 'magnet:?xt=urn:btih:abcdef',
            'torrent_url': '',
            'tags': ['4K', '中字'],
          },
        ],
      );

      final results = await bundle.downloadsApi.searchCandidates(
        movieNumber: 'ABC-001',
      );

      final request = bundle.adapter.requests.single;
      expect(request.path, '/download-candidates');
      expect(request.uri.queryParameters['movie_number'], 'ABC-001');
      expect(request.uri.queryParameters.containsKey('indexer_kind'), isFalse);
      expect(results.single.title, 'ABC-001 4K 中文字幕');
      expect(results.single.resolvedClientName, 'qb-main');
      expect(results.single.resolvedClientKind, DownloadClientKind.qbittorrent);
      expect(results.single.downloadClients, hasLength(2));
      expect(results.single.downloadClients.last.id, 3);
      expect(
        results.single.downloadClients.last.kind,
        DownloadClientKind.cloud115,
      );
      expect(results.single.tags, ['4K', '中字']);
    });

    test('searchCandidates sends indexer kind when provided', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        body: const <Map<String, dynamic>>[],
      );

      await bundle.downloadsApi.searchCandidates(
        movieNumber: 'ABC-001',
        indexerKind: 'pt',
      );

      final request = bundle.adapter.requests.single;
      expect(request.uri.queryParameters['movie_number'], 'ABC-001');
      expect(request.uri.queryParameters['indexer_kind'], 'pt');
    });

    test(
      'createDownloadRequest sends client id and candidate payload and parses response',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/download-requests',
          statusCode: 201,
          body: {
            'task': {
              'id': 100,
              'client_id': 2,
              'movie_number': 'ABC-001',
              'name': 'ABC-001 4K 中文字幕',
              'info_hash': '95a37f09c6d5aac200752f4c334dc9dff91e8cfc',
              'save_path': '/mnt/qb/downloads/a/ABC-001',
              'progress': 0.0,
              'download_state': 'queued',
              'import_status': 'pending',
              'created_at': '2026-03-10T08:10:00Z',
              'updated_at': '2026-03-10T08:10:00Z',
            },
            'created': true,
          },
        );

        final response = await bundle.downloadsApi.createDownloadRequest(
          movieNumber: 'ABC-001',
          clientId: 2,
          candidate: const DownloadCandidateDto(
            source: 'torznab',
            indexerName: 'mteam',
            indexerKind: 'pt',
            resolvedClientId: 2,
            resolvedClientName: 'qb-main',
            movieNumber: 'ABC-001',
            title: 'ABC-001 4K 中文字幕',
            sizeBytes: 12884901888,
            seeders: 18,
            magnetUrl: 'magnet:?xt=urn:btih:abcdef',
            torrentUrl: '',
            tags: ['4K', '中字'],
          ),
        );

        final request = bundle.adapter.requests.single;
        expect(request.path, '/download-requests');
        expect(request.body, {
          'client_id': 2,
          'movie_number': 'ABC-001',
          'candidate': {
            'source': 'torznab',
            'indexer_name': 'mteam',
            'indexer_kind': 'pt',
            'title': 'ABC-001 4K 中文字幕',
            'size_bytes': 12884901888,
            'seeders': 18,
            'magnet_url': 'magnet:?xt=urn:btih:abcdef',
            'torrent_url': '',
            'tags': ['4K', '中字'],
          },
        });
        expect(response.created, isTrue);
        expect(response.task.clientId, 2);
        expect(response.task.downloadState, 'queued');
      },
    );

    test(
      'getDownloadTasks assembles query and parses paginated tasks',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/download-tasks',
          body: {
            'items': [
              {
                'id': 11,
                'client_id': 2,
                'movie_number': 'ABC-001',
                'name': 'ABC-001',
                'info_hash': 'aa',
                'save_path': '/mnt/a',
                'progress': 0.3,
                'download_state': 'downloading',
                'raw_state': 'downloading',
                'download_speed_bytes': 2048,
                'uploaded_speed_bytes': 256,
                'downloaded_bytes': 750,
                'total_size_bytes': 1250,
                'eta_seconds': 60,
                'progress_synced_at': '2026-03-10T08:11:00Z',
                'import_status': 'pending',
                'import_status_label': '等待导入',
                'movie_title': '中文标题',
                'movie_cover': {
                  'id': 5,
                  'origin': '/files/images/orig.jpg',
                  'small': '/files/images/small.jpg',
                  'medium': '/files/images/medium.jpg',
                  'large': '/files/images/large.jpg',
                },
                'created_at': '2026-03-10T08:10:00Z',
                'updated_at': '2026-03-10T08:11:00Z',
              },
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          },
        );

        final result = await bundle.downloadsApi.getDownloadTasks(
          page: 1,
          pageSize: 20,
          sort: 'created_at:desc',
        );

        final request = bundle.adapter.requests.single;
        expect(request.path, '/download-tasks');
        expect(request.uri.queryParameters['page'], '1');
        expect(request.uri.queryParameters['page_size'], '20');
        expect(request.uri.queryParameters['sort'], 'created_at:desc');
        // 未传 downloadState 时不应出现 download_state 查询参数（避免后端误认为空串筛选）。
        expect(
          request.uri.queryParameters.containsKey('download_state'),
          isFalse,
        );
        expect(result.items.single.id, 11);
        expect(result.items.single.importStatusLabel, '等待导入');
        // 后端 JOIN 出的标题/封面已进入 DTO，前端下载卡片可以直接展示，不再二次查。
        expect(result.items.single.movieTitle, '中文标题');
        expect(
          result.items.single.movieCover?.small,
          '/files/images/small.jpg',
        );
        expect(result.items.single.downloadSpeedBytes, 2048);
        expect(result.items.single.uploadedSpeedBytes, 256);
        expect(result.items.single.totalSizeBytes, 1250);
        expect(result.items.single.etaSeconds, 60);
      },
    );

    test(
      'getDownloadTasks forwards download_state and movie_number filters',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/download-tasks',
          body: {
            'items': const <Map<String, dynamic>>[],
            'page': 1,
            'page_size': 20,
            'total': 0,
          },
        );

        await bundle.downloadsApi.getDownloadTasks(
          movieNumber: 'SSIS-001',
          downloadStates: ['paused'],
          clientId: 3,
          sort: 'created_at:desc',
        );

        final request = bundle.adapter.requests.single;
        expect(request.uri.queryParameters['movie_number'], 'SSIS-001');
        expect(request.uri.queryParameters['download_state'], 'paused');
        expect(request.uri.queryParameters['client_id'], '3');
      },
    );

    test(
      'getDownloadTasks sends multiple download_state as repeated params',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/download-tasks',
          body: {
            'items': const <Map<String, dynamic>>[],
            'page': 1,
            'page_size': 20,
            'total': 0,
          },
        );

        await bundle.downloadsApi.getDownloadTasks(
          downloadStates: ['downloading', 'stalled'],
        );

        final request = bundle.adapter.requests.single;
        expect(request.uri.queryParametersAll['download_state'], [
          'downloading',
          'stalled',
        ]);
      },
    );

    test('pauseDownloadTask calls /pause and parses action result', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-tasks/42/pause',
        body: {'task_id': 42, 'action': 'pause', 'status': 'ok'},
      );

      final result = await bundle.downloadsApi.pauseDownloadTask(42);

      expect(bundle.adapter.requests.single.path, '/download-tasks/42/pause');
      expect(result.action, 'pause');
      expect(result.status, 'ok');
    });

    test('resumeDownloadTask forwards 409 as ApiException', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-tasks/9/resume',
        statusCode: 409,
        body: {
          'error': {
            'code': 'download_task_remote_missing',
            'message': '任务在下载器中已不存在',
          },
        },
      );

      expect(
        () => bundle.downloadsApi.resumeDownloadTask(9),
        throwsA(
          isA<ApiException>().having(
            (error) => error.error?.code,
            'error.code',
            'download_task_remote_missing',
          ),
        ),
      );
    });

    test(
      'deleteDownloadTask without delete_files sends only delete_files=false',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'DELETE',
          path: '/download-tasks/7',
          statusCode: 204,
        );

        await bundle.downloadsApi.deleteDownloadTask(7);

        final request = bundle.adapter.requests.single;
        expect(request.uri.queryParameters['delete_files'], 'false');
        expect(
          request.uri.queryParameters.containsKey('confirm_delete_files'),
          isFalse,
        );
      },
    );

    test(
      'deleteDownloadTask with delete_files sends both confirm params',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'DELETE',
          path: '/download-tasks/7',
          statusCode: 204,
        );

        await bundle.downloadsApi.deleteDownloadTask(7, deleteFiles: true);

        final request = bundle.adapter.requests.single;
        expect(request.uri.queryParameters['delete_files'], 'true');
        expect(request.uri.queryParameters['confirm_delete_files'], 'true');
      },
    );

    test(
      'createDownloadRequest converts backend error to ApiException',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/download-requests',
          statusCode: 502,
          body: {
            'error': {
              'code': 'download_candidate_search_failed',
              'message': 'boom',
            },
          },
        );

        expect(
          () => bundle.downloadsApi.createDownloadRequest(
            movieNumber: 'ABC-001',
            clientId: 2,
            candidate: const DownloadCandidateDto(
              source: 'torznab',
              indexerName: 'mteam',
              indexerKind: 'pt',
              resolvedClientId: 2,
              resolvedClientName: 'qb-main',
              movieNumber: 'ABC-001',
              title: 'ABC-001',
              sizeBytes: 123,
              seeders: 5,
              magnetUrl: 'magnet:?xt=urn:btih:abcdef',
              torrentUrl: '',
              tags: ['4K'],
            ),
          ),
          throwsA(
            isA<ApiException>().having(
              (ApiException error) => error.error?.code,
              'error.code',
              'download_candidate_search_failed',
            ),
          ),
        );
      },
    );

    test('getTaskFiles parses qb/115 unified file list', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-tasks/516/files',
        body: <String, dynamic>{
          'task_id': 516,
          'client_kind': 'qbittorrent',
          'files': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'IPX-451.iso',
              'size': 32788611072,
              'is_dir': false,
            },
            <String, dynamic>{
              'name': 'cover.jpg',
              'size': 2048,
              'is_dir': false,
            },
          ],
        },
      );

      final response = await bundle.downloadsApi.getTaskFiles(516);

      final request = bundle.adapter.requests.single;
      expect(request.path, '/download-tasks/516/files');
      expect(response.taskId, 516);
      expect(response.clientKind, 'qbittorrent');
      expect(response.files, hasLength(2));
      expect(response.files.first.name, 'IPX-451.iso');
      expect(response.files.first.size, 32788611072);
      expect(response.files.first.isDir, isFalse);
      expect(response.files.first.path, isNull);
    });
  });
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
  );
  return sessionStore;
}
