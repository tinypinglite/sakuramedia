import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
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
            'source_uri': 'provider://torznab/abcdef',
            'indexer_name': 'mteam',
            'indexer_kind': 'pt',
            'resolved_client_id': 2,
            'resolved_client_name': 'qb-main',
            'download_clients': [
              {'id': 2, 'name': 'qb-main'},
              {'id': 3, 'name': '115-main'},
            ],
            'movie_number': 'ABC-001',
            'title': 'ABC-001 4K 中文字幕',
            'size_bytes': 12884901888,
            'seeders': 18,
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
      expect(results.single.sourceUri, 'provider://torznab/abcdef');
      expect(results.single.resolvedClientName, 'qb-main');
      expect(results.single.downloadClients, hasLength(2));
      expect(results.single.downloadClients.last.id, 3);
      expect(results.single.downloadClients.last.name, '115-main');
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
              'remote_id': '95a37f09c6d5aac200752f4c334dc9dff91e8cfc',
              'state': 'queued',
              'progress': 0.0,
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
            sourceUri: 'provider://torznab/abcdef',
            indexerName: 'mteam',
            indexerKind: 'pt',
            resolvedClientId: 2,
            resolvedClientName: 'qb-main',
            movieNumber: 'ABC-001',
            title: 'ABC-001 4K 中文字幕',
            sizeBytes: 12884901888,
            seeders: 18,
          ),
        );

        final request = bundle.adapter.requests.single;
        expect(request.path, '/download-requests');
        expect(request.body, {
          'client_id': 2,
          'movie_number': 'ABC-001',
          'candidate': {
            'source_uri': 'provider://torznab/abcdef',
            'indexer_name': 'mteam',
            'title': 'ABC-001 4K 中文字幕',
            'size_bytes': 12884901888,
            'seeders': 18,
          },
        });
        expect(response.created, isTrue);
        expect(response.task.clientId, 2);
        expect(response.task.state, 'queued');
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
                'remote_id': 'aa',
                'state': 'downloading',
                'progress': 0.3,
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
        // 未传 states 时不应出现 state 查询参数（避免后端误认为空串筛选）。
        expect(request.uri.queryParameters.containsKey('state'), isFalse);
        expect(result.items.single.id, 11);
        expect(result.items.single.remoteId, 'aa');
        expect(result.items.single.state, 'downloading');
        expect(result.items.single.importStatusLabel, '等待导入');
        // 后端 JOIN 出的标题/封面已进入 DTO，前端下载卡片可以直接展示，不再二次查。
        expect(result.items.single.movieTitle, '中文标题');
        expect(
          result.items.single.movieCover?.small,
          '/files/images/small.jpg',
        );
      },
    );

    test('getDownloadTasks forwards state and movie_number filters', () async {
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
        states: ['failed'],
        clientId: 3,
        sort: 'created_at:desc',
      );

      final request = bundle.adapter.requests.single;
      expect(request.uri.queryParameters['movie_number'], 'SSIS-001');
      expect(request.uri.queryParameters['state'], 'failed');
      expect(request.uri.queryParameters['client_id'], '3');
    });

    test(
      'getDownloadTasks sends multiple state values as repeated params',
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
          states: ['downloading', 'queued'],
        );

        final request = bundle.adapter.requests.single;
        expect(request.uri.queryParametersAll['state'], [
          'downloading',
          'queued',
        ]);
      },
    );

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
              sourceUri: 'provider://torznab/abcdef',
              indexerName: 'mteam',
              indexerKind: 'pt',
              resolvedClientId: 2,
              resolvedClientName: 'qb-main',
              movieNumber: 'ABC-001',
              title: 'ABC-001',
              sizeBytes: 123,
              seeders: 5,
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
