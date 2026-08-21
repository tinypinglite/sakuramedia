import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/sse_event_stream_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/subscriptions/data/api/movie_subscriptions_api.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/desktop/movie_subscriptions_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscriptions_api_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(sessionStore),
          movieSubscriptionsApiProvider.overrideWithValue(
            MovieSubscriptionsApi(apiClient: apiClient),
          ),
          moviesApiProvider.overrideWithValue(MoviesApi(apiClient: apiClient)),
          downloadsApiProvider.overrideWithValue(
            DownloadsApi(
              apiClient: apiClient,
              streamClient: createSseEventStreamClient(
                apiClient: apiClient,
                sessionStore: sessionStore,
              ),
            ),
          ),
          activityApiProvider.overrideWithValue(
            ActivityApi(
              apiClient: apiClient,
              streamClient: createActivityEventStreamClient(
                apiClient: apiClient,
                sessionStore: sessionStore,
              ),
            ),
          ),
        ],
        child: OKToast(
          child: MaterialApp(
            theme: sakuraDesktopThemeData,
            home: const Scaffold(body: DesktopMovieSubscriptionsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DesktopMovieSubscriptionsPage)),
      listen: false,
    );
  }

  void enqueueCounts({
    int imported = 5,
    int downloading = 0,
    int pending = 0,
    int missing = 2,
    int exhausted = 3,
    int importFailed = 0,
    int failed = 0,
    int total = 10,
  }) {
    adapter.setFallbackJson(
      method: 'GET',
      path: '/movie-subscriptions/status-counts',
      body: <String, dynamic>{
        'total': total,
        'imported': imported,
        'import_failed': importFailed,
        'downloading': downloading,
        'pending': pending,
        'missing': missing,
        'exhausted': exhausted,
        'failed': failed,
      },
    );
  }

  testWidgets('分段签带计数，默认落在「缺资源」并渲染求片进度', (tester) async {
    enqueueCounts();
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(
          number: 'ABP-123',
          status: 'missing',
          attemptCount: 2,
          deadCount: 1,
        ),
      ]),
    );

    await pumpPage(tester);

    expect(
      find.byKey(const Key('movie-subscriptions-status-tabs')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-subscriptions-status-tab-missing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-subscription-row-number-ABP-123')),
      findsOneWidget,
    );
    // 求片进度：这一页存在的理由，别的影片列表给不出。
    expect(
      find.byKey(const Key('movie-subscription-row-attempts-ABP-123')),
      findsOneWidget,
    );
    expect(find.text('再尝试 1 次就放弃'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-subscription-row-dead-ABP-123')),
      findsOneWidget,
    );
    expect(find.text('缺资源'), findsWidgets);
  });

  testWidgets('新片展示「持续查询」而不是查询次数', (tester) async {
    enqueueCounts();
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'NEW-001', status: 'missing', isFresh: true),
      ]),
    );

    await pumpPage(tester);

    expect(
      find.byKey(const Key('movie-subscription-row-fresh-NEW-001')),
      findsOneWidget,
    );
    expect(find.text('新片 · 持续查询中'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-subscription-row-attempts-NEW-001')),
      findsNothing,
      reason: '新片每轮都查、永不放弃，不该展示放弃倒计时',
    );
  });

  testWidgets('每个订阅行都可打开磁力搜索弹窗', (tester) async {
    enqueueCounts();
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'MAGNET-001', status: 'missing'),
      ]),
    );

    await pumpPage(tester);

    await tester.tap(
      find.byKey(const Key('movie-subscription-row-magnet-search-MAGNET-001')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-magnet-search-dialog')), findsOneWidget);
    expect(find.text('磁力搜索'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-magnet-search-button')),
      findsOneWidget,
    );
  });

  testWidgets('下载中不展示查询进度文案', (tester) async {
    enqueueCounts(downloading: 1);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'DL-001', status: 'downloading'),
      ]),
    );

    await pumpPage(tester);

    expect(
      find.byKey(const Key('movie-subscription-row-attempts-DL-001')),
      findsNothing,
    );
    expect(find.text('尚未查询'), findsNothing);
    expect(
      find.byKey(const Key('movie-subscription-row-number-DL-001')),
      findsOneWidget,
    );
  });

  testWidgets('已放弃行展示已查询次数而不是倒计时', (tester) async {
    enqueueCounts(exhausted: 1);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'EX-001', status: 'exhausted', attemptCount: 3),
      ]),
    );

    await pumpPage(tester);

    expect(find.text('已查询过 3 次'), findsOneWidget);
    expect(find.textContaining('再尝试'), findsNothing);
  });

  testWidgets('已入库的新片不展示「持续查询中」', (tester) async {
    enqueueCounts(imported: 1);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'IMP-001', status: 'imported', isFresh: true),
      ]),
    );

    await pumpPage(tester);

    expect(
      find.byKey(const Key('movie-subscription-row-fresh-IMP-001')),
      findsNothing,
    );
    expect(find.text('新片 · 持续查询中'), findsNothing);
  });

  testWidgets('待查行只展示尚未查询', (tester) async {
    enqueueCounts(pending: 1);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'P-001', status: 'pending'),
      ]),
    );

    await pumpPage(tester);

    expect(find.text('尚未查询'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-subscription-row-attempts-P-001')),
      findsNothing,
    );
  });

  testWidgets('待办态为空时给正向文案与「查看全部订阅」出口', (tester) async {
    enqueueCounts(missing: 0);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(const <Map<String, dynamic>>[]),
    );

    await pumpPage(tester);

    expect(find.text('没有缺资源的订阅'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-subscriptions-empty-see-all-button')),
      findsOneWidget,
    );
  });

  testWidgets('进入多选后顶栏原地改写，行内操作按钮收起', (tester) async {
    enqueueCounts();
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'ABP-123', status: 'missing'),
        _item(number: 'ABP-124', status: 'missing'),
      ]),
    );
    await pumpPage(tester);

    expect(
      find.byKey(const Key('movie-subscription-row-magnet-search-ABP-123')),
      findsOneWidget,
    );

    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-subscriptions-selection-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-subscriptions-list-header')),
      findsNothing,
      reason: '多选是原地改写整条顶栏，不是另起一行',
    );
    expect(
      find.byKey(const Key('movie-subscription-row-magnet-search-ABP-123')),
      findsNothing,
      reason: '多选态下行内操作与批量动作并存会让改动范围不可预期',
    );
    expect(find.text('已选 0 部'), findsOneWidget);

    await tester.tap(find.text('全选（2）'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 部'), findsOneWidget);
    expect(find.text('取消订阅（2）'), findsOneWidget);
  });

  testWidgets('导入失败独立成签并展示导入补救操作', (tester) async {
    enqueueCounts(importFailed: 3);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'ABP-123', status: 'missing'),
      ]),
    );
    await pumpPage(tester);

    // 待办组里有独立的一签，且角标带上了计数。
    expect(
      find.byKey(const Key('movie-subscriptions-status-tab-import_failed')),
      findsOneWidget,
    );

    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(
          number: 'GACHI-1151',
          status: 'import_failed',
          importOperation: <String, dynamic>{
            'import_job_id': 525,
            'download_task_id': 516,
            'state': 'failed',
            'imported_count': 0,
            'skipped_count': 0,
            'failed_count': 1,
            'retryable_file_count': 0,
            'available_actions': [
              'open_import_job',
              'rerun_import',
              'delete_failed_download',
            ],
            'failure_reason': 'no_media_files_found',
            'failure_detail': '下载目录中没有扫描到可导入的视频',
          },
        ),
      ]),
    );
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/download-tasks/516',
      statusCode: 204,
    );
    // 删除成功后行内刷新会再打一次列表 GET。
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(
          number: 'GACHI-1151',
          status: 'import_failed',
          importOperation: <String, dynamic>{
            'import_job_id': 525,
            'download_task_id': 516,
            'state': 'failed',
            'imported_count': 0,
            'skipped_count': 0,
            'failed_count': 1,
            'retryable_file_count': 0,
            'available_actions': [
              'open_import_job',
              'rerun_import',
              'delete_failed_download',
            ],
            'failure_reason': 'no_media_files_found',
            'failure_detail': '下载目录中没有扫描到可导入的视频',
          },
        ),
      ]),
    );
    await tester.tap(
      find.byKey(const Key('movie-subscriptions-status-tab-import_failed')),
    );
    await tester.pumpAndSettle();

    expect(find.text('导入失败'), findsWidgets);
    // 取消订阅仍然可用。
    final unsubscribeInk = tester.widget<InkWell>(
      find.byKey(const Key('movie-subscription-row-unsubscribe-GACHI-1151')),
    );
    expect(unsubscribeInk.onTap, isNotNull);
    // 失败原因一行直接可见，且「查看导入作业」入口可用。
    expect(
      find.byKey(const Key('movie-subscription-row-import-error-GACHI-1151')),
      findsOneWidget,
    );
    expect(find.text('未发现媒体文件：下载目录中没有扫描到可导入的视频'), findsOneWidget);
    final openImportInk = tester.widget<InkWell>(
      find.byKey(const Key('movie-subscription-row-open-import-GACHI-1151')),
    );
    expect(openImportInk.onTap, isNotNull);
    // 删除下载记录入口可用：复用下载中心的删除任务逻辑，删掉后等 cron 重查。
    final deleteDownloadInk = tester.widget<InkWell>(
      find.byKey(
        const Key('movie-subscription-row-delete-download-GACHI-1151'),
      ),
    );
    expect(deleteDownloadInk.onTap, isNotNull);

    await tester.tap(
      find.byKey(
        const Key('movie-subscription-row-delete-download-GACHI-1151'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('movie-subscription-delete-download-dialog-GACHI-1151'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('删除记录'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.where(
        (request) =>
            request.method == 'DELETE' && request.path == '/download-tasks/516',
      ),
      hasLength(1),
    );
    expect(find.text('已删除下载记录，等待自动下载重新找种'), findsOneWidget);
    // 排掉 oktoast 的 ~2.3s 计时器，否则测试以「Pending timers」失败。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('零产出导入显示未产出媒体而不是导入失败', (tester) async {
    enqueueCounts(importFailed: 1);
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'ABP-123', status: 'missing'),
      ]),
    );
    await pumpPage(tester);

    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(
          number: 'CWPBD-99',
          status: 'import_failed',
          importOperation: <String, dynamic>{
            'import_job_id': 783,
            'download_task_id': 787,
            'state': 'completed',
            'outcome': 'no_media',
            'imported_count': 0,
            'skipped_count': 6,
            'failed_count': 0,
            'available_actions': ['open_import_job', 'rerun_import'],
            'failure_reason': 'file_too_small',
          },
        ),
      ]),
    );
    await tester.tap(
      find.byKey(const Key('movie-subscriptions-status-tab-import_failed')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('未入库'), findsOneWidget);
    expect(find.text('未产出媒体'), findsWidgets);
    expect(find.text('导入失败'), findsNothing);
    expect(find.textContaining('未产出媒体：跳过 6 个文件'), findsOneWidget);
  });

  testWidgets('行内取消订阅移除该行并广播', (tester) async {
    enqueueCounts();
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(<Map<String, dynamic>>[
        _item(number: 'ABP-123', status: 'missing'),
        _item(number: 'ABP-124', status: 'missing'),
      ]),
    );
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABP-123/subscription',
      statusCode: 204,
    );
    final container = await pumpPage(tester);

    final changes = <MovieSubscriptionChange>[];
    container.listen(movieSubscriptionEventsProvider, (_, next) {
      final batch = next.value;
      if (batch != null) changes.addAll(batch);
    });

    await tester.tap(
      find.byKey(const Key('movie-subscription-row-unsubscribe-ABP-123')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-subscription-row-number-ABP-123')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-subscription-row-number-ABP-124')),
      findsOneWidget,
    );
    expect(changes.single.movieNumber, 'ABP-123');
    expect(changes.single.isSubscribed, isFalse);
    expect(find.text('已取消订阅影片'), findsOneWidget);
    // 排掉 oktoast 的 ~2.3s 计时器，否则测试以「Pending timers」失败。
    await tester.pump(const Duration(seconds: 3));
  });
}

Map<String, dynamic> _item({
  required String number,
  required String status,
  int attemptCount = 0,
  int deadCount = 0,
  bool isFresh = false,
  Map<String, dynamic>? importOperation,
}) {
  return <String, dynamic>{
    // 页面测试不打重置请求，id 只需非零占位。
    'movie_id': number.hashCode.abs() % 100000 + 1,
    'movie_number': number,
    'title': 'Title $number',
    'status': status,
    'is_fresh': isFresh,
    'attempt_count': attemptCount,
    'attempt_limit': 3,
    'dead_download_task_count': deadCount,
    'media_count': 0,
    if (importOperation != null) 'import_operation': importOperation,
  };
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 20,
    'total': items.length,
  };
}
