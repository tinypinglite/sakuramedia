import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';
import '../../../../support/riverpod_test_helpers.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  VideoMutationEvents mutationBroadcaster() =>
      container.read(videoMutationEventsProvider.notifier);

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        videosApiProvider.overrideWithValue(VideosApi(apiClient: apiClient)),
      ],
      retry: (_, __) => null,
    );
    keepEventsProviderAlive(container, videoMutationEventsProvider);
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  Future<void> prime(
    VideoSummaryScope scope,
    List<Map<String, dynamic>> items, {
    int? total,
  }) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: _page(items: items, total: total ?? items.length),
    );
    container.listen(videoSummaryProvider(scope), (_, __) {});
    return container.read(videoSummaryProvider(scope).future);
  }

  test('初始加载使用默认排序和 24 条分页参数', () async {
    const scope = VideoSummaryScope.desktop;
    await prime(scope, <Map<String, dynamic>>[_video(1)]);

    final request = adapter.requests.single;
    expect(request.path, '/videos');
    expect(request.uri.queryParameters['page_size'], '24');
    expect(request.uri.queryParameters['sort'], 'created_at:desc');
    expect(request.uri.queryParameters.containsKey('uncollected'), isFalse);
  });

  test('未归类筛选携带 uncollected 重拉且清空旧页', () async {
    const scope = VideoSummaryScope.desktop;
    await prime(scope, <Map<String, dynamic>>[_video(1)]);
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: _page(items: <Map<String, dynamic>>[_video(2)], total: 1),
    );

    await container
        .read(videoSummaryProvider(scope).notifier)
        .applyFilter(const VideoFilterState(uncollected: true));

    final state = container.read(videoSummaryProvider(scope)).requireValue;
    expect(state.filter.uncollected, isTrue);
    expect(state.paged.items.single.id, 2);
    expect(adapter.requests.last.uri.queryParameters['uncollected'], 'true');
  });

  test('排序切换清空旧页并用新参数重拉', () async {
    const scope = VideoSummaryScope.desktop;
    await prime(scope, <Map<String, dynamic>>[_video(1)]);
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: _page(items: <Map<String, dynamic>>[_video(2)], total: 1),
    );

    await container
        .read(videoSummaryProvider(scope).notifier)
        .applyFilter(
          const VideoFilterState(
            sortField: VideoSortField.title,
            sortDirection: SortDirection.asc,
          ),
        );

    final state = container.read(videoSummaryProvider(scope)).requireValue;
    expect(state.paged.items.single.id, 2);
    expect(state.filter.sortField, VideoSortField.title);
    expect(adapter.requests.last.uri.queryParameters['sort'], 'title:asc');
  });

  test('删除广播就地移除条目，合集成员变更不影响网格', () async {
    const scope = VideoSummaryScope.desktop;
    await prime(scope, <Map<String, dynamic>>[_video(1), _video(2)]);

    mutationBroadcaster().reportCollectionMembershipChanged(videoId: 1);
    await _settleEvents();
    expect(
      container
          .read(videoSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .map((item) => item.id),
      <int>[1, 2],
    );

    mutationBroadcaster().reportDeleted(1);
    await _settleEvents();
    final state = container.read(videoSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((item) => item.id), <int>[2]);
    expect(state.paged.total, 1);
  });

  test('desktop/mobile family 状态隔离', () async {
    const desktop = VideoSummaryScope.desktop;
    const mobile = VideoSummaryScope.mobile;
    await prime(desktop, <Map<String, dynamic>>[_video(1)]);
    await prime(mobile, <Map<String, dynamic>>[_video(2)]);

    expect(
      container
          .read(videoSummaryProvider(desktop))
          .requireValue
          .paged
          .items
          .single
          .id,
      1,
    );
    expect(
      container
          .read(videoSummaryProvider(mobile))
          .requireValue
          .paged
          .items
          .single
          .id,
      2,
    );
  });

  test('页面缓存 link 保活列表，驱逐后重新请求', () async {
    const scope = VideoSummaryScope.desktop;
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: _page(items: <Map<String, dynamic>>[_video(1)], total: 1),
    );
    final subscription = container.listen(
      videoSummaryProvider(scope),
      (_, __) {},
    );
    await container.read(videoSummaryProvider(scope).future);
    final firstLink = container
        .read(videoSummaryProvider(scope).notifier)
        .cacheLink;
    expect(firstLink, isNotNull);

    final cache = RiverpodPageCache();
    addTearDown(cache.dispose);
    cache.obtain(key: scope.cacheKey, resolveLinks: () => [firstLink!]);
    subscription.close();
    await _settleEvents();
    expect(
      container
          .read(videoSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .id,
      1,
    );

    cache.remove(scope.cacheKey);
    await _settleEvents();
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: _page(items: <Map<String, dynamic>>[_video(2)], total: 1),
    );
    await container.read(videoSummaryProvider(scope).future);
    expect(
      container
          .read(videoSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .id,
      2,
    );
  });
}

Future<void> _settleEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  required int total,
}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 24,
    'total': total,
  };
}

Map<String, dynamic> _video(int id) {
  return <String, dynamic>{
    'id': id,
    'title': '视频$id',
    'summary': '',
    'cover_image': null,
    'release_date': null,
    'media_count': 1,
    'can_play': true,
    'created_at': '2026-01-02T03:04:05',
    'updated_at': '2026-01-02T03:04:05',
  };
}
