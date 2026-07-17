import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaApi mediaApi;
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
    mediaApi = MediaApi(apiClient: apiClient);
    container = ProviderContainer(
      overrides: [mediaApiProvider.overrideWithValue(mediaApi)],
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
        pageSize: 1,
        total: 2,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        page: 2,
        pageSize: 1,
        total: 2,
        items: [_invalidMediaJson(id: 2, movieNumber: 'ABC-002')],
      ),
    );

    // Provider 默认 pageSize=20；这里 fake 返回 pageSize=1，走一次 loadMore 便到底。
    await container.read(invalidMediaProvider.future);
    await container.read(invalidMediaProvider.notifier).loadMore();

    final state = container.read(invalidMediaProvider).requireValue;
    // Provider 用它自己的 pageSize（20）拼参数，但 fake 只关心命中；后端返回 total=2
    // → 加载后 items 累加 2 条。
    expect(state.paged.items.map((item) => item.movieNumber),
        ['ABC-001', 'ABC-002']);
    expect(state.paged.total, 2);
    expect(state.paged.hasMore, isFalse);
  });

  test('keeps loaded items after load more error', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        page: 1,
        pageSize: 1,
        total: 2,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': 'Server error',
        },
      },
    );

    await container.read(invalidMediaProvider.future);
    await container.read(invalidMediaProvider.notifier).loadMore();

    final state = container.read(invalidMediaProvider).requireValue;
    expect(state.paged.items.single.movieNumber, 'ABC-001');
    expect(state.paged.loadMoreErrorMessage, '加载更多失效媒体失败，请点击重试');
    expect(state.paged.hasMore, isTrue);
  });

  test('removes item when validity check revives media', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/1/validity-check',
      body: _validityResultJson(id: 1, revived: true, validAfter: true),
    );

    await container.read(invalidMediaProvider.future);
    final result = await container
        .read(invalidMediaProvider.notifier)
        .checkValidity(mediaId: 1);

    expect(result.revived, isTrue);
    final state = container.read(invalidMediaProvider).requireValue;
    expect(state.paged.items, isEmpty);
    expect(state.paged.total, 0);
    expect(state.checkingMediaId, isNull);
  });

  test('keeps item when validity check is still invalid', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/1/validity-check',
      body: _validityResultJson(id: 1, revived: false, validAfter: false),
    );

    await container.read(invalidMediaProvider.future);
    final result = await container
        .read(invalidMediaProvider.notifier)
        .checkValidity(mediaId: 1);

    expect(result.revived, isFalse);
    final state = container.read(invalidMediaProvider).requireValue;
    expect(state.paged.items.single.id, 1);
    expect(state.paged.total, 1);
    expect(state.canDeleteMedia(1), isTrue);
  });

  test('deleteInvalidMedia requires failed validity check first', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );

    await container.read(invalidMediaProvider.future);

    expect(
      () => container
          .read(invalidMediaProvider.notifier)
          .deleteInvalidMedia(mediaId: 1),
      throwsA(isA<StateError>()),
    );
    expect(adapter.hitCount('DELETE', '/media/1'), 0);
  });

  test('deleteInvalidMedia removes checked invalid item after API succeeds',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/1/validity-check',
      body: _validityResultJson(id: 1, revived: false, validAfter: false),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);

    await container.read(invalidMediaProvider.future);
    await container
        .read(invalidMediaProvider.notifier)
        .checkValidity(mediaId: 1);
    await container
        .read(invalidMediaProvider.notifier)
        .deleteInvalidMedia(mediaId: 1);

    final state = container.read(invalidMediaProvider).requireValue;
    expect(state.paged.items, isEmpty);
    expect(state.paged.total, 0);
    expect(state.deletingMediaId, isNull);
    expect(state.canDeleteMedia(1), isFalse);
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

Map<String, dynamic> _invalidMediaJson({
  required int id,
  required String movieNumber,
}) {
  return <String, dynamic>{
    'id': id,
    'movie_number': movieNumber,
    'movie_title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'path': '/library/main/$movieNumber.mp4',
    'library_id': 1,
    'library_name': 'Main Library',
    'file_size_bytes': 1024,
    'updated_at': '2026-05-13T12:00:00Z',
  };
}

Map<String, dynamic> _validityResultJson({
  required int id,
  required bool revived,
  required bool validAfter,
}) {
  return <String, dynamic>{
    'id': id,
    'path': '/library/main/ABC-001.mp4',
    'file_exists': validAfter,
    'valid_before': false,
    'valid_after': validAfter,
    'updated': true,
    'invalidated': false,
    'revived': revived,
    'checked_at': '2026-05-13T12:10:00Z',
  };
}
