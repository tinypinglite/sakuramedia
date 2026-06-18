import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';

import '../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionJson({int id = 7, String name = '精选合集'}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'description': '我的精选',
      'clip_count': 3,
      'cover_image': <String, dynamic>{
        'id': 1,
        'origin': '/clips/cover-origin.webp',
        'small': '/clips/cover-small.webp',
        'medium': '/clips/cover-medium.webp',
        'large': '/clips/cover-large.webp',
      },
      'created_at': '2026-06-13T10:00:00Z',
      'updated_at': '2026-06-13T11:00:00Z',
    };

Map<String, dynamic> _clipItemJson({int clipId = 12, int position = 0}) =>
    <String, dynamic>{
      'clip_id': clipId,
      'media_id': 34,
      'movie_number': 'ABC-001',
      'start_offset_seconds': 10,
      'end_offset_seconds': 30,
      'title': '片段$clipId',
      'duration_seconds': 20,
      'file_size_bytes': 1048576,
      'cover_image': null,
      'stream_url': '/media-clips/$clipId/stream?expires=1&signature=abc',
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

  tearDown(() {
    apiClient.dispose();
  });

  test('getCollections maps GET /clip-collections', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: <Map<String, dynamic>>[
        _collectionJson(),
        _collectionJson(id: 8, name: '其它'),
      ],
    );

    final collections = await api.getCollections();

    expect(collections, hasLength(2));
    expect(collections.first.id, 7);
    expect(collections.first.name, '精选合集');
    expect(collections.first.clipCount, 3);
    expect(collections.first.coverImage?.bestAvailableUrl, '/clips/cover-large.webp');
  });

  test('createCollection posts trimmed name and description', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/clip-collections',
      statusCode: 201,
      body: _collectionJson(),
    );

    final created = await api.createCollection(name: ' 精选合集 ', description: ' 我的精选 ');

    expect(created.id, 7);
    expect(adapter.requests.single.body, <String, dynamic>{
      'name': '精选合集',
      'description': '我的精选',
    });
  });

  test('updateCollection patches only provided fields', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/clip-collections/7',
      body: _collectionJson(name: '新名字'),
    );

    final updated = await api.updateCollection(
      collectionId: 7,
      payload: const UpdateClipCollectionPayload(name: '新名字'),
    );

    expect(updated.name, '新名字');
    expect(adapter.requests.single.body, <String, dynamic>{'name': '新名字'});
  });

  test('deleteCollection maps DELETE /clip-collections/{id}', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/clip-collections/7',
      statusCode: 204,
    );

    await api.deleteCollection(collectionId: 7);

    expect(adapter.hitCount('DELETE', '/clip-collections/7'), 1);
  });

  test('getCollectionClips maps paginated items with position', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7/clips',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _clipItemJson(clipId: 12, position: 0),
          _clipItemJson(clipId: 13, position: 1),
        ],
        'page': 1,
        'page_size': 20,
        'total': 2,
      },
    );

    final page = await api.getCollectionClips(collectionId: 7);

    expect(page.items, hasLength(2));
    expect(page.items.first.clip.clipId, 12);
    expect(page.items.first.position, 0);
    expect(page.items.last.position, 1);
    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'page': '1',
      'page_size': '20',
    });
  });

  test('getAllCollectionClips 并发翻页拉全部并保序', () async {
    Map<String, dynamic> pageBody(int page, List<int> clipIds, int total) {
      return <String, dynamic>{
        'page': page,
        'page_size': 2,
        'total': total,
        'items': <Map<String, dynamic>>[
          for (var i = 0; i < clipIds.length; i++)
            _clipItemJson(clipId: clipIds[i], position: (page - 1) * 2 + i),
        ],
      };
    }

    // total=5 → 3 页（pageSize 2）；第 2/3 页落在同一并发批次，需保持页序拼接。
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7/clips',
      body: pageBody(1, <int>[12, 13], 5),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7/clips',
      body: pageBody(2, <int>[14, 15], 5),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/7/clips',
      body: pageBody(3, <int>[16], 5),
    );

    final clips = await api.getAllCollectionClips(collectionId: 7, pageSize: 2);

    expect(clips.map((c) => c.clipId), <int>[12, 13, 14, 15, 16]);
    expect(adapter.hitCount('GET', '/clip-collections/7/clips'), 3);
  });

  test('addClipToCollection maps PUT /clip-collections/{id}/clips/{clipId}', () async {
    adapter.enqueueJson(
      method: 'PUT',
      path: '/clip-collections/7/clips/12',
      statusCode: 204,
    );

    await api.addClipToCollection(collectionId: 7, clipId: 12);

    expect(adapter.hitCount('PUT', '/clip-collections/7/clips/12'), 1);
  });

  test('removeClipFromCollection maps DELETE /clip-collections/{id}/clips/{clipId}', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/clip-collections/7/clips/12',
      statusCode: 204,
    );

    await api.removeClipFromCollection(collectionId: 7, clipId: 12);

    expect(adapter.hitCount('DELETE', '/clip-collections/7/clips/12'), 1);
  });

  test('setCollectionClips puts ordered clip_ids', () async {
    adapter.enqueueJson(
      method: 'PUT',
      path: '/clip-collections/7/clips',
      statusCode: 204,
    );

    await api.setCollectionClips(collectionId: 7, clipIds: <int>[13, 12, 14]);

    expect(adapter.requests.single.body, <String, dynamic>{
      'clip_ids': <int>[13, 12, 14],
    });
  });
}
