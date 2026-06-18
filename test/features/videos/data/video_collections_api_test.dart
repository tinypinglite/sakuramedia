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

  test('getCollectionItems 分页解析 position/内嵌视频/playUrl 并拼分页参数', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: <String, dynamic>{
        'page': 1,
        'page_size': 100,
        'total': 2,
        'items': <dynamic>[
          <String, dynamic>{
            'item_id': 100,
            'position': 0,
            'play_url': '/media/9/stream?sig=a',
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
      },
    );

    final result = await collectionsApi.getCollectionItems(
      collectionId: 3,
      includePlayUrl: true,
    );

    expect(result.items, hasLength(2));
    expect(result.total, 2);
    expect(result.items.first.itemId, 100);
    expect(result.items.first.position, 0);
    expect(result.items.first.video.title, '第一段');
    expect(result.items.first.playUrl, '/media/9/stream?sig=a');
    expect(result.items.last.video.id, 2);
    // 后端未内联（无媒体）的成员 playUrl 为 null。
    expect(result.items.last.playUrl, isNull);

    // 分页与 include_play_url 查询参数正确下发。
    final query = adapter.requests.single.uri.queryParameters;
    expect(query['page'], '1');
    expect(query['page_size'], '100');
    expect(query['include_play_url'], 'true');
  });

  test('getAllCollectionItems 循环翻页拉全部成员', () async {
    Map<String, dynamic> pageBody(int page, List<int> ids, int total) {
      return <String, dynamic>{
        'page': page,
        'page_size': 2,
        'total': total,
        'items': ids
            .map(
              (id) => <String, dynamic>{
                'item_id': id + 100,
                'position': id,
                'video': <String, dynamic>{
                  'id': id,
                  'title': '片$id',
                  'media_count': 1,
                  'can_play': true,
                  'created_at': '2026-01-02T03:04:05',
                  'updated_at': '2026-01-02T03:04:05',
                },
              },
            )
            .toList(),
      };
    }

    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/7/items',
      body: pageBody(1, <int>[0, 1], 3),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/7/items',
      body: pageBody(2, <int>[2], 3),
    );

    final items = await collectionsApi.getAllCollectionItems(
      collectionId: 7,
      pageSize: 2,
    );

    expect(items, hasLength(3));
    expect(items.map((it) => it.video.id), <int>[0, 1, 2]);
    // 翻了两页直至取满 total。
    expect(adapter.hitCount('GET', '/video-collections/7/items'), 2);
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
