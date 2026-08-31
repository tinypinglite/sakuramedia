import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionBody() => <String, dynamic>{
  'id': 3,
  'name': '连播合集',
  'description': '',
  'item_count': 2,
  'created_at': '2026-01-02T03:04:05',
  'updated_at': '2026-01-02T03:04:05',
};

// 成员端点已分页：返回 {items, page, page_size, total} 信封。两条成员、total=2，
// getAllCollectionItems 一次请求即取满（不再翻页）。
Map<String, dynamic> _itemsBody() => <String, dynamic>{
  'page': 1,
  'page_size': 100,
  'total': 2,
  'items': <dynamic>[
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
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        videoCollectionsApiProvider.overrideWithValue(
          VideoCollectionsApi(apiClient: apiClient),
        ),
        videosApiProvider.overrideWithValue(VideosApi(apiClient: apiClient)),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void keepAlive() {
    // autoDispose family：挂监听者保活，避免两次 read 之间被释放重建。
    final subscription = container.listen(
      videoCollectionDetailProvider(3),
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  void enqueueLoad() {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3',
      body: _collectionBody(),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: _itemsBody(),
    );
  }

  test('reorder 乐观更新本地顺序并以新顺序 POST', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'POST',
      path: '/video-collections/3/items/reorder',
      body: <dynamic>[],
    );

    keepAlive();
    final state = await container.read(videoCollectionDetailProvider(3).future);
    expect(state.items.map((item) => item.video.id).toList(), <int>[1, 2]);

    // 把第二个成员拖到最前。
    await container
        .read(videoCollectionDetailProvider(3).notifier)
        .reorder(1, 0);

    final next = container.read(videoCollectionDetailProvider(3)).requireValue;
    expect(next.items.map((item) => item.video.id).toList(), <int>[2, 1]);
    final reorderRequest = adapter.requests.last;
    expect(reorderRequest.path, '/video-collections/3/items/reorder');
    final body = reorderRequest.body as Map<String, dynamic>;
    expect(body['ordered_item_ids'], <int>[101, 100]);
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

    keepAlive();
    await container.read(videoCollectionDetailProvider(3).future);

    await container
        .read(videoCollectionDetailProvider(3).notifier)
        .reorder(1, 0);

    // 失败回滚到提交前顺序 [1, 2]，不再触发重载。
    final state = container.read(videoCollectionDetailProvider(3)).requireValue;
    expect(state.items.map((item) => item.video.id).toList(), <int>[1, 2]);
  });

  test('removeItem 成功：乐观移除并返回 null', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/video-collections/3/items/100',
      statusCode: 204,
      body: const <String, dynamic>{},
    );

    keepAlive();
    await container.read(videoCollectionDetailProvider(3).future);

    final error = await container
        .read(videoCollectionDetailProvider(3).notifier)
        .removeItem(100);

    expect(error, isNull);
    final state = container.read(videoCollectionDetailProvider(3)).requireValue;
    expect(state.items.map((item) => item.itemId).toList(), <int>[101]);
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

    keepAlive();
    await container.read(videoCollectionDetailProvider(3).future);

    final error = await container
        .read(videoCollectionDetailProvider(3).notifier)
        .removeItem(100);

    expect(error, isNotNull);
    final state = container.read(videoCollectionDetailProvider(3)).requireValue;
    // 失败回滚，成员仍在。
    expect(state.items.map((item) => item.itemId).toList(), <int>[100, 101]);
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

    keepAlive();
    await container.read(videoCollectionDetailProvider(3).future);

    final error = await container
        .read(videoCollectionDetailProvider(3).notifier)
        .deleteVideo(100, 1);

    expect(error, isNull);
    final state = container.read(videoCollectionDetailProvider(3)).requireValue;
    expect(state.items.map((item) => item.itemId).toList(), <int>[101]);
    expect(adapter.requests.last.path, '/videos/1');
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

    keepAlive();
    await container.read(videoCollectionDetailProvider(3).future);

    final error = await container
        .read(videoCollectionDetailProvider(3).notifier)
        .deleteVideo(100, 1);

    expect(error, isNotNull);
    final state = container.read(videoCollectionDetailProvider(3)).requireValue;
    // 失败回滚，成员仍在。
    expect(state.items.map((item) => item.itemId).toList(), <int>[100, 101]);
  });

  test('默认手动顺序：build 不带 sort 参数', () async {
    enqueueLoad();

    keepAlive();
    final state = await container.read(videoCollectionDetailProvider(3).future);

    expect(state.sort.isManual, isTrue);
    expect(state.sort.field, isNull);
    expect(state.sort.apiValue, isNull);
    final itemsRequest = adapter.requests.firstWhere(
      (request) => request.path == '/video-collections/3/items',
    );
    expect(itemsRequest.uri.queryParameters.containsKey('sort'), isFalse);
  });

  test('applySort 切到非手动字段：带 sort 查询且退出手动顺序', () async {
    enqueueLoad();
    // 切到「时长降序」后按新排序重拉成员。
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: _itemsBody(),
    );

    keepAlive();
    await container.read(videoCollectionDetailProvider(3).future);

    final update = container
        .read(videoCollectionDetailProvider(3).notifier)
        .applySort(
          field: VideoSortField.duration,
          direction: SortDirection.desc,
        );

    final pending = container
        .read(videoCollectionDetailProvider(3))
        .requireValue;
    expect(pending.sort.field, VideoSortField.duration);
    expect(pending.sort.direction, SortDirection.desc);
    expect(pending.filterUpdate.isLoading, isTrue);
    expect(pending.items, isNotEmpty);
    expect(adapter.hitCount('GET', '/video-collections/3/items'), 1);

    await update;

    final state = container.read(videoCollectionDetailProvider(3)).requireValue;
    expect(state.sort.isManual, isFalse);
    expect(state.sort.field, VideoSortField.duration);
    expect(state.sort.direction, SortDirection.desc);
    // 「播放全部」透传给连播页的排序表达式，与拉取成员时使用的一致。
    expect(state.sort.apiValue, 'duration:desc');
    expect(adapter.requests.last.uri.queryParameters['sort'], 'duration:desc');
  });

  test('applySort 切回手动顺序：去掉 sort 查询并恢复手动顺序', () async {
    enqueueLoad();
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: _itemsBody(),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/3/items',
      body: _itemsBody(),
    );

    keepAlive();
    await container.read(videoCollectionDetailProvider(3).future);
    await container
        .read(videoCollectionDetailProvider(3).notifier)
        .applySort(field: VideoSortField.title);
    expect(
      container
          .read(videoCollectionDetailProvider(3))
          .requireValue
          .sort
          .isManual,
      isFalse,
    );

    await container
        .read(videoCollectionDetailProvider(3).notifier)
        .applySort(field: null);

    final state = container.read(videoCollectionDetailProvider(3)).requireValue;
    expect(state.sort.isManual, isTrue);
    expect(state.sort.apiValue, isNull);
    // 最后一次拉取不带 sort（手动顺序）。
    expect(
      adapter.requests.last.uri.queryParameters.containsKey('sort'),
      isFalse,
    );
  });
}
