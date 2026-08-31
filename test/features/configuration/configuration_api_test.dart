import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/cloud115_qr_login_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';

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

    test(
      'cloud115 download client only sends name, kind and media library',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/download-clients',
          statusCode: 201,
          body: <String, dynamic>{
            'id': 8,
            'name': '115 主账号',
            'kind': 'cloud115',
            'base_url': null,
            'username': null,
            'client_save_path': null,
            'local_root_path': null,
            'media_library_id': 12,
            'has_password': false,
            'created_at': '2026-07-15T08:00:00Z',
            'updated_at': '2026-07-15T08:00:00Z',
          },
        );

        final created = await bundle.downloadClientsApi.createClient(
          const CreateDownloadClientPayload(
            name: '115 主账号',
            kind: DownloadClientKind.cloud115,
            mediaLibraryId: 12,
          ),
        );

        expect(created.kind, DownloadClientKind.cloud115);
        expect(created.baseUrl, isEmpty);
        expect(bundle.adapter.requests.single.body, <String, dynamic>{
          'name': '115 主账号',
          'kind': 'cloud115',
          'media_library_id': 12,
        });
      },
    );

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
      expect(healthy.checkedAt, DateTime.parse('2026-07-03T12:00:00'));

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
      expect(storageWarn.warnings.single, contains('下载目录到媒体库不支持硬链接'));
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

    test(
      'download client probe apis send form payload without client id',
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
              'probe_local_dir':
                  '/mnt/downloads/new/.sakuramedia-diagnostics/xx',
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
      },
    );

    test(
      'download client probe apis carry null password + client id for edit',
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
      },
    );

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
            'backend': 'local',
            'backend_config': {'root_path': '/media/library/main'},
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
          'backend': 'local',
          'backend_config': {'root_path': '/media/library/archive'},
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
          'backend': 'local',
          'backend_config': {'root_path': '/media/library/archive'},
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
        ),
      );
      await bundle.mediaLibrariesApi.deleteLibrary(2);

      expect(libraries.single.name, 'Main Library');
      expect(libraries.single.rootPath, '/media/library/main');
      expect(created.id, 2);
      expect(updated.name, 'Archive Library Updated');
      expect(bundle.adapter.requests[1].body['name'], 'Archive Library');
      expect(bundle.adapter.requests[1].body['backend'], 'local');
      expect(bundle.adapter.requests[1].body['backend_config'], {
        'root_path': '/media/library/archive',
      });
      expect(bundle.adapter.requests[2].body, <String, dynamic>{
        'name': 'Archive Library Updated',
      });
      expect(bundle.adapter.hitCount('DELETE', '/media-libraries/2'), 1);
    });

    test(
      'cloud115 qr login api maps token, status, create and reauth',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/media-libraries/cloud115/qrlogin/token',
          body: {
            'uid': 'uid-1',
            'time': 1700000000,
            'sign': 'sign-1',
            'qrcode_png_base64': 'UE5H',
          },
        );
        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/media-libraries/cloud115/qrlogin/status',
          body: {'status': 'scanned'},
        );
        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/media-libraries/cloud115',
          statusCode: 201,
          body: {
            'id': 8,
            'name': '115 主账号',
            'backend': 'cloud115',
            'backend_config': {'root_cid': 'cid-root', 'app': 'wechatmini'},
            'created_at': '2026-07-14T09:30:00Z',
            'updated_at': '2026-07-14T09:30:00Z',
          },
        );
        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/media-libraries/cloud115/8/reauth',
          body: {
            'id': 8,
            'name': '115 主账号',
            'backend': 'cloud115',
            'backend_config': {'root_cid': 'cid-root', 'app': 'web'},
            'created_at': '2026-07-14T09:30:00Z',
            'updated_at': '2026-07-14T10:00:00Z',
          },
        );

        final token = await bundle.mediaLibrariesApi.getCloud115QrToken();
        final status = await bundle.mediaLibrariesApi.pollCloud115QrStatus(
          token,
        );
        final created = await bundle.mediaLibrariesApi.createCloud115Library(
          const Cloud115LibraryCreatePayload(
            name: '115 主账号',
            uid: 'uid-1',
            app: Cloud115LoginApp.wechatmini,
          ),
        );
        final reauthed = await bundle.mediaLibrariesApi.reauthCloud115Library(
          libraryId: 8,
          payload: const Cloud115LibraryReauthPayload(
            uid: 'uid-2',
            app: Cloud115LoginApp.web,
          ),
        );

        expect(status.status, Cloud115QrStatus.scanned);
        expect(created.isCloud115, isTrue);
        expect(created.cloud115App, Cloud115LoginApp.wechatmini);
        expect(reauthed.cloud115App, Cloud115LoginApp.web);
        expect(
          bundle.adapter.requests[1].receiveTimeout,
          const Duration(seconds: 45),
        );
        expect(bundle.adapter.requests[2].body, {
          'name': '115 主账号',
          'uid': 'uid-1',
          'app': 'wechatmini',
        });
        expect(
          bundle.adapter.requests[2].receiveTimeout,
          const Duration(seconds: 60),
        );
        expect(bundle.adapter.requests[3].body, {'uid': 'uid-2', 'app': 'web'});
      },
    );

    test('cloud115 directory api maps pagination and entries', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries/cloud115/8/entries',
        body: {
          'cid': 'cid-parent',
          'total': 3,
          'offset': 1,
          'limit': 1,
          'root_cid': 'cid-root',
          'entries': [
            {
              'entry_id': 'cid-child',
              'name': '来源目录',
              'is_dir': true,
              'size': 0,
              'is_video': false,
              'mtime': 1700000000,
            },
          ],
        },
      );

      final page = await bundle.mediaLibrariesApi.listCloud115Directory(
        libraryId: 8,
        cid: 'cid-parent',
        offset: 1,
        limit: 1,
      );

      expect(page.cid, 'cid-parent');
      expect(page.rootCid, 'cid-root');
      expect(page.entries.single.entryId, 'cid-child');
      expect(page.entries.single.isDirectory, isTrue);
      expect(page.entries.single.mtime, 1700000000);
      expect(page.hasMore, isTrue);
      expect(bundle.adapter.requests.single.uri.queryParameters, {
        'cid': 'cid-parent',
        'offset': '1',
        'limit': '1',
      });
    });

    test('indexer settings api maps singleton resource', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/indexer-settings',
        body: {
          'indexers': [
            {
              'id': 1,
              'name': 'mteam',
              'url': 'https://example.com/torznab',
              'kind': 'pt',
              'api_key': 'secret-key',
              'download_clients': [
                {'id': 2, 'name': 'qb-main', 'kind': 'qbittorrent'},
              ],
            },
          ],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: {
          'indexers': [
            {
              'id': 1,
              'name': 'mteam',
              'url': 'https://example.com/torznab',
              'kind': 'pt',
              'api_key': 'updated-key',
              'download_clients': [
                {'id': 2, 'name': 'qb-main', 'kind': 'qbittorrent'},
              ],
            },
          ],
        },
      );

      final settings = await bundle.indexerSettingsApi.getSettings();
      final updated = await bundle.indexerSettingsApi.updateSettings(
        const UpdateIndexerSettingsPayload(
          indexers: [
            IndexerEntryDto(
              id: 0,
              name: 'mteam',
              url: 'https://example.com/torznab',
              kind: 'pt',
              apiKey: 'updated-key',
              downloadClients: [
                IndexerBoundClientDto(
                  id: 2,
                  name: 'qb-main',
                  kind: DownloadClientKind.qbittorrent,
                ),
              ],
            ),
          ],
        ),
      );

      expect(settings.indexers.single.id, 1);
      expect(settings.indexers.single.apiKey, 'secret-key');
      expect(settings.indexers.single.downloadClientIds, [2]);
      expect(settings.indexers.single.downloadClientNames, 'qb-main');
      expect(updated.indexers.single.apiKey, 'updated-key');
      expect(updated.indexers.single.downloadClientNames, 'qb-main');
      expect(bundle.adapter.requests[1].body.containsKey('type'), isFalse);
      expect(bundle.adapter.requests[1].body.containsKey('api_key'), isFalse);
      expect(
        bundle.adapter.requests[1].body['indexers'][0]['api_key'],
        'updated-key',
      );
      expect(
        bundle.adapter.requests[1].body['indexers'][0]['download_client_ids'],
        [2],
      );
    });

    test(
      'indexer connection test maps healthy and unhealthy results',
      () async {
        final sessionStore = await _buildLoggedInSessionStore();
        final bundle = await createTestApiBundle(sessionStore);
        addTearDown(bundle.dispose);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/indexer-settings/test',
          body: <String, dynamic>{
            'healthy': true,
            'checked_at': '2026-07-11T08:00:00Z',
            'query': 'SSNI-888',
            'indexers_checked': 2,
            'result_count': 5,
            'elapsed_ms': 342,
            'error': null,
          },
        );
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/indexer-settings/test',
          body: <String, dynamic>{
            'healthy': false,
            'checked_at': '2026-07-11T08:01:00Z',
            'query': 'SSNI-888',
            'indexers_checked': 0,
            'result_count': 0,
            'elapsed_ms': 2,
            'error': <String, dynamic>{
              'type': 'no_indexers_configured',
              'message': '尚未配置任何 indexer',
            },
          },
        );
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/indexer-settings/test',
          body: <String, dynamic>{
            'healthy': false,
            'checked_at': '2026-07-11T08:02:00Z',
            'query': 'SSNI-888',
            'indexers_checked': 1,
            'result_count': 0,
            'elapsed_ms': 30,
            'error': <String, dynamic>{
              'type': 'torznab_request_error',
              'message': 'connection refused',
            },
          },
        );

        final healthy = await bundle.indexerSettingsApi.testConnection();
        final noIndexers = await bundle.indexerSettingsApi.testConnection();
        final requestError = await bundle.indexerSettingsApi.testConnection();

        expect(healthy.healthy, isTrue);
        expect(healthy.checkedAt, DateTime.parse('2026-07-11T08:00:00Z'));
        expect(healthy.query, 'SSNI-888');
        expect(healthy.indexersChecked, 2);
        expect(healthy.resultCount, 5);
        expect(healthy.elapsedMs, 342);
        expect(healthy.error, isNull);
        expect(noIndexers.healthy, isFalse);
        expect(noIndexers.error?.type, 'no_indexers_configured');
        expect(requestError.error?.type, 'torznab_request_error');
        expect(requestError.error?.message, 'connection refused');
        expect(bundle.adapter.hitCount('GET', '/indexer-settings/test'), 3);
      },
    );

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
        expect(settings.indexers.single.apiKey, isNull);
        expect(settings.indexers.single.downloadClientIds, isEmpty);
        expect(settings.indexers.single.downloadClientNames, '');
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
