import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/announcements/data/announcements_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-11-12T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() => apiClient.dispose());

  test('parses announcement items and skips malformed entries', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/announcements',
      body: <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 'notice-1',
            'level': 'warning',
            'title_i18n': <String, dynamic>{'zh-CN': '标题', 'en': 'Title'},
            'body_i18n': <String, dynamic>{'zh-CN': '正文', 'en': 'Body'},
            'published_at': '2026-11-12T08:00:00Z',
          },
          <String, dynamic>{'id': 'broken'},
        ],
      },
    );

    final items = await AnnouncementsApi(
      apiClient: apiClient,
    ).getAnnouncements();

    expect(items, hasLength(1));
    expect(items.single.id, 'notice-1');
    expect(items.single.titleI18n['en'], 'Title');
  });

  test('returns an empty list when items is not a list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/announcements',
      body: const <String, dynamic>{'items': null},
    );

    final items = await AnnouncementsApi(
      apiClient: apiClient,
    ).getAnnouncements();

    expect(items, isEmpty);
  });
}
