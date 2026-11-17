import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_provider.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expiresAt: DateTime.parse('2026-08-04T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void keepAlive() {
    // autoDispose：挂监听者保活。
    final subscription = container.listen(
      overviewSystemInfoProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  OverviewSystemInfo notifier() =>
      container.read(overviewSystemInfoProvider.notifier);

  /// 等 build 里 microtask 触发的初始 load 完成。
  Future<void> settle() => pumpEventQueue();

  test('build kicks off load; all legs land and flags clear', () async {
    _enqueueOverviewStatus(adapter);

    keepAlive();
    expect(container.read(overviewSystemInfoProvider).isLoadingStatus, isTrue);
    await settle();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.isLoadingStatus, isFalse);
    expect(state.isLoadingImageSearchStatus, isFalse);
    expect(state.isLoadingInsights, isFalse);
    expect(state.isLoadingWatchTrend, isFalse);
    expect(state.status, isNotNull);
    expect(state.statusError, isNull);
    expect(state.insights, isNotNull);
    expect(state.insightsError, isNull);
    expect(state.watchTrend, isNotNull);
    expect(state.watchTrendError, isNull);
  });

  test(
    'status failure sets error; image search failure stays silent',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/status',
        statusCode: 500,
        body: <String, dynamic>{'detail': 'failed'},
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/status/image-search',
        statusCode: 500,
        body: <String, dynamic>{'detail': 'failed'},
      );
      _enqueueInsights(adapter);
      _enqueueWatchTrend(adapter);

      keepAlive();
      await settle();

      final state = container.read(overviewSystemInfoProvider);
      // 三腿错误语义不同:status 置错,image-search 静默 null。
      expect(state.statusError, '媒体资产加载失败，请稍后重试');
      expect(state.imageSearchStatus, isNull);
      expect(state.isLoadingStatus, isFalse);
      expect(state.isLoadingImageSearchStatus, isFalse);
    },
  );

  test('insights failure sets its own error without blocking others', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      body: <String, dynamic>{},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      body: <String, dynamic>{},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/insights',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    _enqueueWatchTrend(adapter);

    keepAlive();
    await settle();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.insightsError, '统计数据加载失败');
    expect(state.statusError, isNull);
    expect(state.watchTrendError, isNull);
  });

  test(
    'setWatchTrendRange requests the new range once and ignores repeats',
    () async {
      _enqueueOverviewStatus(adapter);
      keepAlive();
      await settle();

      _enqueueWatchTrend(adapter, range: '7d', watchedMovieCount: 3);
      await notifier().setWatchTrendRange(WatchTrendRange.last7Days);

      var state = container.read(overviewSystemInfoProvider);
      expect(state.watchTrendRange, WatchTrendRange.last7Days);
      expect(state.watchTrend?.watchedMovieCount, 3);
      expect(adapter.hitCount('GET', '/status/watch-trend'), 2);
      expect(adapter.requests.last.uri.queryParameters['range'], '7d');

      await notifier().setWatchTrendRange(WatchTrendRange.last7Days);
      expect(adapter.hitCount('GET', '/status/watch-trend'), 2);
      state = container.read(overviewSystemInfoProvider);
      expect(state.watchTrendRange, WatchTrendRange.last7Days);
    },
  );

  test('refresh resets loading flags and clears previous error', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      body: <String, dynamic>{},
    );
    _enqueueInsights(adapter);
    _enqueueWatchTrend(adapter);
    keepAlive();
    await settle();
    expect(container.read(overviewSystemInfoProvider).statusError, isNotNull);

    _enqueueOverviewStatus(adapter);
    await notifier().refresh();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.statusError, isNull);
    expect(state.status, isNotNull);
  });

  test('resetImageSearch refreshes the image-search status', () async {
    _enqueueOverviewStatus(adapter);
    keepAlive();
    await settle();

    adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/reset',
      statusCode: 202,
      body: <String, dynamic>{},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      body: <String, dynamic>{
        'index_space': <String, dynamic>{
          'state': 'rebuild_required',
          'indexed_space_id': 'siglip2-old',
          'current_space_id': 'siglip2-new',
          'is_rebuilding': true,
        },
      },
    );

    await notifier().resetImageSearch();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.isResettingImageSearch, isFalse);
    expect(state.imageSearchStatus?.indexSpace.isRebuilding, isTrue);
    expect(adapter.hitCount('POST', '/image-search/reset'), 1);
  });

  test('formats an active image-search rebuild as rebuilding', () {
    final status = StatusImageSearchDto.fromJson(<String, dynamic>{
      'index_space': <String, dynamic>{
        'state': 'rebuild_required',
        'is_rebuilding': true,
      },
    });

    expect(imageSearchIndexSpaceLabel(status, AppLocalizationsZh()), '重建中');
    expect(imageSearchIndexSpaceTone(status), AppTextTone.info);
    expect(pendingIndexCount(null), 0);
  });
}

void _enqueueOverviewStatus(FakeHttpClientAdapter adapter) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    body: <String, dynamic>{},
  );
  adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: <String, dynamic>{},
  );
  _enqueueInsights(adapter);
  _enqueueWatchTrend(adapter);
}

void _enqueueInsights(FakeHttpClientAdapter adapter) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/status/insights',
    body: <String, dynamic>{'media_libraries': <dynamic>[]},
  );
}

void _enqueueWatchTrend(
  FakeHttpClientAdapter adapter, {
  String range = '30d',
  int watchedMovieCount = 5,
}) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/status/watch-trend',
    body: <String, dynamic>{
      'range': range,
      'granularity': 'day',
      'watched_movie_count': watchedMovieCount,
      'buckets': <dynamic>[],
    },
  );
}
