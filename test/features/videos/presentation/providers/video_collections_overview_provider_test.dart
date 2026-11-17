import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

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
        videoCollectionsApiProvider.overrideWithValue(
          VideoCollectionsApi(apiClient: apiClient),
        ),
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
    final subscription = container.listen(
      videoCollectionsOverviewProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  test('build fetches collections from the API', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections',
      body: _collectionsBody(ids: [10, 11]),
    );

    keepAlive();
    final result = await container.read(
      videoCollectionsOverviewProvider.future,
    );

    expect(result.map((c) => c.id), <int>[10, 11]);
  });

  test('refresh replaces cached list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections',
      body: _collectionsBody(ids: [10]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections',
      body: _collectionsBody(ids: [20, 21]),
    );

    keepAlive();
    await container.read(videoCollectionsOverviewProvider.future);
    await container
        .read(videoCollectionsOverviewProvider.notifier)
        .refresh();

    final state = container.read(videoCollectionsOverviewProvider);
    expect(state.hasValue, isTrue);
    expect(state.requireValue.map((c) => c.id), <int>[20, 21]);
  });

  test('refresh surfaces error state on failure', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections',
      body: _collectionsBody(ids: [10]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'down'},
    );

    keepAlive();
    await container.read(videoCollectionsOverviewProvider.future);
    await container
        .read(videoCollectionsOverviewProvider.notifier)
        .refresh();

    expect(container.read(videoCollectionsOverviewProvider).hasError, isTrue);
  });
}

List<Map<String, dynamic>> _collectionsBody({required List<int> ids}) {
  return ids
      .map(
        (id) => <String, dynamic>{
          'id': id,
          'name': 'Video Collection $id',
          'description': '',
          'item_count': 0,
          'cover_image': null,
          'created_at': null,
          'updated_at': null,
        },
      )
      .toList();
}
