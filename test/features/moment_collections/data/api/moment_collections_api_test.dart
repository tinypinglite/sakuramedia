import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/moment_collections/data/api/moment_collections_api.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';

import '../../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionJson({int id = 7, String name = '周末回看'}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'description': '按时间整理的时刻',
      'point_count': 3,
      'cover_image': <String, dynamic>{
        'id': 1,
        'origin': '/moments/origin.webp',
        'small': '/moments/small.webp',
        'medium': '/moments/medium.webp',
        'large': '/moments/large.webp',
      },
      'created_at': '2026-09-10T10:00:00Z',
      'updated_at': '2026-09-10T11:00:00Z',
    };

Map<String, dynamic> _pointJson({int pointId = 12, int position = 0}) =>
    <String, dynamic>{
      'point_id': pointId,
      'media_id': 34,
      'movie_number': 'ABC-001',
      'video_item_id': null,
      'thumbnail_id': 56,
      'offset_seconds': 90,
      'image': <String, dynamic>{
        'id': 2,
        'origin': '/moments/point.webp',
        'small': '/moments/point.webp',
        'medium': '/moments/point.webp',
        'large': '/moments/point.webp',
      },
      'position': position,
    };

void main() {
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MomentCollectionsApi api;

  setUp(() async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-09-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    api = MomentCollectionsApi(apiClient: apiClient);
  });

  tearDown(() => apiClient.dispose());

  test('合集列表映射封面和时刻数', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: <Map<String, dynamic>>[_collectionJson()],
    );

    final collections = await api.getCollections();

    expect(collections.single.name, '周末回看');
    expect(collections.single.pointCount, 3);
    expect(
      collections.single.coverImage?.bestAvailableUrl,
      '/moments/large.webp',
    );
  });

  test('创建时刻合集会提交裁剪后的输入', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/moment-collections',
      statusCode: 201,
      body: _collectionJson(),
    );

    await api.createCollection(name: ' 周末回看 ', description: ' 朋友聚会 ');

    expect(adapter.requests.single.body, <String, dynamic>{
      'name': '周末回看',
      'description': '朋友聚会',
    });
  });

  test('成员列表读取 position，并在重排时提交 point_ids', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7/points',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _pointJson(pointId: 12, position: 0),
          _pointJson(pointId: 13, position: 1),
        ],
        'page': 1,
        'page_size': 50,
        'total': 2,
      },
    );
    adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/7/points',
      statusCode: 204,
    );

    final page = await api.getCollectionPoints(collectionId: 7);
    await api.setPoints(collectionId: 7, pointIds: <int>[13, 12]);

    expect(page.items.map((item) => item.position), <int>[0, 1]);
    expect(adapter.requests.last.body, <String, dynamic>{
      'point_ids': <int>[13, 12],
    });
  });

  test('时刻归属和单个收藏关系映射到专属端点', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points/12/collections',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'id': 7, 'name': '周末回看'},
      ],
    );
    adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/7/points/12',
      statusCode: 204,
    );

    final memberships = await api.getPointCollections(pointId: 12);
    await api.addPoint(collectionId: 7, pointId: 12);

    expect(memberships.single.name, '周末回看');
    expect(adapter.hitCount('PUT', '/moment-collections/7/points/12'), 1);
  });

  test('更新 DTO 只提交显式字段', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/moment-collections/7',
      body: _collectionJson(name: '重新命名'),
    );

    final updated = await api.updateCollection(
      collectionId: 7,
      payload: const UpdateMomentCollectionPayload(name: '重新命名'),
    );

    expect(updated.name, '重新命名');
    expect(adapter.requests.single.body, <String, dynamic>{'name': '重新命名'});
  });
}
