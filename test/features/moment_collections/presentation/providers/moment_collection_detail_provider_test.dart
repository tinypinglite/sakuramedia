import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/moment_collections/data/api/moment_collections_api.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_detail_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionJson({int pointCount = 3}) => <String, dynamic>{
  'id': 7,
  'name': '周末回看',
  'description': '',
  'point_count': pointCount,
  'cover_image': null,
  'created_at': '2026-09-10T10:00:00Z',
  'updated_at': '2026-09-10T11:00:00Z',
};

Map<String, dynamic> _pointJson(int pointId, int position) => <String, dynamic>{
  'point_id': pointId,
  'media_id': pointId + 100,
  'movie_number': 'ABC-$pointId',
  'video_item_id': null,
  'thumbnail_id': pointId + 200,
  'offset_seconds': pointId * 10,
  'image': null,
  'position': position,
};

void main() {
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

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
    container = ProviderContainer(
      overrides: [
        momentCollectionsApiProvider.overrideWithValue(
          MomentCollectionsApi(apiClient: apiClient),
        ),
      ],
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
  });

  void keepAlive() {
    final subscription = container.listen(
      momentCollectionDetailProvider(7),
      (_, _) {},
    );
    addTearDown(subscription.close);
  }

  void enqueueLoad({int pointCount = 3}) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7',
      body: _collectionJson(pointCount: pointCount),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7/points',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _pointJson(10, 0),
          _pointJson(11, 1),
          _pointJson(12, 2),
        ],
        'page': 1,
        'page_size': 50,
        'total': 3,
      },
    );
  }

  test('详情会读取合集元数据和有序的时刻成员', () async {
    enqueueLoad();
    keepAlive();

    final state = await container.read(
      momentCollectionDetailProvider(7).future,
    );

    expect(state.collection.name, '周末回看');
    expect(state.points.map((point) => point.pointId), <int>[10, 11, 12]);
  });

  test('拖动排序会提交完整 point_ids 并更新本地顺序', () async {
    enqueueLoad();
    keepAlive();
    await container.read(momentCollectionDetailProvider(7).future);
    adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/7/points',
      statusCode: 204,
    );

    await container
        .read(momentCollectionDetailProvider(7).notifier)
        .reorder(0, 2);

    final state = container
        .read(momentCollectionDetailProvider(7))
        .requireValue;
    expect(state.points.map((point) => point.pointId), <int>[11, 10, 12]);
    expect(adapter.requests.last.body, <String, dynamic>{
      'point_ids': <int>[11, 10, 12],
    });
  });

  test('移出成员会保留时刻本体并更新本地计数', () async {
    enqueueLoad();
    keepAlive();
    await container.read(momentCollectionDetailProvider(7).future);
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/moment-collections/7/points/11',
      statusCode: 204,
    );

    await container
        .read(momentCollectionDetailProvider(7).notifier)
        .removePoint(11);

    final state = container
        .read(momentCollectionDetailProvider(7))
        .requireValue;
    expect(state.points.map((point) => point.pointId), <int>[10, 12]);
    expect(state.collection.pointCount, 2);
  });

  test('移出失败会回滚本地成员和计数', () async {
    enqueueLoad();
    keepAlive();
    await container.read(momentCollectionDetailProvider(7).future);
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/moment-collections/7/points/11',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'temporary failure'},
    );

    await expectLater(
      container
          .read(momentCollectionDetailProvider(7).notifier)
          .removePoint(11),
      throwsA(isA<Object>()),
    );

    final state = container
        .read(momentCollectionDetailProvider(7))
        .requireValue;
    expect(state.points.map((point) => point.pointId), <int>[10, 11, 12]);
    expect(state.collection.pointCount, 3);
  });
}
