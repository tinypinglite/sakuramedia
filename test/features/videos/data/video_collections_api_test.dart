import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late VideoCollectionsApi collectionsApi;
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
    collectionsApi = VideoCollectionsApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getCollectionItems 解析 position 与内嵌视频概要', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: <dynamic>[
        <String, dynamic>{
          'item_id': 100,
          'position': 0,
          'video': <String, dynamic>{
            'id': 1,
            'title': '第一段',
            'media_count': 1,
            'can_play': true,
            'created_at': '2026-01-02T03:04:05',
            'updated_at': '2026-01-02T03:04:05',
          },
        },
        <String, dynamic>{
          'item_id': 101,
          'position': 1,
          'video': <String, dynamic>{
            'id': 2,
            'title': '第二段',
            'media_count': 1,
            'can_play': true,
            'created_at': '2026-01-02T03:04:05',
            'updated_at': '2026-01-02T03:04:05',
          },
        },
      ],
    );

    final items = await collectionsApi.getCollectionItems(collectionId: 3);

    expect(items, hasLength(2));
    expect(items.first.itemId, 100);
    expect(items.first.position, 0);
    expect(items.first.video.title, '第一段');
    expect(items.last.video.id, 2);
  });

  test('reorderCollectionItems 以有序 item_id 列表 POST', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-collections/3/items/reorder',
      // 端点返回成员列表，但前端走乐观重排、不消费返回体。
      body: <dynamic>[],
    );

    await collectionsApi.reorderCollectionItems(
      collectionId: 3,
      orderedItemIds: <int>[101, 100],
    );

    final body = adapter.requests.single.body as Map<String, dynamic>;
    expect(body['ordered_item_ids'], <int>[101, 100]);
  });
}
