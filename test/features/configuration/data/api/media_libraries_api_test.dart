import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  test('media library API uses provider key/config for CRUD', () async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Main',
          'provider_key': 'demo',
          'provider_config': <String, dynamic>{'root': '/media/main'},
          'created_at': '2026-03-08T09:30:00Z',
          'updated_at': '2026-03-08T10:30:00Z',
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media-libraries',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 2,
        'name': 'Archive',
        'provider_key': 'demo',
        'provider_config': <String, dynamic>{'root': '/media/archive'},
        'created_at': '2026-03-09T09:30:00Z',
        'updated_at': '2026-03-09T09:30:00Z',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/media-libraries/2',
      body: <String, dynamic>{
        'id': 2,
        'name': 'Archive Updated',
        'provider_key': 'demo',
        'provider_config': <String, dynamic>{'root': '/media/archive'},
        'created_at': '2026-03-09T09:30:00Z',
        'updated_at': '2026-03-10T09:30:00Z',
      },
    );

    final api = bundle.mediaLibrariesApi;
    final libraries = await api.getLibraries();
    final created = await api.createLibrary(
      const CreateMediaLibraryPayload(
        name: 'Archive',
        providerKey: 'demo',
        providerConfig: <String, dynamic>{'root': '/media/archive'},
      ),
    );
    final updated = await api.updateLibrary(
      libraryId: 2,
      payload: const UpdateMediaLibraryPayload(name: 'Archive Updated'),
    );

    expect(libraries.single.providerKey, 'demo');
    expect(libraries.single.providerConfig, {'root': '/media/main'});
    expect(created.providerConfig, {'root': '/media/archive'});
    expect(updated.name, 'Archive Updated');
    expect(bundle.adapter.requests[1].body, <String, dynamic>{
      'name': 'Archive',
      'provider_key': 'demo',
      'provider_config': <String, dynamic>{'root': '/media/archive'},
    });
    expect(bundle.adapter.requests[2].body, <String, dynamic>{
      'name': 'Archive Updated',
    });
  });

  test('update payload can send provider config while omitting name', () {
    expect(
      const UpdateMediaLibraryPayload(
        providerConfig: <String, dynamic>{'url': 'https://example.com'},
      ).toJson(),
      <String, dynamic>{
        'provider_config': <String, dynamic>{'url': 'https://example.com'},
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
