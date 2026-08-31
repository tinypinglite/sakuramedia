import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';

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
      expiresAt: DateTime.parse('2026-05-13T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
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

  test('loads invalid media and appends more pages', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        page: 1,
        total: 3,
        items: [_invalidMediaJson(1), _invalidMediaJson(2)],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(page: 2, total: 3, items: [_invalidMediaJson(3)]),
    );

    await container.read(invalidMediaProvider.future);
    await container.read(invalidMediaProvider.notifier).loadMore();

    final state = container.read(invalidMediaProvider).requireValue;
    expect(state.paged.items.map((item) => item.id), [1, 2, 3]);
    expect(state.paged.total, 3);
  });

  test('deleteInvalidMedia removes item after API succeeds', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(total: 1, items: [_invalidMediaJson(1)]),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);

    await container.read(invalidMediaProvider.future);
    await container
        .read(invalidMediaProvider.notifier)
        .deleteInvalidMedia(mediaId: 1);

    final state = container.read(invalidMediaProvider).requireValue;
    expect(state.paged.items, isEmpty);
    expect(state.paged.total, 0);
    expect(state.deletingMediaId, isNull);
    expect(adapter.hitCount('DELETE', '/media/1'), 1);
  });
}

Map<String, dynamic> _invalidMediaPage({
  int page = 1,
  int pageSize = 20,
  required int total,
  required List<Map<String, dynamic>> items,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _invalidMediaJson(int id) {
  return <String, dynamic>{
    'id': id,
    'movie_number': 'ABC-$id',
    'video_item_id': null,
    'movie_title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'file_name': 'ABC-$id.mp4',
    'library_id': 1,
    'library_name': 'Main Library',
    'file_size_bytes': 1024,
    'updated_at': '2026-05-13T12:00:00Z',
  };
}
