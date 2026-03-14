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
            'source': 'jackett',
            'indexer_name': 'mteam',
            'indexer_kind': 'pt',
            'resolved_client_id': 2,
            'resolved_client_name': 'qb-main',
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
            source: 'jackett',
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
            'source': 'jackett',
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
              source: 'jackett',
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
