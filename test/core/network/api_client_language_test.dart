import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import '../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late String language;

  setUp(() async {
    language = 'zh-CN';
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    apiClient = ApiClient(
      sessionStore: sessionStore,
      languageProvider: () => language,
    );
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('normal requests read the current language on every call', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      body: <String, dynamic>{'username': 'account'},
    );
    await apiClient.get('/account');
    expect(adapter.requests.last.headers['Accept-Language'], 'zh-CN');

    language = 'en';
    adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      body: <String, dynamic>{'username': 'account'},
    );
    await apiClient.get('/account');
    expect(adapter.requests.last.headers['Accept-Language'], 'en');
  });

  test('SSE and rawDio requests carry the language header', () async {
    language = 'en';
    adapter.enqueueSse(
      method: 'POST',
      path: '/movies/metadata-imports',
      chunks: <String>['event: completed\ndata: {}\n\n'],
    );
    await apiClient
        .postSse(
          '/movies/metadata-imports',
          data: <String, dynamic>{'movie_number': 'ABP-123'},
        )
        .toList();
    expect(adapter.requests.last.headers['Accept-Language'], 'en');

    adapter.enqueueJson(
      method: 'GET',
      path: '/healthz',
      body: <String, dynamic>{'status': 'ok'},
    );
    await apiClient.rawDio.get<dynamic>('/healthz');
    expect(adapter.requests.last.headers['Accept-Language'], 'en');
  });
}
