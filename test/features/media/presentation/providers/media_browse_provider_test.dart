import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';

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

  test('build loads first page with default filter (no sort param)', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_javItemJson(id: 1)], total: 1, page: 1),
    );

    final state = await container.read(mediaBrowseProvider.future);

    expect(state.paged.items, hasLength(1));
    expect(state.paged.items.first.id, 1);
    expect(state.filter.isDefault, isTrue);
    expect(
      adapter.requests.single.uri.queryParameters.containsKey('sort'),
      isFalse,
    );
  });

  test('applyFilterState triggers reload with new query and clears selection',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_javItemJson(id: 1)], total: 1, page: 1),
    );
    await container.read(mediaBrowseProvider.future);
    container.read(mediaBrowseProvider.notifier).toggleSelection(1);
    expect(container.read(mediaBrowseProvider).requireValue.selectionCount, 1);

    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const [], total: 0, page: 1),
    );

    await container.read(mediaBrowseProvider.notifier).applyFilterState(
          const MediaBrowseFilterState().copyWith(
            kind: MediaListItemKind.jav,
            libraryId: 8,
            sortField: MediaBrowseSortField.heat,
            sortDirection: MediaBrowseSortDirection.desc,
          ),
        );

    final state = container.read(mediaBrowseProvider).requireValue;
    expect(state.selectionCount, 0);
    expect(state.filter.kind, MediaListItemKind.jav);
    expect(
      adapter.requests.last.uri.queryParameters,
      containsPair('kind', 'jav'),
    );
    expect(
      adapter.requests.last.uri.queryParameters,
      containsPair('library_id', '8'),
    );
    expect(
      adapter.requests.last.uri.queryParameters,
      containsPair('sort', 'heat:desc'),
    );
  });

  test('applyFilterState short-circuits when equal filters are supplied',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const [], total: 0, page: 1),
    );
    await container.read(mediaBrowseProvider.future);

    await container
        .read(mediaBrowseProvider.notifier)
        .applyFilterState(const MediaBrowseFilterState().copyWith());

    expect(adapter.hitCount('GET', '/media'), 1);
  });

  test('removeItemsByIds prunes list, adjusts total, clears selection',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_javItemJson(id: 1), _javItemJson(id: 2)],
        total: 5,
        page: 1,
      ),
    );
    await container.read(mediaBrowseProvider.future);
    container.read(mediaBrowseProvider.notifier).toggleSelection(1);

    container.read(mediaBrowseProvider.notifier).removeItemsByIds(const [1, 2]);

    final state = container.read(mediaBrowseProvider).requireValue;
    expect(state.paged.items, isEmpty);
    expect(state.paged.total, 3);
    expect(state.selectionCount, 0);
  });

  test('selectAllLoaded / setSelected / clearSelection', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_javItemJson(id: 10), _javItemJson(id: 20)],
        total: 2,
        page: 1,
      ),
    );
    await container.read(mediaBrowseProvider.future);

    final notifier = container.read(mediaBrowseProvider.notifier);
    notifier.selectAllLoaded();
    expect(container.read(mediaBrowseProvider).requireValue.selectionCount, 2);
    expect(container.read(mediaBrowseProvider).requireValue.isSelected(10),
        isTrue);

    notifier.setSelected(10, false);
    expect(container.read(mediaBrowseProvider).requireValue.selectionCount, 1);

    notifier.clearSelection();
    expect(container.read(mediaBrowseProvider).requireValue.selectionCount, 0);
  });
}

Map<String, dynamic> _javItemJson({required int id}) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'ABC-$id',
    'video_item_id': null,
    'title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main',
    'path': '/library/main/abc-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'special_tags': '普通',
    'valid': true,
    'heat': 100,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}

Map<String, dynamic> _mediaPage({
  required List<Map<String, dynamic>> items,
  required int total,
  required int page,
  int pageSize = 20,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}
