import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_filter.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';

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
        clipsApiProvider.overrideWithValue(ClipsApi(apiClient: apiClient)),
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
    final subscription = container.listen(clipsOverviewProvider, (_, __) {});
    addTearDown(subscription.close);
  }

  test('build loads first page with default sort', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [1, 2], page: 1, total: 3, pageSize: 24),
    );

    keepAlive();
    final state = await container.read(clipsOverviewProvider.future);

    expect(state.paged.items.map((c) => c.clipId), <int>[1, 2]);
    expect(state.paged.total, 3);
    expect(state.paged.hasMore, isTrue);
    expect(state.filter.sort, ClipsFilter.defaultSort);
    expect(
      adapter.requests.single.uri.queryParameters['sort'],
      'created_at:desc',
    );
  });

  test('loadMore appends next page', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [1, 2], page: 1, total: 3, pageSize: 2),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [3], page: 2, total: 3, pageSize: 2),
    );

    keepAlive();
    await container.read(clipsOverviewProvider.future);
    await container.read(clipsOverviewProvider.notifier).loadMore();

    final state = container.read(clipsOverviewProvider).requireValue;
    expect(state.paged.items.map((c) => c.clipId), <int>[1, 2, 3]);
    expect(state.paged.hasMore, isFalse);
  });

  test('loadMore records error and keeps existing items', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [1, 2], page: 1, total: 5, pageSize: 2),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'down'},
    );

    keepAlive();
    await container.read(clipsOverviewProvider.future);
    await container.read(clipsOverviewProvider.notifier).loadMore();

    final state = container.read(clipsOverviewProvider).requireValue;
    expect(state.paged.items, hasLength(2));
    expect(state.paged.loadMoreErrorMessage, isNotNull);
  });

  test('applySort refetches with the new sort and updates filter', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [1], page: 1, total: 1, pageSize: 24),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [2], page: 1, total: 1, pageSize: 24),
    );

    keepAlive();
    await container.read(clipsOverviewProvider.future);
    final notifier = container.read(clipsOverviewProvider.notifier);

    // 同值去重：值对象 == 短路，不发第 2 次请求。
    await notifier.applySort('created_at:desc');
    expect(adapter.requests, hasLength(1));

    await notifier.applySort('created_at:asc');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.uri.queryParameters['sort'], 'created_at:asc');
    final state = container.read(clipsOverviewProvider).requireValue;
    expect(state.filter.sort, 'created_at:asc');
    expect(state.paged.items.single.clipId, 2);
  });

  test('initial filter update state is idle', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [1, 2], page: 1, total: 2, pageSize: 24),
    );

    keepAlive();
    final initial = await container.read(clipsOverviewProvider.future);
    expect(initial.paged.items, hasLength(2));
    expect(initial.paged.filterUpdate.isIdle, isTrue);
  });

  test('removeClip drops the clip and decrements total', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(clipIds: [1, 2], page: 1, total: 2, pageSize: 24),
    );

    keepAlive();
    await container.read(clipsOverviewProvider.future);
    container.read(clipsOverviewProvider.notifier).removeClip(1);

    final state = container.read(clipsOverviewProvider).requireValue;
    expect(state.paged.items.map((c) => c.clipId), <int>[2]);
    expect(state.paged.total, 1);
    expect(state.paged.hasMore, isFalse);
  });

  test('replaceClip swaps the matching clip in place', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(
        clipIds: [1, 2],
        page: 1,
        total: 2,
        pageSize: 24,
        titleOf: (id) => id == 1 ? 'old' : '',
      ),
    );

    keepAlive();
    await container.read(clipsOverviewProvider.future);
    container
        .read(clipsOverviewProvider.notifier)
        .replaceClip(_seedClip(clipId: 1, title: 'renamed'));

    final state = container.read(clipsOverviewProvider).requireValue;
    expect(state.paged.items.first.title, 'renamed');
    expect(state.paged.items, hasLength(2));
    // total 不变。
    expect(state.paged.total, 2);
  });
}

MediaClipDto _seedClip({required int clipId, String title = ''}) {
  return MediaClipDto(
    clipId: clipId,
    mediaId: 100 + clipId,
    movieNumber: 'ABC-${clipId.toString().padLeft(3, '0')}',
    startOffsetSeconds: 0,
    endOffsetSeconds: 10,
    title: title,
    durationSeconds: 10,
    fileSizeBytes: 0,
    coverImage: null,
    streamUrl: '/media-clips/$clipId/stream',
    createdAt: null,
  );
}

Map<String, dynamic> _clipsPage({
  required List<int> clipIds,
  required int page,
  required int total,
  required int pageSize,
  String Function(int)? titleOf,
}) {
  return <String, dynamic>{
    'items': clipIds
        .map(
          (clipId) => <String, dynamic>{
            'clip_id': clipId,
            'media_id': 100 + clipId,
            'movie_number': 'ABC-${clipId.toString().padLeft(3, '0')}',
            'start_offset_seconds': 0,
            'end_offset_seconds': 10,
            'title': titleOf?.call(clipId) ?? '',
            'duration_seconds': 10,
            'file_size_bytes': 0,
            'cover_image': null,
            'stream_url': '/media-clips/$clipId/stream',
            'created_at': null,
          },
        )
        .toList(),
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}
