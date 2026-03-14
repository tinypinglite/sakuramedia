import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late AuthApi authApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    apiClient = ApiClient(sessionStore: sessionStore);
    authApi = AuthApi(apiClient: apiClient, sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('createToken sends request body and persists tokens', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/auth/tokens',
      statusCode: 200,
      body: <String, dynamic>{
        'access_token': 'access-1',
        'refresh_token': 'refresh-1',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': '2026-03-08T11:00:00Z',
        'refresh_expires_at': '2026-03-15T11:00:00Z',
        'user': <String, dynamic>{'username': 'account'},
      },
    );

    final dto = await authApi.createToken(username: 'account', password: 'pwd');

    expect(dto.accessToken, 'access-1');
    expect(dto.refreshToken, 'refresh-1');
    expect(sessionStore.accessToken, 'access-1');
    expect(sessionStore.refreshToken, 'refresh-1');
    expect(adapter.requests.length, 1);
    expect(adapter.requests.first.path, '/auth/tokens');
    expect(adapter.requests.first.method, 'POST');
    expect(adapter.requests.first.body, <String, dynamic>{
      'username': 'account',
      'password': 'pwd',
    });
    expect(adapter.requests.first.headers['Authorization'], isNull);
  });

  test('createToken converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/auth/tokens',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_credentials',
          'message': '用户名或密码错误',
        },
      },
    );

    expect(
      () => authApi.createToken(username: 'account', password: 'wrong'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'invalid_credentials',
        ),
      ),
    );
  });
}
