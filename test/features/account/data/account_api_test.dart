import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late AccountApi accountApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    accountApi = AccountApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getAccount maps response body', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      statusCode: 200,
      body: <String, dynamic>{
        'username': 'account',
        'created_at': '2026-03-08T09:00:00Z',
        'last_login_at': '2026-03-08T10:00:00Z',
      },
    );

    final account = await accountApi.getAccount();
    expect(account.username, 'account');
    expect(account.createdAt, DateTime.parse('2026-03-08T09:00:00Z'));
    expect(account.lastLoginAt, DateTime.parse('2026-03-08T10:00:00Z'));
    expect(adapter.requests.single.path, '/account');
    expect(adapter.requests.single.method, 'GET');
  });

  test('changePassword accepts 204 response', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/account/password',
      statusCode: 204,
    );

    await accountApi.changePassword(
      currentPassword: 'old-pwd',
      newPassword: 'new-pwd',
    );

    expect(adapter.requests.single.path, '/account/password');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.body, <String, dynamic>{
      'current_password': 'old-pwd',
      'new_password': 'new-pwd',
    });
  });

  test('getAccount maps user language', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      statusCode: 200,
      body: <String, dynamic>{
        'username': 'account',
        'language': 'en',
        'created_at': '2026-03-08T09:00:00Z',
        'last_login_at': '2026-03-08T10:00:00Z',
      },
    );

    final account = await accountApi.getAccount();

    expect(account.language, 'en');
  });

  test('updateLanguage patches account and maps response', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/account',
      statusCode: 200,
      body: <String, dynamic>{
        'username': 'account',
        'language': 'en',
        'created_at': '2026-03-08T09:00:00Z',
        'last_login_at': '2026-03-08T10:00:00Z',
      },
    );

    final account = await accountApi.updateLanguage('en');

    expect(account.language, 'en');
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/account');
    expect(adapter.requests.single.body, <String, dynamic>{'language': 'en'});
  });

  test('updateUsername converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/account',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'username_conflict',
          'message': 'Username exists',
        },
      },
    );

    expect(
      () => accountApi.updateUsername('duplicate'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'username_conflict',
        ),
      ),
    );
  });

  test('listApiKeys maps response list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/account/api-keys',
      body: <dynamic>[
        <String, dynamic>{
          'id': 3,
          'name': 'MCP server',
          'key_hint': 'sk-AbCd1234',
          'created_at': '2026-10-07T10:00:00',
          'last_used_at': null,
        },
        <String, dynamic>{
          'id': 2,
          'name': '',
          'key_hint': 'sk-ZzZz9999',
          'created_at': '2026-10-06T10:00:00',
          'last_used_at': '2026-10-07T11:00:00',
        },
      ],
    );

    final keys = await accountApi.listApiKeys();

    expect(keys, hasLength(2));
    expect(keys[0].id, 3);
    expect(keys[0].name, 'MCP server');
    expect(keys[0].keyHint, 'sk-AbCd1234');
    expect(keys[0].lastUsedAt, isNull);
    expect(keys[1].lastUsedAt, DateTime.parse('2026-10-07T11:00:00'));
  });

  test('createApiKey posts optional name and parses one-time secret', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/account/api-keys',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 9,
        'name': 'MCP',
        'key_hint': 'sk-AbCd1234',
        'created_at': '2026-10-07T10:00:00',
        'last_used_at': null,
        'key': 'sk-AbCd1234EfGh5678',
      },
    );

    final created = await accountApi.createApiKey(name: 'MCP');

    expect(created.id, 9);
    expect(created.key, 'sk-AbCd1234EfGh5678');
    expect(adapter.requests.single.body, <String, dynamic>{'name': 'MCP'});
  });

  test('deleteApiKey accepts 204 response', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/account/api-keys/9',
      statusCode: 204,
    );

    await accountApi.deleteApiKey(9);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/account/api-keys/9');
  });
}
