import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';

import '../../support/test_api_bundle.dart';

void main() {
  test('download clients API maps provider-neutral CRUD payloads', () async {
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
          'library_id': 7,
          'provider_config': {'endpoint': 'http://demo'},
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
        'library_id': 8,
        'provider_config': {'endpoint': 'http://demo-b', 'token': '***'},
        'created_at': '2026-03-10T09:00:00Z',
        'updated_at': '2026-03-10T09:00:00Z',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/download-clients/2',
      body: {
        'id': 2,
        'name': 'client-c',
        'library_id': 9,
        'provider_config': {'endpoint': 'http://demo-c'},
        'created_at': '2026-03-10T09:00:00Z',
        'updated_at': '2026-03-10T10:00:00Z',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/download-clients/2',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients/test',
      body: {
        'status': 'warning',
        'checks': [
          {
            'key': 'hardlink',
            'status': 'warning',
            'code': 'hardlink_unavailable',
            'message': '导入时会回退为复制。',
          },
        ],
        'checked_at': '2026-03-10T10:01:00Z',
        'elapsed_ms': 12,
      },
    );

    final list = await bundle.downloadClientsApi.getClients();
    final created = await bundle.downloadClientsApi.createClient(
      const CreateDownloadClientPayload(
        name: 'client-b',
        libraryId: 8,
        providerConfig: {'endpoint': 'http://demo-b', 'token': 'secret'},
      ),
    );
    final updated = await bundle.downloadClientsApi.updateClient(
      clientId: 2,
      payload: const UpdateDownloadClientPayload(
        name: 'client-c',
        libraryId: 9,
        providerConfig: {'endpoint': 'http://demo-c'},
      ),
    );
    final diagnostic = await bundle.downloadClientsApi.testClient(
      const DownloadClientTestPayload(
        clientId: 2,
        libraryId: 9,
        providerConfig: <String, dynamic>{'endpoint': 'http://demo-c'},
      ),
    );
    await bundle.downloadClientsApi.deleteClient(2);

    expect(list.single.providerConfig['endpoint'], 'http://demo');
    expect(created.libraryId, 8);
    expect(updated.name, 'client-c');
    expect(diagnostic.status, 'warning');
    expect(diagnostic.checks.single.code, 'hardlink_unavailable');
    expect(bundle.adapter.requests[1].body, {
      'name': 'client-b',
      'library_id': 8,
      'provider_config': {'endpoint': 'http://demo-b', 'token': 'secret'},
    });
    expect(bundle.adapter.requests[2].body, {
      'name': 'client-c',
      'library_id': 9,
      'provider_config': {'endpoint': 'http://demo-c'},
    });
    expect(bundle.adapter.requests[3].body, {
      'client_id': 2,
      'library_id': 9,
      'provider_config': {'endpoint': 'http://demo-c'},
    });
  });

  test('download client DTO maps the library relation', () {
    expect(
      DownloadClientDto.fromJson(const <String, dynamic>{
        'id': 1,
        'name': 'client',
        'library_id': 7,
        'provider_config': <String, dynamic>{},
      }).libraryId,
      7,
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
