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
}
