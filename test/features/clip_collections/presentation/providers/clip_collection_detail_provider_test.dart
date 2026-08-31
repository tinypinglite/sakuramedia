import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionJson({int clipCount = 3}) => <String, dynamic>{
      'id': 7,
      'name': '精选合集',
      'description': '',
      'clip_count': clipCount,
      'cover_image': null,
      'created_at': '2026-06-13T10:00:00Z',
      'updated_at': '2026-06-13T11:00:00Z',
    };

Map<String, dynamic> _itemJson(int clipId, int position) => <String, dynamic>{
      'clip_id': clipId,
      'media_id': 1,
      'movie_number': 'ABC-001',
      'start_offset_seconds': 0,
      'end_offset_seconds': 10,
      'title': '片段$clipId',
      'duration_seconds': 10,
      'file_size_bytes': 1024,
      'cover_image': null,
      'stream_url': '/media-clips/$clipId/stream',
      'created_at': '2026-06-13T10:00:00Z',
      'position': position,
    };

void main() {
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
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        clipCollectionsApiProvider.overrideWithValue(
          ClipCollectionsApi(apiClient: apiClient),
        ),
        clipsApiProvider.overrideWithValue(ClipsApi(apiClient: apiClient)),
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
      clipCollectionDetailProvider(7),
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  void enqueueLoad({int clipCount = 3}) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7',
      body: _collectionJson(clipCount: clipCount),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7/clips',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _itemJson(10, 0),
          _itemJson(11, 1),
          _itemJson(12, 2),
        ],
        'page': 1,
        'page_size': 50,
        'total': 3,
      },
    );
  }

  test('build fetches collection meta and all clips in order', () async {
    enqueueLoad();

    keepAlive();
    final state = await container.read(
      clipCollectionDetailProvider(7).future,
    );

    expect(state.collection.name, '精选合集');
    expect(state.clips.map((clip) => clip.clipId).toList(), <int>[10, 11, 12]);
  });

  test('reorder moves item and PUTs full ordered ids', () async {
    enqueueLoad();

    keepAlive();
    await container.read(clipCollectionDetailProvider(7).future);

    adapter.enqueueJson(
      method: 'PUT',
      path: '/clip-collections/7/clips',
      statusCode: 204,
    );

    // 把首个片段拖到末尾之前：ReorderableListView 语义 (0 -> 2) => [11, 10, 12]
    final error = await container
        .read(clipCollectionDetailProvider(7).notifier)
        .reorder(0, 2);

    expect(error, isNull);
    final state = container.read(clipCollectionDetailProvider(7)).requireValue;
    expect(state.clips.map((clip) => clip.clipId).toList(), <int>[11, 10, 12]);
    expect(adapter.requests.last.body, <String, dynamic>{
      'clip_ids': <int>[11, 10, 12],
    });
  });

  test('reorder rolls back on failure', () async {
    enqueueLoad();

    keepAlive();
    await container.read(clipCollectionDetailProvider(7).future);

    adapter.enqueueJson(
      method: 'PUT',
      path: '/clip-collections/7/clips',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    final error = await container
        .read(clipCollectionDetailProvider(7).notifier)
        .reorder(0, 2);

    expect(error, isNotNull);
    final state = container.read(clipCollectionDetailProvider(7)).requireValue;
    expect(state.clips.map((clip) => clip.clipId).toList(), <int>[10, 11, 12]);
  });

  test('removeClip optimistically drops then confirms', () async {
    enqueueLoad();

    keepAlive();
    await container.read(clipCollectionDetailProvider(7).future);

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/clip-collections/7/clips/11',
      statusCode: 204,
    );

    final error = await container
        .read(clipCollectionDetailProvider(7).notifier)
        .removeClip(11);

    expect(error, isNull);
    final state = container.read(clipCollectionDetailProvider(7)).requireValue;
    expect(state.clips.map((clip) => clip.clipId).toList(), <int>[10, 12]);
    expect(state.collection.clipCount, 2);
  });

  test(
    'deleteClip optimistically drops then confirms via media-clips DELETE',
    () async {
      enqueueLoad();

      keepAlive();
      await container.read(clipCollectionDetailProvider(7).future);

      adapter.enqueueJson(
        method: 'DELETE',
        path: '/media-clips/11',
        statusCode: 204,
      );

      final error = await container
          .read(clipCollectionDetailProvider(7).notifier)
          .deleteClip(11);

      expect(error, isNull);
      final state =
          container.read(clipCollectionDetailProvider(7)).requireValue;
      expect(state.clips.map((clip) => clip.clipId).toList(), <int>[10, 12]);
      expect(state.collection.clipCount, 2);
    },
  );

  test('deleteClip rolls back on failure', () async {
    enqueueLoad();

    keepAlive();
    await container.read(clipCollectionDetailProvider(7).future);

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-clips/11',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    final error = await container
        .read(clipCollectionDetailProvider(7).notifier)
        .deleteClip(11);

    expect(error, isNotNull);
    final state = container.read(clipCollectionDetailProvider(7)).requireValue;
    expect(state.clips.map((clip) => clip.clipId).toList(), <int>[10, 11, 12]);
    // 回滚同时把 clipCount 恢复到 3（不是 2）。
    expect(state.collection.clipCount, 3);
  });

  test('applyCollectionMeta updates name but preserves current count',
      () async {
    enqueueLoad(clipCount: 3);

    keepAlive();
    await container.read(clipCollectionDetailProvider(7).future);

    // Simulate an edit response arriving with a stale count (e.g. 999)—
    // provider should preserve the local clip.length (3).
    container.read(clipCollectionDetailProvider(7).notifier).applyCollectionMeta(
          ClipCollectionDto.fromJson(
            _collectionJson(clipCount: 999)..['name'] = '改名后',
          ),
        );

    final state = container.read(clipCollectionDetailProvider(7)).requireValue;
    expect(state.collection.name, '改名后');
    expect(state.collection.clipCount, 3);
  });

  test('refresh reloads collection meta and clips', () async {
    enqueueLoad();

    keepAlive();
    await container.read(clipCollectionDetailProvider(7).future);

    // Second load returns a shrinked list.
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7',
      body: _collectionJson(clipCount: 1),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7/clips',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_itemJson(20, 0)],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
    );

    await container
        .read(clipCollectionDetailProvider(7).notifier)
        .refresh();

    final state = container.read(clipCollectionDetailProvider(7)).requireValue;
    expect(state.clips.map((c) => c.clipId).toList(), <int>[20]);
    expect(state.collection.clipCount, 1);
  });
}

