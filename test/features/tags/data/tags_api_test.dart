import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late TagsApi tagsApi;
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
    tagsApi = TagsApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getTags sends default sort and parses tag list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/tags',
      statusCode: 200,
      body: <Map<String, dynamic>>[
        <String, dynamic>{'tag_id': 5, 'name': '巨乳', 'movie_count': 1280},
        <String, dynamic>{'tag_id': 8, 'name': '单体作品', 'movie_count': 940},
      ],
    );

    final tags = await tagsApi.getTags();

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/tags');
    expect(request.uri.queryParameters['sort'], 'movie_count:desc');
    expect(request.uri.queryParameters.containsKey('query'), isFalse);
    expect(tags, hasLength(2));
    expect(tags.first.tagId, 5);
    expect(tags.first.name, '巨乳');
    expect(tags.first.movieCount, 1280);
  });

  test('getTags sends trimmed query and custom sort when provided', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/tags',
      statusCode: 200,
      body: const <Map<String, dynamic>>[],
    );

    await tagsApi.getTags(query: '  巨乳  ', sort: 'name:asc');

    final request = adapter.requests.single;
    expect(request.uri.queryParameters['query'], '巨乳');
    expect(request.uri.queryParameters['sort'], 'name:asc');
  });

  test('getTags omits blank query', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/tags',
      statusCode: 200,
      body: const <Map<String, dynamic>>[],
    );

    await tagsApi.getTags(query: '   ');

    final request = adapter.requests.single;
    expect(request.uri.queryParameters.containsKey('query'), isFalse);
  });

  test('getTags converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/tags',
      statusCode: 422,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_tag_filter',
          'message': '非法筛选',
        },
      },
    );

    expect(
      () => tagsApi.getTags(sort: 'bad:order'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'invalid_tag_filter',
        ),
      ),
    );
  });
}
