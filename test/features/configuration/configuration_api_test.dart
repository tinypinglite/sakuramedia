import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_dto.dart';

import '../../support/test_api_bundle.dart';

void main() {
  group('configuration APIs', () {
    test('download clients api maps CRUD endpoints and payloads', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-clients',
        body: [
          {
            'id': 1,
            'name': 'client-a',
            'base_url': 'http://localhost:8080',
            'username': 'alice',
            'client_save_path': '/downloads/a',
            'local_root_path': '/mnt/qb/downloads/a',
            'media_library_id': 1,
            'has_password': true,
            'created_at': '2026-03-10T08:00:00Z',
            'updated_at': '2026-03-10T08:00:00Z',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-clients',
        statusCode: 201,
        body: {
          'id': 2,
          'name': 'client-b',
          'base_url': 'https://qb.example.com',
          'username': 'bob',
          'client_save_path': '/downloads/b',
          'local_root_path': '/data/downloads/b',
          'media_library_id': 2,
          'has_password': true,
          'created_at': '2026-03-10T09:00:00Z',
          'updated_at': '2026-03-10T09:00:00Z',
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/download-clients/2',
        body: {
          'id': 2,
          'name': 'client-b',
          'base_url': 'https://qb.example.com',
          'username': 'charlie',
          'client_save_path': '/downloads/b',
          'local_root_path': '/data/downloads/b',
          'media_library_id': 2,
          'has_password': true,
          'created_at': '2026-03-10T09:00:00Z',
          'updated_at': '2026-03-10T09:10:00Z',
        },
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/download-clients/2',
        statusCode: 204,
      );

      final list = await bundle.downloadClientsApi.getClients();
      final created = await bundle.downloadClientsApi.createClient(
        const CreateDownloadClientPayload(
          name: 'client-b',
          baseUrl: 'https://qb.example.com',
          username: 'bob',
          password: 'secret',
          clientSavePath: '/downloads/b',
          localRootPath: '/data/downloads/b',
          mediaLibraryId: 2,
        ),
      );
      final updated = await bundle.downloadClientsApi.updateClient(
        clientId: 2,
        payload: const UpdateDownloadClientPayload(
          username: 'charlie',
          mediaLibraryId: 2,
        ),
      );
      await bundle.downloadClientsApi.deleteClient(2);

      expect(list.single.name, 'client-a');
      expect(list.single.clientSavePath, '/downloads/a');
      expect(list.single.localRootPath, '/mnt/qb/downloads/a');
      expect(created.id, 2);
      expect(updated.username, 'charlie');
      expect(bundle.adapter.requests[1].body['password'], 'secret');
      expect(
        bundle.adapter.requests[1].body['client_save_path'],
        '/downloads/b',
      );
      expect(
        bundle.adapter.requests[1].body['local_root_path'],
        '/data/downloads/b',
      );
      expect(bundle.adapter.requests[2].body.containsKey('password'), isFalse);
    });

    test('download clients diagnostic apis map endpoints and results', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-clients/1/test',
        body: {
          'healthy': true,
          'checked_at': '2026-07-03T12:00:00',
          'client_id': 1,
          'client_name': 'client-a',
          'base_url': 'http://localhost:8080',
          'elapsed_ms': 18,
          'version': '5.0.4',
          'web_api_version': '2.11.4',
          'error': null,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-clients/2/test',
        body: {
          'healthy': false,
          'checked_at': '2026-07-03T12:00:00',
          'client_id': 2,
          'client_name': 'client-b',
          'base_url': 'http://localhost:8081',
          'elapsed_ms': 1002,
          'version': null,
          'web_api_version': null,
          'error': {
            'type': 'qbittorrent_request_error',
            'message': 'login failed',
          },
        },
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-clients/1/storage-test',
        body: {
          'healthy': true,
          'checked_at': '2026-07-03T12:05:00',
          'client_id': 1,
          'client_name': 'client-a',
          'elapsed_ms': 24,
          'warnings': <String>[],
          'directory_mapping': {
            'status': 'ok',
            'client_save_path': '/downloads/a',
            'local_root_path': '/mnt/qb/downloads/a',
            'probe_remote_dir': '/downloads/a/.sakuramedia-diagnostics/4f9b',
            'probe_local_dir':
                '/mnt/qb/downloads/a/.sakuramedia-diagnostics/4f9b',
            'sentinel_visible_to_qb': true,
            'error': null,
          },
          'hardlink': {
            'status': 'ok',
            'supported': true,
            'source_path':
                '/mnt/qb/downloads/a/.sakuramedia-diagnostics/4f9b/sentinel.txt',
            'target_path':
                '/media/library/main/.sakuramedia-diagnostics/4f9b/sentinel.link',
            'error': null,
          },
        },
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-clients/2/storage-test',
        body: {
          'healthy': true,
          'checked_at': '2026-07-03T12:05:00',
          'client_id': 2,
          'client_name': 'client-b',
          'elapsed_ms': 31,
          'warnings': ['下载目录到媒体库不支持硬链接，导入会回退为复制'],
          'directory_mapping': {
            'status': 'ok',
            'client_save_path': '/downloads/b',
            'local_root_path': '/mnt/qb/downloads/b',
            'probe_remote_dir': '/downloads/b/.sakuramedia-diagnostics/aaaa',
            'probe_local_dir':
                '/mnt/qb/downloads/b/.sakuramedia-diagnostics/aaaa',
            'sentinel_visible_to_qb': true,
            'error': null,
          },
          'hardlink': {
            'status': 'failed',
            'supported': false,
            'source_path':
                '/mnt/qb/downloads/b/.sakuramedia-diagnostics/aaaa/sentinel.txt',
            'target_path':
                '/media/library/main/.sakuramedia-diagnostics/aaaa/sentinel.link',
            'error': {
              'type': 'hardlink_not_supported',
              'message': 'Invalid cross-device link',
            },
          },
        },
      );

      final healthy = await bundle.downloadClientsApi.testClient(1);
      final unhealthy = await bundle.downloadClientsApi.testClient(2);
      final storageOk = await bundle.downloadClientsApi.storageTestClient(1);
      final storageWarn = await bundle.downloadClientsApi.storageTestClient(2);

      expect(healthy.healthy, isTrue);
      expect(healthy.version, '5.0.4');
      expect(healthy.webApiVersion, '2.11.4');
      expect(healthy.error, isNull);
      expect(
        healthy.checkedAt,
        DateTime.parse('2026-07-03T12:00:00'),
      );

      expect(unhealthy.healthy, isFalse);
      expect(unhealthy.version, isNull);
      expect(unhealthy.webApiVersion, isNull);
      expect(unhealthy.error?.type, 'qbittorrent_request_error');
      expect(unhealthy.error?.message, 'login failed');

      expect(storageOk.healthy, isTrue);
      expect(storageOk.warnings, isEmpty);
      expect(storageOk.directoryMapping.status, 'ok');
      expect(storageOk.directoryMapping.sentinelVisibleToQb, isTrue);
      expect(storageOk.hardlink.status, 'ok');
      expect(storageOk.hardlink.supported, isTrue);

      expect(storageWarn.healthy, isTrue);
      expect(storageWarn.warnings.length, 1);
      expect(
        storageWarn.warnings.single,
        contains('下载目录到媒体库不支持硬链接'),
      );
      expect(storageWarn.hardlink.status, 'failed');
      expect(storageWarn.hardlink.supported, isFalse);
      expect(storageWarn.hardlink.error?.type, 'hardlink_not_supported');

      expect(bundle.adapter.requests.length, 4);
      expect(bundle.adapter.requests[0].method, 'GET');
      expect(bundle.adapter.requests[0].path, '/download-clients/1/test');
      expect(bundle.adapter.requests[2].method, 'POST');
      expect(
        bundle.adapter.requests[2].path,
        '/download-clients/1/storage-test',
      );
    });

    test('download client probe apis send form payload without client id',
        () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-clients/probe/test',
        body: {
          'healthy': true,
          'checked_at': '2026-07-03T13:00:00',
          'client_id': 0,
          'client_name': '',
          'base_url': 'http://qb.example.com',
          'elapsed_ms': 12,
          'version': '5.0.4',
          'web_api_version': '2.11.4',
          'error': null,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-clients/probe/storage-test',
        body: {
          'healthy': true,
          'checked_at': '2026-07-03T13:05:00',
          'client_id': 0,
          'client_name': '',
          'elapsed_ms': 22,
          'warnings': <String>[],
          'directory_mapping': {
            'status': 'ok',
            'client_save_path': '/downloads/new',
            'local_root_path': '/mnt/downloads/new',
            'probe_remote_dir': '/downloads/new/.sakuramedia-diagnostics/xx',
            'probe_local_dir': '/mnt/downloads/new/.sakuramedia-diagnostics/xx',
            'sentinel_visible_to_qb': true,
            'error': null,
          },
          'hardlink': {
            'status': 'ok',
            'supported': true,
            'source_path':
                '/mnt/downloads/new/.sakuramedia-diagnostics/xx/sentinel.txt',
            'target_path':
                '/library/main/.sakuramedia-diagnostics/xx/sentinel.link',
            'error': null,
          },
        },
      );

      final connectivity = await bundle.downloadClientsApi.probeTestClient(
        const DownloadClientProbeTestPayload(
          baseUrl: 'http://qb.example.com',
          username: 'alice',
          password: 'fresh-secret',
        ),
      );
      final storage = await bundle.downloadClientsApi.probeStorageTestClient(
        const DownloadClientProbeStorageTestPayload(
          baseUrl: 'http://qb.example.com',
          username: 'alice',
          password: 'fresh-secret',
          clientSavePath: '/downloads/new',
          localRootPath: '/mnt/downloads/new',
          mediaLibraryId: 3,
        ),
      );

      expect(connectivity.healthy, isTrue);
      expect(connectivity.version, '5.0.4');
      expect(storage.healthy, isTrue);
      expect(storage.directoryMapping.clientSavePath, '/downloads/new');

      expect(bundle.adapter.requests[0].method, 'POST');
      expect(bundle.adapter.requests[0].path, '/download-clients/probe/test');
      final connBody = bundle.adapter.requests[0].body;
      expect(connBody['base_url'], 'http://qb.example.com');
      expect(connBody['username'], 'alice');
      expect(connBody['password'], 'fresh-secret');
      expect(connBody.containsKey('client_id'), isFalse);

      expect(bundle.adapter.requests[1].method, 'POST');
      expect(
        bundle.adapter.requests[1].path,
        '/download-clients/probe/storage-test',
      );
      final storageBody = bundle.adapter.requests[1].body;
      expect(storageBody['client_save_path'], '/downloads/new');
      expect(storageBody['local_root_path'], '/mnt/downloads/new');
      expect(storageBody['media_library_id'], 3);
      expect(storageBody.containsKey('client_id'), isFalse);
    });

    test('download client probe apis carry null password + client id for edit',
        () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-clients/probe/test',
        body: {
          'healthy': true,
          'checked_at': '2026-07-03T13:10:00',
          'client_id': 42,
          'client_name': 'client-a',
          'base_url': 'http://qb.example.com',
          'elapsed_ms': 9,
          'version': '5.0.4',
          'web_api_version': '2.11.4',
          'error': null,
        },
      );

      final result = await bundle.downloadClientsApi.probeTestClient(
        const DownloadClientProbeTestPayload(
          baseUrl: 'http://qb.example.com',
          username: 'alice',
          password: null,
          clientId: 42,
        ),
      );

      expect(result.healthy, isTrue);
      final body = bundle.adapter.requests[0].body;
      expect(body['password'], isNull);
      expect(body['client_id'], 42);
    });

    test('download client diagnostic dtos tolerate missing fields', () {
      final test = DownloadClientTestResultDto.fromJson(
        const <String, dynamic>{},
      );
      expect(test.healthy, isFalse);
      expect(test.clientId, 0);
      expect(test.clientName, isEmpty);
      expect(test.version, isNull);
      expect(test.webApiVersion, isNull);
      expect(test.error, isNull);
      expect(test.checkedAt, isNull);

      final storage = DownloadClientStorageTestResultDto.fromJson(
        const <String, dynamic>{},
      );
      expect(storage.healthy, isFalse);
      expect(storage.warnings, isEmpty);
      expect(storage.directoryMapping.status, isEmpty);
      expect(storage.directoryMapping.sentinelVisibleToQb, isFalse);
      expect(storage.directoryMapping.error, isNull);
      expect(storage.hardlink.supported, isFalse);
      expect(storage.hardlink.error, isNull);
    });

    test('media libraries api maps CRUD endpoints and payloads', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries',
        body: [
          {
            'id': 1,
            'name': 'Main Library',
            'root_path': '/media/library/main',
            'created_at': '2026-03-08T09:30:00Z',
            'updated_at': '2026-03-08T09:30:00Z',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/media-libraries',
        statusCode: 201,
        body: {
          'id': 2,
          'name': 'Archive Library',
          'root_path': '/media/library/archive',
          'created_at': '2026-03-09T09:30:00Z',
          'updated_at': '2026-03-09T09:30:00Z',
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/media-libraries/2',
        body: {
          'id': 2,
          'name': 'Archive Library Updated',
          'root_path': '/media/library/archive-new',
          'created_at': '2026-03-09T09:30:00Z',
          'updated_at': '2026-03-10T09:30:00Z',
        },
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media-libraries/2',
        statusCode: 204,
      );

      final libraries = await bundle.mediaLibrariesApi.getLibraries();
      final created = await bundle.mediaLibrariesApi.createLibrary(
        const CreateMediaLibraryPayload(
          name: 'Archive Library',
          rootPath: '/media/library/archive',
        ),
      );
      final updated = await bundle.mediaLibrariesApi.updateLibrary(
        libraryId: 2,
        payload: const UpdateMediaLibraryPayload(
          name: 'Archive Library Updated',
          rootPath: '/media/library/archive-new',
        ),
      );
      await bundle.mediaLibrariesApi.deleteLibrary(2);

      expect(libraries.single.name, 'Main Library');
      expect(libraries.single.rootPath, '/media/library/main');
      expect(created.id, 2);
      expect(updated.name, 'Archive Library Updated');
      expect(bundle.adapter.requests[1].body['name'], 'Archive Library');
      expect(
        bundle.adapter.requests[2].body['root_path'],
        '/media/library/archive-new',
      );
      expect(bundle.adapter.hitCount('DELETE', '/media-libraries/2'), 1);
    });

    test('collection number features api maps singleton resource', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/collection-number-features',
        body: {
          'features': ['CJOB', 'DVAJ'],
          'sync_stats': null,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/collection-number-features',
        body: {
          'features': ['FC2', 'OFJE'],
          'sync_stats': {
            'total_movies': 100,
            'matched_count': 30,
            'updated_to_collection_count': 6,
            'updated_to_single_count': 4,
            'unchanged_count': 90,
          },
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/collection-number-features',
        body: {
          'features': ['FC2'],
          'sync_stats': null,
        },
      );

      final fetched = await bundle.collectionNumberFeaturesApi.getFeatures();
      final updatedWithSync = await bundle.collectionNumberFeaturesApi
          .updateFeatures(
            const UpdateCollectionNumberFeaturesPayload(
              features: ['FC2', 'OFJE'],
            ),
            applyNow: true,
          );
      final updatedWithoutSync = await bundle.collectionNumberFeaturesApi
          .updateFeatures(
            const UpdateCollectionNumberFeaturesPayload(features: ['FC2']),
            applyNow: false,
          );

      expect(fetched.features, ['CJOB', 'DVAJ']);
      expect(fetched.syncStats, isNull);
      expect(updatedWithSync.features, ['FC2', 'OFJE']);
      expect(updatedWithSync.syncStats?.totalMovies, 100);
      expect(updatedWithSync.syncStats?.updatedToCollectionCount, 6);
      expect(updatedWithSync.syncStats?.updatedToSingleCount, 4);
      expect(updatedWithoutSync.features, ['FC2']);
      expect(updatedWithoutSync.syncStats, isNull);

      final patchRequests = bundle.adapter.requests
          .where(
            (request) =>
                request.method == 'PATCH' &&
                request.path == '/collection-number-features',
          )
          .toList(growable: false);
      expect(patchRequests[0].body['features'], ['FC2', 'OFJE']);
      expect(patchRequests[0].uri.queryParameters['apply_now'], 'true');
      expect(patchRequests[1].body['features'], ['FC2']);
      expect(patchRequests[1].uri.queryParameters['apply_now'], 'false');
    });

    test('indexer settings api maps singleton resource', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/indexer-settings',
        body: {
          'type': 'jackett',
          'api_key': 'secret-key',
          'indexers': [
            {
              'id': 1,
              'name': 'mteam',
              'url': 'https://example.com/torznab',
              'kind': 'pt',
              'download_client_id': 2,
              'download_client_name': 'qb-main',
            },
          ],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: {
          'type': 'jackett',
          'api_key': 'updated-key',
          'indexers': [
            {
              'id': 1,
              'name': 'mteam',
              'url': 'https://example.com/torznab',
              'kind': 'pt',
              'download_client_id': 2,
              'download_client_name': 'qb-main',
            },
          ],
        },
      );

      final settings = await bundle.indexerSettingsApi.getSettings();
      final updated = await bundle.indexerSettingsApi.updateSettings(
        const UpdateIndexerSettingsPayload(
          type: 'jackett',
          apiKey: 'updated-key',
          indexers: [
            IndexerEntryDto(
              id: 0,
              name: 'mteam',
              url: 'https://example.com/torznab',
              kind: 'pt',
              downloadClientId: 2,
              downloadClientName: '',
            ),
          ],
        ),
      );

      expect(settings.apiKey, 'secret-key');
      expect(settings.indexers.single.id, 1);
      expect(settings.indexers.single.downloadClientId, 2);
      expect(settings.indexers.single.downloadClientName, 'qb-main');
      expect(updated.apiKey, 'updated-key');
      expect(updated.indexers.single.downloadClientName, 'qb-main');
      expect(bundle.adapter.requests[1].body['api_key'], 'updated-key');
      expect(
        bundle.adapter.requests[1].body['indexers'][0]['download_client_id'],
        2,
      );
    });

    test(
      'indexer settings dto keeps compatibility with missing binding fields',
      () {
        final settings = IndexerSettingsDto.fromJson({
          'type': 'jackett',
          'api_key': 'legacy-key',
          'indexers': [
            {
              'name': 'legacy',
              'url': 'https://example.com/legacy',
              'kind': 'bt',
            },
          ],
        });

        expect(settings.indexers.single.id, 0);
        expect(settings.indexers.single.downloadClientId, 0);
        expect(settings.indexers.single.downloadClientName, '');
      },
    );

    test(
      'movie desc translation settings api maps resource and test endpoint',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/movie-desc-translation-settings',
          body: <String, dynamic>{
            'enabled': false,
            'base_url': 'http://llm.internal:8000',
            'api_key': 'secret-token',
            'model': 'gpt-4o-mini',
            'timeout_seconds': 300.0,
            'connect_timeout_seconds': 3.0,
          },
        );
        bundle.adapter.enqueueJson(
          method: 'PATCH',
          path: '/movie-desc-translation-settings',
          body: <String, dynamic>{
            'enabled': true,
            'base_url': 'http://127.0.0.1:8000',
            'api_key': '',
            'model': 'gpt-4o-mini',
            'timeout_seconds': 180.0,
            'connect_timeout_seconds': 9.0,
          },
        );
        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/movie-desc-translation-settings/test',
          body: const <String, dynamic>{'ok': true},
        );

        final settings =
            await bundle.movieDescTranslationSettingsApi.getSettings();
        final updated = await bundle.movieDescTranslationSettingsApi
            .updateSettings(
              const UpdateMovieDescTranslationSettingsPayload(
                enabled: true,
                baseUrl: 'http://127.0.0.1:8000',
                apiKey: '',
                model: 'gpt-4o-mini',
                timeoutSeconds: 180,
                connectTimeoutSeconds: 9,
              ),
            );
        final ok = await bundle.movieDescTranslationSettingsApi.testSettings(
          const TestMovieDescTranslationSettingsPayload(
            enabled: true,
            baseUrl: 'http://127.0.0.1:8000',
            apiKey: '',
            model: 'gpt-4o-mini',
            timeoutSeconds: 180,
            connectTimeoutSeconds: 9,
          ),
        );

        expect(settings.enabled, isFalse);
        expect(settings.baseUrl, 'http://llm.internal:8000');
        expect(settings.model, 'gpt-4o-mini');
        expect(settings.timeoutSeconds, 300);
        expect(updated.enabled, isTrue);
        expect(updated.connectTimeoutSeconds, 9);
        expect(ok, isTrue);
        expect(
          bundle.adapter.requests[1].body['base_url'],
          'http://127.0.0.1:8000',
        );
        expect(bundle.adapter.requests[2].body['timeout_seconds'], 180.0);
        expect(
          bundle.adapter.hitCount('PATCH', '/movie-desc-translation-settings'),
          1,
        );
        expect(
          bundle.adapter.hitCount(
            'POST',
            '/movie-desc-translation-settings/test',
          ),
          1,
        );
      },
    );
  });
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}
