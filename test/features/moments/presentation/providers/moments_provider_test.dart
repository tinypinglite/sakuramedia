import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

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
      expiresAt: DateTime.parse('2026-08-04T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        mediaApiProvider.overrideWithValue(MediaApi(apiClient: apiClient)),
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
    // autoDispose：挂监听者保活，避免两次 read 之间被释放重建。
    final subscription = container.listen(momentsProvider, (_, __) {});
    addTearDown(subscription.close);
  }

  test('refresh replaces first page items', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: _momentPage(pointIds: [1], total: 2),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: _momentPage(pointIds: [99], total: 1),
    );

    keepAlive();
    await container.read(momentsProvider.future);
    final errorMessage = await container.read(momentsProvider.notifier).refresh();

    expect(errorMessage, isNull);
    final state = container.read(momentsProvider).requireValue;
    expect(state.paged.items.single.pointId, 99);
    expect(state.paged.total, 1);
    expect(state.paged.hasMore, isFalse);
  });

  test('refresh returns error message and keeps existing items on failure',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: _momentPage(pointIds: [1], total: 2),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );

    keepAlive();
    await container.read(momentsProvider.future);
    final errorMessage = await container.read(momentsProvider.notifier).refresh();

    expect(errorMessage, isNotNull);
    final state = container.read(momentsProvider).requireValue;
    expect(state.paged.items.single.pointId, 1);
    expect(state.paged.total, 2);
  });

  test('applyFilterState reloads with the new kind and sort apiValue',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: _momentPage(pointIds: [1], total: 1),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: _momentPage(pointIds: [2], total: 1),
    );

    keepAlive();
    await container.read(momentsProvider.future);
    expect(
      adapter.requests.single.uri.queryParameters['kind'],
      'jav',
    );
    final notifier = container.read(momentsProvider.notifier);

    // 同值去重：不发请求。
    await notifier.applyFilterState(MomentsFilter.initial);
    expect(adapter.requests, hasLength(1));

    // 换内容类型 + 排序：清列表重拉，新请求携带新 apiValue。
    await notifier.applyFilterState(
      const MomentsFilter(
        sortOrder: MomentSortOrder.earliest,
        kindFilter: MomentKindFilter.video,
      ),
    );
    expect(adapter.requests, hasLength(2));
    final query = adapter.requests.last.uri.queryParameters;
    expect(query['kind'], 'video');
    expect(query['sort'], 'created_at:asc');
    final state = container.read(momentsProvider).requireValue;
    expect(state.filter.kindFilter, MomentKindFilter.video);
    expect(state.paged.items.single.pointId, 2);
  });
}

Map<String, dynamic> _momentPage({
  required List<int> pointIds,
  required int total,
}) {
  return <String, dynamic>{
    'items': pointIds
        .map(
          (pointId) => <String, dynamic>{
            'point_id': pointId,
            'media_id': 100 + pointId,
            'movie_number': 'ABC-${pointId.toString().padLeft(3, '0')}',
            'thumbnail_id': 500 + pointId,
            'offset_seconds': 360,
            'image': null,
          },
        )
        .toList(),
    'page': 1,
    'page_size': 20,
    'total': total,
  };
}
