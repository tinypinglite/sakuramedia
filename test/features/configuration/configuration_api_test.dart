import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';

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
