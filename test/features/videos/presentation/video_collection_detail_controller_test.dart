import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/video_collection_detail_controller.dart';

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

  Map<String, dynamic> collectionBody() => <String, dynamic>{
    'id': 3,
    'name': '连播合集',
    'description': '',
    'item_count': 2,
    'created_at': '2026-01-02T03:04:05',
    'updated_at': '2026-01-02T03:04:05',
  };

  List<dynamic> itemsBody() => <dynamic>[
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
  ];

  void enqueueLoad() {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3',
      body: collectionBody(),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: itemsBody(),
    );
  }

  test('reorder 乐观更新本地顺序并以新顺序 POST', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-collections/3/items/reorder',
      body: <dynamic>[],
    );

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
    );
    await controller.load();
    expect(controller.orderedVideoIds, <int>[1, 2]);

    // 把第二个成员拖到最前。
    await controller.reorder(1, 0);

    expect(controller.orderedVideoIds, <int>[2, 1]);
    final reorderRequest = adapter.requests.last;
    expect(reorderRequest.path, '/video-collections/3/items/reorder');
    final body = reorderRequest.body as Map<String, dynamic>;
    expect(body['ordered_item_ids'], <int>[101, 100]);

    controller.dispose();
  });

  test('reorder 失败时回滚为服务端顺序', () async {
    enqueueLoad();
    // reorder 失败（500）。
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-collections/3/items/reorder',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );
    // 失败后控制器重载，回到服务端真实顺序。
    enqueueLoad();

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
    );
    await controller.load();

    await controller.reorder(1, 0);

    // 重载后顺序回到服务端的 [1, 2]。
    expect(controller.orderedVideoIds, <int>[1, 2]);

    controller.dispose();
  });
}
