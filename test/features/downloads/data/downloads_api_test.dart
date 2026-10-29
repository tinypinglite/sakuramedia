import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';

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
      'searchCandidates parses selection evaluation and release fields',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/download-candidates',
          body: <Map<String, dynamic>>[
            <String, dynamic>{
              'source_uri': 'magnet:?xt=abc',
              'indexer_name': 'mteam',
              'indexer_kind': 'pt',
              'resolved_client_id': 2,
              'resolved_client_name': 'qb-main',
              'download_clients': <Map<String, dynamic>>[],
              'movie_number': 'ABC-001',
              'title': 'ABC-001 1080p',
              'release_title': 'ABC-001 1080p',
              'description': '中文字幕',
              'published_at': '2026-10-29T12:00:00Z',
              'size_bytes': 5368709120,
              'seeders': 18,
              'selection_evaluation': <String, dynamic>{
                'eligible': false,
                'rejection_reasons': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'code': 'excluded_term',
                    'message': '命中排除词 sample',
                    'term': 'sample',
                  },
                ],
                'matched_required_group_labels': <String>['清晰度'],
                'matched_preferred_group_label': '字幕',
                'preference_rank': 0,
                'selection_rank': null,
                'within_attempt_limit': false,
              },
            },
          ],
        );

        final candidate = (await bundle.downloadsApi.searchCandidates(
          movieNumber: 'ABC-001',
        )).single;

        expect(candidate.releaseTitle, 'ABC-001 1080p');
        expect(candidate.description, '中文字幕');
        expect(candidate.publishedAt, DateTime.parse('2026-10-29T12:00:00Z'));
        final evaluation = candidate.selectionEvaluation;
        expect(evaluation?.eligible, isFalse);
        expect(evaluation?.matchedRequiredGroupLabels, <String>['清晰度']);
        expect(evaluation?.matchedPreferredGroupLabel, '字幕');
        expect(evaluation?.rejectionReasons.single.code, 'excluded_term');
        expect(evaluation?.rejectionReasons.single.term, 'sample');
      },
    );

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
                'display_name': '我的资源',
                'movie_title': '中文标题',
                'movie_cover': {'id': 5, 'origin': '/files/images/large.jpg'},
                'movie_thin_cover': {
                  'id': 6,
                  'origin': '/files/images/thin-large.jpg',
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
        expect(result.items.single.displayName, '我的资源');
        // 后端 JOIN 出的标题/封面已进入 DTO，前端下载卡片可以直接展示，不再二次查。
        expect(result.items.single.movieTitle, '中文标题');
        expect(
          result.items.single.movieCover?.origin,
          '/files/images/large.jpg',
        );
        expect(
          result.items.single.movieThinCover?.origin,
          '/files/images/thin-large.jpg',
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

    test('createManualDownloadRequest sends jav magnet payload', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-requests/manual',
        statusCode: 201,
        body: _downloadTaskResponse(),
      );

      final response = await bundle.downloadsApi.createManualDownloadRequest(
        clientId: 2,
        mediaKind: ManualDownloadMediaKind.jav,
        sourceUri: 'magnet:?xt=urn:btih:abc',
        movieNumber: ' ABC-001 ',
        collectionId: 9,
        displayName: ' ',
        deleteSourceAfterImport: true,
      );

      expect(bundle.adapter.requests.single.body, {
        'client_id': 2,
        'media_kind': 'jav',
        'source_uri': 'magnet:?xt=urn:btih:abc',
        'movie_number': 'ABC-001',
        'delete_source_after_import': true,
      });
      expect(response.created, isTrue);
    });

    test(
      'createManualDownloadRequest sends video collection payload',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/download-requests/manual',
          statusCode: 201,
          body: _downloadTaskResponse(movieNumber: null),
        );

        await bundle.downloadsApi.createManualDownloadRequest(
          clientId: 3,
          mediaKind: ManualDownloadMediaKind.video,
          sourceUri: 'magnet:?xt=urn:btih:def',
          movieNumber: 'IGNORED',
          collectionId: 9,
          displayName: ' 我的视频 ',
        );

        expect(bundle.adapter.requests.single.body, {
          'client_id': 3,
          'media_kind': 'video',
          'source_uri': 'magnet:?xt=urn:btih:def',
          'collection_id': 9,
          'display_name': '我的视频',
          'delete_source_after_import': false,
        });
      },
    );

    test(
      'createManualTorrentDownloadRequest sends multipart fields and file',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/download-requests/manual/torrent',
          statusCode: 201,
          body: _downloadTaskResponse(movieNumber: null),
        );

        final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
        await bundle.downloadsApi.createManualTorrentDownloadRequest(
          clientId: 2,
          mediaKind: ManualDownloadMediaKind.video,
          torrentBytes: bytes,
          fileName: 'abc.torrent',
          collectionId: 9,
          displayName: '视频资源',
        );

        final body = bundle.adapter.requests.single.body as FormData;
        final fields = <String, String>{
          for (final entry in body.fields) entry.key: entry.value,
        };
        expect(fields, {
          'client_id': '2',
          'media_kind': 'video',
          'collection_id': '9',
          'display_name': '视频资源',
          'delete_source_after_import': 'false',
        });
        expect(body.files, hasLength(1));
        expect(body.files.single.key, 'file');
        expect(body.files.single.value.filename, 'abc.torrent');
        expect(body.files.single.value.length, bytes.length);
      },
    );

    test('createManualDownloadRequest surfaces backend error code', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-requests/manual',
        statusCode: 409,
        body: {
          'error': {
            'code': 'download_task_already_imported',
            'message': '该资源已有下载任务且已进入导入流程',
          },
        },
      );

      expect(
        () => bundle.downloadsApi.createManualDownloadRequest(
          clientId: 2,
          mediaKind: ManualDownloadMediaKind.jav,
          sourceUri: 'magnet:?xt=urn:btih:abc',
          movieNumber: 'ABC-001',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException error) => error.error?.code,
            'error.code',
            'download_task_already_imported',
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
      'triggerDownloadTaskImport posts to the task import endpoint',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/download-tasks/7/import',
          statusCode: 202,
          body: {'task_id': 7, 'task_run_id': 42, 'status': 'accepted'},
        );

        await bundle.downloadsApi.triggerDownloadTaskImport(7);

        final request = bundle.adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/download-tasks/7/import');
      },
    );

    test(
      'getDownloadTaskFiles gets the task files endpoint and parses files',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/download-tasks/7/files',
          body: [
            {
              'name': 'ABC-001.mkv',
              'relative_path': 'ABC-001/ABC-001.mkv',
              'size_bytes': 123,
              'is_video': true,
            },
            {
              'name': 'zh.srt',
              'relative_path': 'ABC-001/subs/zh.srt',
              'size_bytes': 45,
              'is_video': false,
            },
          ],
        );

        final files = await bundle.downloadsApi.getDownloadTaskFiles(7);

        final request = bundle.adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/download-tasks/7/files');
        expect(files, hasLength(2));
        expect(files.first.name, 'ABC-001.mkv');
        expect(files.first.relativePath, 'ABC-001/ABC-001.mkv');
        expect(files.first.sizeBytes, 123);
        expect(files.first.isVideo, isTrue);
        expect(files.last.name, 'zh.srt');
        expect(files.last.isVideo, isFalse);
      },
    );

    test(
      'triggerDownloadTaskBatchImport posts task ids and parses result',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/download-tasks/imports',
          statusCode: 202,
          body: {
            'accepted_count': 2,
            'skipped_task_ids': [7],
          },
        );

        final result = await bundle.downloadsApi.triggerDownloadTaskBatchImport(
          [1, 2, 7],
        );

        final request = bundle.adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/download-tasks/imports');
        expect(request.body, {
          'task_ids': [1, 2, 7],
        });
        expect(result.acceptedCount, 2);
        expect(result.skippedTaskIds, [7]);
      },
    );

    test(
      'triggerDownloadTaskBatchImport chunks ids over 100 and merges results',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        final ids = List<int>.generate(250, (index) => index + 1);
        for (final body in const <Map<String, dynamic>>[
          {'accepted_count': 100, 'skipped_task_ids': <int>[]},
          {'accepted_count': 100, 'skipped_task_ids': <int>[]},
          {
            'accepted_count': 49,
            'skipped_task_ids': [250],
          },
        ]) {
          bundle.adapter.enqueueJson(
            method: 'POST',
            path: '/download-tasks/imports',
            statusCode: 202,
            body: body,
          );
        }

        final result = await bundle.downloadsApi.triggerDownloadTaskBatchImport(
          ids,
        );

        final posts = bundle.adapter.requests.toList();
        expect(posts, hasLength(3));
        expect(posts[0].body, {'task_ids': ids.sublist(0, 100)});
        expect(posts[1].body, {'task_ids': ids.sublist(100, 200)});
        expect(posts[2].body, {'task_ids': ids.sublist(200)});
        expect(result.acceptedCount, 249);
        expect(result.skippedTaskIds, [250]);
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

Map<String, dynamic> _downloadTaskResponse({
  int id = 123,
  String? movieNumber = 'ABC-001',
}) {
  return <String, dynamic>{
    'task': <String, dynamic>{
      'id': id,
      'client_id': 2,
      'movie_number': movieNumber,
      'name': movieNumber ?? 'manual',
      'remote_id': 'remote-$id',
      'state': 'queued',
      'progress': 0.0,
      'import_status': 'pending',
      'created_at': '2026-03-10T08:10:00Z',
      'updated_at': '2026-03-10T08:10:00Z',
    },
    'created': true,
  };
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
