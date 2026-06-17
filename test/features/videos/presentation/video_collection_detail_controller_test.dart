import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/video_collection_detail_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_filter_state.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late VideoCollectionsApi collectionsApi;
  late VideosApi videosApi;
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
    videosApi = VideosApi(apiClient: apiClient);
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
      videosApi: videosApi,
    );
    await controller.load();
    expect(
      controller.items.map((item) => item.video.id).toList(),
      <int>[1, 2],
    );

    // 把第二个成员拖到最前。
    await controller.reorder(1, 0);

    expect(
      controller.items.map((item) => item.video.id).toList(),
      <int>[2, 1],
    );
    final reorderRequest = adapter.requests.last;
    expect(reorderRequest.path, '/video-collections/3/items/reorder');
    final body = reorderRequest.body as Map<String, dynamic>;
    expect(body['ordered_item_ids'], <int>[101, 100]);

    controller.dispose();
  });

  test('reorder 失败时回滚为提交前的本地顺序', () async {
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

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();

    await controller.reorder(1, 0);

    // 失败回滚到提交前顺序 [1, 2]，不再触发重载。
    expect(
      controller.items.map((item) => item.video.id).toList(),
      <int>[1, 2],
    );
    expect(controller.isMutating, isFalse);

    controller.dispose();
  });

  test('removeItem 成功：乐观移除并返回 null', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/video-collections/3/items/100',
      statusCode: 204,
      body: const <String, dynamic>{},
    );

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();

    final error = await controller.removeItem(100);

    expect(error, isNull);
    expect(
      controller.items.map((item) => item.itemId).toList(),
      <int>[101],
    );
    expect(controller.isMutating, isFalse);

    controller.dispose();
  });

  test('removeItem 失败：回滚并返回错误消息', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/video-collections/3/items/100',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();

    final error = await controller.removeItem(100);

    expect(error, isNotNull);
    // 失败回滚，成员仍在。
    expect(
      controller.items.map((item) => item.itemId).toList(),
      <int>[100, 101],
    );
    expect(controller.isMutating, isFalse);

    controller.dispose();
  });

  test('deleteVideo 成功：乐观移除该成员并返回 null', () async {
    enqueueLoad();
    // 删除的是视频本体（itemId 100 对应 video.id 1）。
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/videos/1',
      statusCode: 204,
      body: const <String, dynamic>{},
    );

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();

    final error = await controller.deleteVideo(100, 1);

    expect(error, isNull);
    expect(
      controller.items.map((item) => item.itemId).toList(),
      <int>[101],
    );
    expect(adapter.requests.last.path, '/videos/1');
    expect(controller.isMutating, isFalse);

    controller.dispose();
  });

  test('deleteVideo 失败：回滚并返回错误消息', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/videos/1',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();

    final error = await controller.deleteVideo(100, 1);

    expect(error, isNotNull);
    // 失败回滚，成员仍在。
    expect(
      controller.items.map((item) => item.itemId).toList(),
      <int>[100, 101],
    );
    expect(controller.isMutating, isFalse);

    controller.dispose();
  });

  test('默认手动顺序：load 不带 sort 参数', () async {
    enqueueLoad();

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();

    expect(controller.isManualOrder, isTrue);
    expect(controller.sortField, isNull);
    // 手动顺序下排序表达式为 null，「播放全部」据此不附加 sort（连播沿用 position:asc）。
    expect(controller.sortExpression, isNull);
    final itemsRequest = adapter.requests.firstWhere(
      (request) => request.path == '/video-collections/3/items',
    );
    expect(itemsRequest.uri.queryParameters.containsKey('sort'), isFalse);

    controller.dispose();
  });

  test('applySort 切到非手动字段：带 sort 查询且退出手动顺序', () async {
    enqueueLoad();
    // 切到「时长降序」后按新排序重拉成员。
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: itemsBody(),
    );

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();

    await controller.applySort(
      field: VideoSortField.duration,
      direction: SortDirection.desc,
    );

    expect(controller.isManualOrder, isFalse);
    expect(controller.sortField, VideoSortField.duration);
    expect(controller.sortDirection, SortDirection.desc);
    // 「播放全部」透传给连播页的排序表达式，与拉取成员时使用的一致。
    expect(controller.sortExpression, 'duration:desc');
    expect(
      adapter.requests.last.uri.queryParameters['sort'],
      'duration:desc',
    );

    controller.dispose();
  });

  test('applySort 切回手动顺序：去掉 sort 查询并恢复手动顺序', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: itemsBody(),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: itemsBody(),
    );

    final controller = VideoCollectionDetailController(
      collectionId: 3,
      collectionsApi: collectionsApi,
      videosApi: videosApi,
    );
    await controller.load();
    await controller.applySort(field: VideoSortField.title);
    expect(controller.isManualOrder, isFalse);

    await controller.applySort(field: null);

    expect(controller.isManualOrder, isTrue);
    expect(controller.sortField, isNull);
    expect(
      adapter.requests.last.uri.queryParameters.containsKey('sort'),
      isFalse,
    );

    controller.dispose();
  });
}
