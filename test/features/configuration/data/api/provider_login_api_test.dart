import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  test('creates and deletes a provider login session', () async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media-libraries/provider-login-sessions',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 'login-session',
        'provider_key': 'cloud115',
        'account_label': '123456',
        'expires_at': '2026-11-03T12:10:00+08:00',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-libraries/provider-login-sessions/login-session',
      statusCode: 204,
    );

    final session = await bundle.providerLoginApi.createSession(
      providerKey: 'cloud115',
      cookies: const <ProviderLoginCookieSetPayload>[
        ProviderLoginCookieSetPayload(
          url: 'https://115.com/',
          values: <String, String>{'UID': '123456', 'CID': 'cid'},
        ),
      ],
      localStorage: const <ProviderLoginLocalStorageSetPayload>[],
    );
    await bundle.providerLoginApi.deleteSession(session.id);

    expect(session.id, 'login-session');
    expect(session.providerKey, 'cloud115');
    expect(session.accountLabel, '123456');
    expect(session.expiresAt, isNotNull);
    final request = bundle.adapter.requests.first;
    expect(request.body, <String, dynamic>{
      'provider_key': 'cloud115',
      'cookies': <Map<String, dynamic>>[
        <String, dynamic>{
          'url': 'https://115.com/',
          'values': <String, String>{'UID': '123456', 'CID': 'cid'},
        },
      ],
      'local_storage': <Map<String, dynamic>>[],
    });
    expect(
      bundle.adapter.hitCount(
        'DELETE',
        '/media-libraries/provider-login-sessions/login-session',
      ),
      1,
    );
  });
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-11-03T12:00:00Z'),
  );
  return store;
}
