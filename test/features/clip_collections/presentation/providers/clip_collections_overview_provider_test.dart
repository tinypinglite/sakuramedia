import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';

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
        clipCollectionsApiProvider.overrideWithValue(
          ClipCollectionsApi(apiClient: apiClient),
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
      clipCollectionsOverviewProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  test('build fetches collections from the API', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: [10, 11]),
    );

    keepAlive();
    final result = await container.read(
      clipCollectionsOverviewProvider.future,
    );

    expect(result.map((c) => c.id), <int>[10, 11]);
  });

  test('refresh replaces cached list without loading state', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: [10]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: [20, 21]),
    );

    keepAlive();
    await container.read(clipCollectionsOverviewProvider.future);
    await container
        .read(clipCollectionsOverviewProvider.notifier)
        .refresh();

    final state = container.read(clipCollectionsOverviewProvider);
    expect(state.hasValue, isTrue);
    expect(state.requireValue.map((c) => c.id), <int>[20, 21]);
  });

  test('refresh surfaces error state on failure', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: [10]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'down'},
    );

    keepAlive();
    await container.read(clipCollectionsOverviewProvider.future);
    await container
        .read(clipCollectionsOverviewProvider.notifier)
        .refresh();

    expect(container.read(clipCollectionsOverviewProvider).hasError, isTrue);
  });

  test('insertCollection prepends the new collection', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: [10]),
    );

    keepAlive();
    await container.read(clipCollectionsOverviewProvider.future);
    container
        .read(clipCollectionsOverviewProvider.notifier)
        .insertCollection(_seedCollection(id: 99));

    final state = container.read(clipCollectionsOverviewProvider).requireValue;
    expect(state.map((c) => c.id), <int>[99, 10]);
  });

  test('replaceCollection swaps the matching collection', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: [10, 11]),
    );

    keepAlive();
    await container.read(clipCollectionsOverviewProvider.future);
    container
        .read(clipCollectionsOverviewProvider.notifier)
        .replaceCollection(_seedCollection(id: 10, name: 'renamed'));

    final state = container.read(clipCollectionsOverviewProvider).requireValue;
    expect(state.first.name, 'renamed');
    expect(state.map((c) => c.id), <int>[10, 11]);
  });

  test('removeCollection drops the matching collection', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: [10, 11]),
    );

    keepAlive();
    await container.read(clipCollectionsOverviewProvider.future);
    container
        .read(clipCollectionsOverviewProvider.notifier)
        .removeCollection(10);

    final state = container.read(clipCollectionsOverviewProvider).requireValue;
    expect(state.map((c) => c.id), <int>[11]);
  });
}

ClipCollectionDto _seedCollection({required int id, String name = 'name'}) {
  return ClipCollectionDto(
    id: id,
    name: name,
    description: '',
    clipCount: 0,
    coverImage: null,
    createdAt: null,
    updatedAt: null,
  );
}

List<Map<String, dynamic>> _collectionsBody({required List<int> ids}) {
  return ids
      .map(
        (id) => <String, dynamic>{
          'id': id,
          'name': 'Collection $id',
          'description': '',
          'clip_count': 0,
          'cover_image': null,
          'created_at': null,
          'updated_at': null,
        },
      )
      .toList();
}
