import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collection_detail_controller.dart';

import '../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionJson() => <String, dynamic>{
  'id': 7,
  'name': '精选合集',
  'description': '',
  'clip_count': 3,
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
  late ClipCollectionsApi api;

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
    api = ClipCollectionsApi(apiClient: apiClient);
  });

  tearDown(() => apiClient.dispose());

  void enqueueLoad() {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7',
      body: _collectionJson(),
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

  test('load fetches collection meta and all clips in order', () async {
    enqueueLoad();
    final controller = ClipCollectionDetailController(collectionId: 7, api: api);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.collection?.name, '精选合集');
    expect(
      controller.clips.map((clip) => clip.clipId).toList(),
      <int>[10, 11, 12],
    );
  });

  test('reorder moves item and PUTs full ordered ids', () async {
    enqueueLoad();
    final controller = ClipCollectionDetailController(collectionId: 7, api: api);
    addTearDown(controller.dispose);
    await controller.load();

    adapter.enqueueJson(
      method: 'PUT',
      path: '/clip-collections/7/clips',
      statusCode: 204,
    );

    // 把首个片段拖到末尾之前：ReorderableListView 语义 (0 -> 2) => [11, 10, 12]
    final error = await controller.reorder(0, 2);

    expect(error, isNull);
    expect(
      controller.clips.map((clip) => clip.clipId).toList(),
      <int>[11, 10, 12],
    );
    expect(adapter.requests.last.body, <String, dynamic>{
      'clip_ids': <int>[11, 10, 12],
    });
  });

  test('reorder rolls back on failure', () async {
    enqueueLoad();
    final controller = ClipCollectionDetailController(collectionId: 7, api: api);
    addTearDown(controller.dispose);
    await controller.load();

    adapter.enqueueJson(
      method: 'PUT',
      path: '/clip-collections/7/clips',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    final error = await controller.reorder(0, 2);

    expect(error, isNotNull);
    expect(
      controller.clips.map((clip) => clip.clipId).toList(),
      <int>[10, 11, 12],
    );
  });

  test('removeClip optimistically drops then confirms', () async {
    enqueueLoad();
    final controller = ClipCollectionDetailController(collectionId: 7, api: api);
    addTearDown(controller.dispose);
    await controller.load();

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/clip-collections/7/clips/11',
      statusCode: 204,
    );

    final error = await controller.removeClip(11);

    expect(error, isNull);
    expect(
      controller.clips.map((clip) => clip.clipId).toList(),
      <int>[10, 12],
    );
    expect(controller.collection?.clipCount, 2);
  });
}
