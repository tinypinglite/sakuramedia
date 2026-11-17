import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';

import '../../../../support/fake_http_client_adapter.dart';

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
      path: '/video-collections/3/videos',
      body: <String, dynamic>{
        'page': 1,
        'page_size': 100,
        'total': 2,
        'items': <dynamic>[
          <String, dynamic>{
            'position': 0,
            'play_url': '/media/9/play/?expires=1777777777&signature=abc',
            'first_media_id': 9,
            'play_provider_key': 'cloud115',
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
    expect(result.items.first.video.id, 1);
    expect(result.items.first.position, 0);
    expect(result.items.first.video.title, '第一段');
    expect(
      result.items.first.playUrl,
      '/media/9/play/?expires=1777777777&signature=abc',
    );
    expect(result.items.first.firstMediaId, 9);
    expect(result.items.first.playProviderKey, 'cloud115');
    expect(result.items.last.video.id, 2);
    // 后端未内联（无媒体）的成员 playUrl / firstMediaId / provider 为 null。
    expect(result.items.last.playUrl, isNull);
    expect(result.items.last.firstMediaId, isNull);
    expect(result.items.last.playProviderKey, isNull);

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
        'items':
            ids
                .map(
                  (id) => <String, dynamic>{
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
      path: '/video-collections/7/videos',
      body: pageBody(1, <int>[0, 1], 3),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/7/videos',
      body: pageBody(2, <int>[2], 3),
    );

    final items = await collectionsApi.getAllCollectionItems(
      collectionId: 7,
      pageSize: 2,
    );

    expect(items, hasLength(3));
    expect(items.map((it) => it.video.id), <int>[0, 1, 2]);
    // 翻了两页直至取满 total。
    expect(adapter.hitCount('GET', '/video-collections/7/videos'), 2);
  });

  test('addVideoToCollection 以视频 id 幂等加入合集', () async {
    adapter.enqueueJson(
      method: 'PUT',
      path: '/video-collections/3/videos/101',
      statusCode: 204,
    );

    await collectionsApi.addVideoToCollection(
      collectionId: 3,
      videoItemId: 101,
    );

    expect(adapter.requests.single.method, 'PUT');
    expect(
      adapter.requests.single.uri.path,
      '/video-collections/3/videos/101',
    );
  });

  test('removeVideoFromCollection 按视频 id 移出合集', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/video-collections/3/videos/101',
      statusCode: 204,
    );

    await collectionsApi.removeVideoFromCollection(
      collectionId: 3,
      videoItemId: 101,
    );

    expect(adapter.requests.single.method, 'DELETE');
    expect(
      adapter.requests.single.uri.path,
      '/video-collections/3/videos/101',
    );
  });
}
