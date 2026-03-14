import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import '../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'old-access',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );

    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('retries original request once after refreshing token', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'token expired',
        },
      },
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/auth/token-refreshes',
      statusCode: 200,
      body: <String, dynamic>{
        'access_token': 'new-access',
        'refresh_token': 'new-refresh',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': '2026-03-08T11:00:00Z',
        'refresh_expires_at': '2026-03-15T11:00:00Z',
        'user': <String, dynamic>{'username': 'account'},
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 200,
      body: <String, dynamic>{
        'actors': <String, dynamic>{'female_total': 1, 'female_subscribed': 1},
        'movies': <String, dynamic>{'total': 2, 'subscribed': 1, 'playable': 1},
        'media_files': <String, dynamic>{'total': 3, 'total_size_bytes': 100},
        'media_libraries': <String, dynamic>{'total': 1},
      },
    );

    final response = await apiClient.get('/status');

    expect(response['movies']['total'], 2);
    expect(adapter.hitCount('POST', '/auth/token-refreshes'), 1);
    expect(adapter.hitCount('GET', '/status'), 2);
    expect(sessionStore.accessToken, 'new-access');
    expect(sessionStore.refreshToken, 'new-refresh');
  });

  test('clears session and throws unauthorized when refresh fails', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'expired',
        },
      },
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/auth/token-refreshes',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_refresh_token',
          'message': 'invalid refresh token',
        },
      },
    );

    await expectLater(
      () => apiClient.get('/status'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'invalid_refresh_token',
        ),
      ),
    );
    expect(sessionStore.hasSession, isFalse);
  });

  test('parallel unauthorized requests trigger only one refresh', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'expired',
        },
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'expired',
        },
      },
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/auth/token-refreshes',
      statusCode: 200,
      body: <String, dynamic>{
        'access_token': 'refreshed-access',
        'refresh_token': 'refreshed-refresh',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': '2026-03-08T11:00:00Z',
        'refresh_expires_at': '2026-03-15T11:00:00Z',
        'user': <String, dynamic>{'username': 'account'},
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 200,
      body: <String, dynamic>{
        'actors': <String, dynamic>{'female_total': 1, 'female_subscribed': 1},
        'movies': <String, dynamic>{'total': 2, 'subscribed': 1, 'playable': 1},
        'media_files': <String, dynamic>{'total': 3, 'total_size_bytes': 100},
        'media_libraries': <String, dynamic>{'total': 1},
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 200,
      body: <String, dynamic>{
        'actors': <String, dynamic>{'female_total': 1, 'female_subscribed': 1},
        'movies': <String, dynamic>{'total': 2, 'subscribed': 1, 'playable': 1},
        'media_files': <String, dynamic>{'total': 3, 'total_size_bytes': 100},
        'media_libraries': <String, dynamic>{'total': 1},
      },
    );

    await Future.wait(<Future<Map<String, dynamic>>>[
      apiClient.get('/status'),
      apiClient.get('/status'),
    ]);

    expect(adapter.hitCount('POST', '/auth/token-refreshes'), 1);
    expect(adapter.hitCount('GET', '/status'), 4);
  });

  test('business invalid_credentials does not trigger token refresh', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/account/password',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_credentials',
          'message': 'Current password is incorrect',
          'details': null,
        },
      },
    );

    await expectLater(
      () => apiClient.postNoContent(
        '/account/password',
        data: <String, dynamic>{
          'current_password': 'wrong-password',
          'new_password': 'new-password',
        },
      ),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.error?.code,
              'error.code',
              'invalid_credentials',
            )
            .having(
              (ApiException error) => error.error?.message,
              'error.message',
              'Current password is incorrect',
            ),
      ),
    );

    expect(adapter.hitCount('POST', '/auth/token-refreshes'), 0);
    expect(sessionStore.hasSession, isTrue);
  });
}
