import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/presentation/desktop_activity_page.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'desktop activity page no longer renders notifications and switches tabs',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        activeTasks: <Map<String, dynamic>>[_taskJson(id: 88)],
        taskRuns: <Map<String, dynamic>>[_taskJson(id: 88)],
      );

      await _pumpActivityPage(tester, bundle: bundle);

      expect(find.byKey(const Key('desktop-activity-page')), findsOneWidget);
      // 通知已迁出活动中心：不再有通知 Tab / 通知中心标题 / 已读归档 UI。
      expect(
        find.byKey(const Key('activity-tab-notifications')),
        findsNothing,
      );
      expect(find.text('通知中心'), findsNothing);
      expect(find.text('归档'), findsNothing);
      expect(find.text('已读'), findsNothing);

      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('activity-tasks-tab')), findsOneWidget);
      expect(find.byKey(const Key('activity-task-88')), findsNWidgets(2));
    },
  );

  testWidgets(
    'task history filter shows adaptive spinner immediately and keeps active task section',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        activeTasks: <Map<String, dynamic>>[_taskJson(id: 88)],
        taskRuns: <Map<String, dynamic>>[
          _taskJson(id: 201, state: 'completed'),
        ],
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/system/task-runs',
        responder: (_, __) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return _jsonResponseBody(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              _taskJson(id: 302, state: 'failed', taskName: '失败任务'),
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          });
        },
      );

      await _pumpActivityPage(tester, bundle: bundle);

      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('activity-task-state-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('失败').last);
      await tester.pump();

      expect(
        find.byKey(const Key('activity-task-filter-loading')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('activity-task-88')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('activity-task-filter-loading')),
        findsNothing,
      );
      expect(find.byKey(const Key('activity-task-302')), findsOneWidget);
      expect(find.byKey(const Key('activity-task-88')), findsOneWidget);
    },
  );

  testWidgets(
    'task tab hides active task card when there are no active tasks',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        taskRuns: <Map<String, dynamic>>[
          _taskJson(id: 201, taskName: '历史任务 201', state: 'completed'),
        ],
      );

      await _pumpActivityPage(tester, bundle: bundle);

      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();

      expect(find.text('活动任务'), findsNothing);
      expect(find.text('当前没有正在运行的后台任务'), findsNothing);
      expect(find.text('任务历史'), findsOneWidget);
      expect(find.byKey(const Key('activity-task-201')), findsOneWidget);
    },
  );

  testWidgets(
    'activity page applies compact typography for titles and filters',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        activeTasks: <Map<String, dynamic>>[
          _taskJson(id: 88, taskName: '活动任务标题'),
        ],
        taskRuns: <Map<String, dynamic>>[
          _taskJson(id: 201, taskName: '历史任务标题', state: 'completed'),
        ],
      );

      await _pumpActivityPage(tester, bundle: bundle);

      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();

      expect(_textStyleOf(tester, find.text('活动任务')).fontSize, 18);
      expect(_textStyleOf(tester, find.text('任务历史')).fontSize, 18);
      expect(_textStyleOf(tester, find.text('活动任务标题')).fontSize, 14);
      expect(_textStyleOf(tester, find.text('历史任务标题')).fontSize, 14);
      expect(
        _textStyleOf(tester, find.text('全部状态')).fontSize,
        sakuraThemeData.appTextScale.s12,
      );
    },
  );

  testWidgets('activity page renders sections without outer content cards', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      activeTasks: <Map<String, dynamic>>[
        _taskJson(id: 88, taskName: '活动任务标题'),
      ],
      taskRuns: <Map<String, dynamic>>[
        _taskJson(id: 201, taskName: '历史任务标题', state: 'completed'),
      ],
    );

    await _pumpActivityPage(tester, bundle: bundle);

    await tester.tap(find.byKey(const Key('activity-tab-tasks')));
    await tester.pumpAndSettle();

    expect(find.text('活动任务'), findsOneWidget);
    expect(find.text('任务历史'), findsOneWidget);
    expect(find.byType(AppContentCard), findsNothing);
    expect(find.byKey(const Key('activity-task-88')), findsOneWidget);
    expect(find.byKey(const Key('activity-task-201')), findsOneWidget);
  });

  testWidgets('task tab shows executable jobs and disabled forbidden job', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(
          taskKey: 'ranking_sync',
          cliHelp: '执行一次排行榜同步',
          manualTriggerAllowed: false,
          lastTaskRun: _taskJson(
            id: 88,
            taskKey: 'ranking_sync',
            taskName: '排行榜同步',
            state: 'completed',
          ),
        ),
      ],
    );

    await _pumpActivityPage(tester, bundle: bundle);
    await tester.tap(find.byKey(const Key('activity-tab-tasks')));
    await tester.pumpAndSettle();

    expect(find.text('可执行任务'), findsOneWidget);
    expect(find.text('1 个任务'), findsOneWidget);
    expect(find.text('执行一次排行榜同步'), findsNothing);
    expect(
      find.byKey(const Key('activity-job-trigger-ranking_sync')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('执行一次排行榜同步'), findsOneWidget);
    expect(find.text('0 2 * * *'), findsWidgets);
    expect(find.textContaining('最近运行：完成于'), findsOneWidget);
    expect(
      find.byKey(const Key('activity-job-trigger-ranking_sync')),
      findsOneWidget,
    );
    expect(find.text('不可手动执行'), findsOneWidget);
  });

  testWidgets('task tab triggers executable job and shows submitted toast', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(taskKey: 'ranking_sync', cliHelp: '执行一次排行榜同步'),
      ],
    );
    bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/system/jobs/ranking_sync/run',
      responder: (_, __) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return _jsonResponseBody(<String, dynamic>{
          'task_run_id': 13,
          'task_key': 'ranking_sync',
          'state': 'pending',
        });
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: _bootstrapBody(
        latestEventId: 121,
        activeTasks: <Map<String, dynamic>>[
          _taskJson(id: 13, taskKey: 'ranking_sync', taskName: '排行榜同步'),
        ],
        taskRuns: <Map<String, dynamic>>[
          _taskJson(id: 13, taskKey: 'ranking_sync', taskName: '排行榜同步'),
        ],
      ),
    );

    await _pumpActivityPage(tester, bundle: bundle);
    await tester.tap(find.byKey(const Key('activity-tab-tasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('activity-job-trigger-ranking_sync')),
    );
    await tester.pump();

    expect(find.text('提交中'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/system/jobs/ranking_sync/run'), 1);
    expect(find.text('任务已提交'), findsOneWidget);
    expect(find.byKey(const Key('activity-task-13')), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('task tab shows jobs load error retry entry', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': '任务列表加载失败',
        },
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: _bootstrapBody(latestEventId: 120),
    );
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        _jobJson(taskKey: 'ranking_sync', cliHelp: '执行一次排行榜同步'),
      ],
    );

    await _pumpActivityPage(tester, bundle: bundle);
    await tester.tap(find.byKey(const Key('activity-tab-tasks')));
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.byKey(const Key('activity-jobs-error')), findsNothing);

    await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-jobs-error')), findsOneWidget);
    expect(find.text('任务列表加载失败'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-jobs-retry-button')));
    await tester.pumpAndSettle();

    expect(find.text('执行一次排行榜同步'), findsOneWidget);
  });

  testWidgets(
    'activity page loading state renders without outer content card',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/system/activity/bootstrap',
        responder: (_, __) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _jsonResponseBody(
            _bootstrapBody(
              latestEventId: 120,
              activeTasks: const <Map<String, dynamic>>[],
              taskRuns: const <Map<String, dynamic>>[],
            ),
          );
        },
      );
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: const <String>[
          'id: 1\n'
              'event: heartbeat\n'
              'data: {}\n\n',
        ],
      );

      await _pumpActivityPage(tester, bundle: bundle, settle: false);

      expect(find.text('活动中心'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppContentCard), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('activity page error state renders without outer content card', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/system/activity/bootstrap',
      responder: (_, __) async => throw Exception('load failed'),
    );

    await _pumpActivityPage(tester, bundle: bundle);

    expect(find.text('活动中心'), findsOneWidget);
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byType(AppContentCard), findsNothing);
  });

  testWidgets(
    'download tab is lazy — no /download-tasks requests until switched to',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(bundle);

      await _pumpActivityPage(tester, bundle: bundle);

      expect(bundle.adapter.hitCount('GET', '/download-tasks'), 0);
      expect(bundle.adapter.hitCount('GET', '/download-tasks/stream'), 0);
      expect(bundle.adapter.hitCount('GET', '/download-clients'), 0);
    },
  );

  testWidgets(
    'switching to 下载任务 tab loads list, connects stream, renders card',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(bundle);
      _enqueueDownloadTaskState(
        bundle,
        items: <Map<String, dynamic>>[_downloadTaskJson(id: 11)],
      );

      await _pumpActivityPage(tester, bundle: bundle);
      await tester.tap(find.byKey(const Key('activity-tab-download-tasks')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('download-client-speed-bar')), findsOneWidget);
      expect(find.byKey(const Key('download-task-11')), findsOneWidget);
      expect(bundle.adapter.hitCount('GET', '/download-tasks'), 1);
      expect(bundle.adapter.hitCount('GET', '/download-tasks/stream'), 1);

      // 切回任务 tab 触发 downloadTask disconnect + 清 reconnect timer。
      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'delete confirm with delete_files checkbox forwards double confirm query',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(bundle);
      _enqueueDownloadTaskState(
        bundle,
        items: <Map<String, dynamic>>[_downloadTaskJson(id: 11)],
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/download-tasks/11',
        statusCode: 204,
      );

      await _pumpActivityPage(tester, bundle: bundle);
      await tester.tap(find.byKey(const Key('activity-tab-download-tasks')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('download-task-delete-11')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('download-task-delete-files-checkbox')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      final deleteReq = bundle.adapter.requests.lastWhere(
        (r) => r.path == '/download-tasks/11' && r.method == 'DELETE',
      );
      expect(deleteReq.uri.queryParameters['delete_files'], 'true');
      expect(deleteReq.uri.queryParameters['confirm_delete_files'], 'true');
      expect(find.byKey(const Key('download-task-11')), findsNothing);

      // 切回任务 tab 触发 downloadTask disconnect + 清 reconnect timer。
      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'tasks tab auto loads task history on scroll and retries failure',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        taskRuns: List<Map<String, dynamic>>.generate(
          20,
          (index) => _taskJson(
            id: index + 1,
            taskName: '任务 ${index + 1}',
            state: 'completed',
          ),
        ),
        taskRunTotal: 30,
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/system/task-runs',
        responder: (_, __) async => throw Exception('load more failed'),
      );

      await _pumpActivityPage(tester, bundle: bundle);

      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);

      expect(find.byKey(const Key('activity-task-20')), findsOneWidget);
      expect(find.text('加载更多任务失败，请点击重试'), findsOneWidget);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': List<Map<String, dynamic>>.generate(
            10,
            (index) => _taskJson(
              id: index + 21,
              taskName: '任务 ${index + 21}',
              state: 'completed',
            ),
          ),
          'page': 2,
          'page_size': 20,
          'total': 30,
        },
      );

      await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pump();
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);

      expect(bundle.adapter.hitCount('GET', '/system/task-runs'), 2);
      expect(find.byKey(const Key('activity-task-30')), findsOneWidget);
      expect(find.text('加载更多任务失败，请点击重试'), findsNothing);
    },
  );
}

Future<SessionStore> _createSessionStore() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T10:00:00Z'),
  );
  return sessionStore;
}

Future<void> _pumpActivityPage(
  WidgetTester tester, {
  required TestApiBundle bundle,
  SessionStore? sessionStore,
  bool settle = true,
}) async {
  // MaskedImage 需要在 widget 树里能找到 SessionStore（拿 baseUrl 拼绝对 URL）。
  // 下载任务卡片会引用 MaskedImage 展示影片封面，因此 harness 必须提供该 provider。
  final resolvedSessionStore = sessionStore ?? SessionStore.inMemory();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: resolvedSessionStore),
        Provider<ActivityEventStreamClient>.value(
          value: bundle.activityEventStreamClient,
        ),
        Provider<ActivityApi>.value(value: bundle.activityApi),
        Provider<DownloadsApi>.value(value: bundle.downloadsApi),
        Provider<DownloadClientsApi>.value(value: bundle.downloadClientsApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
}

void _setDesktopViewport(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();
  await tester.pumpAndSettle();
}

void _enqueueActivityState(
  TestApiBundle bundle, {
  int latestEventId = 120,
  List<Map<String, dynamic>> activeTasks = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> taskRuns = const <Map<String, dynamic>>[],
  int? taskRunTotal,
  List<Map<String, dynamic>> jobs = const <Map<String, dynamic>>[],
}) {
  bundle.adapter.enqueueJson(method: 'GET', path: '/system/jobs', body: jobs);
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: _bootstrapBody(
      latestEventId: latestEventId,
      activeTasks: activeTasks,
      taskRuns: taskRuns,
      taskRunTotal: taskRunTotal,
    ),
  );
  bundle.adapter.enqueueSse(
    method: 'GET',
    path: '/system/events/stream',
    chunks: const <String>[
      'id: 1\n'
          'event: heartbeat\n'
          'data: {}\n\n',
    ],
  );
}

Map<String, dynamic> _bootstrapBody({
  required int latestEventId,
  List<Map<String, dynamic>> activeTasks = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> taskRuns = const <Map<String, dynamic>>[],
  int? taskRunTotal,
}) {
  return <String, dynamic>{
    'latest_event_id': latestEventId,
    'notifications': const <String, dynamic>{
      'items': <Map<String, dynamic>>[],
      'page': 1,
      'page_size': 20,
      'total': 0,
    },
    'unread_count': 0,
    'active_task_runs': activeTasks,
    'task_runs': <String, dynamic>{
      'items': taskRuns,
      'page': 1,
      'page_size': 20,
      'total': taskRunTotal ?? taskRuns.length,
    },
  };
}

Map<String, dynamic> _taskJson({
  required int id,
  String? taskName,
  String taskKey = 'download_task_import',
  String triggerType = 'manual',
  String state = 'running',
}) {
  return <String, dynamic>{
    'id': id,
    'task_key': taskKey,
    'task_name': taskName ?? '下载任务导入 SSIS-${id.toString().padLeft(3, '0')}',
    'trigger_type': triggerType,
    'state': state,
    'progress_current': state == 'completed' ? 3 : 1,
    'progress_total': 3,
    'progress_text': state == 'completed' ? '导入完成' : '正在导入影片文件',
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:11:00Z',
    'started_at': '2026-03-26T09:10:00Z',
    'finished_at': state == 'completed' ? '2026-03-26T09:20:00Z' : null,
  };
}

Map<String, dynamic> _jobJson({
  required String taskKey,
  String? cliHelp,
  bool manualTriggerAllowed = true,
  Map<String, dynamic>? lastTaskRun,
}) {
  return <String, dynamic>{
    'task_key': taskKey,
    'log_name': taskKey.replaceAll('_', '-'),
    'cli_name': 'run-$taskKey',
    'cli_help': cliHelp ?? '执行一次 $taskKey',
    'cron_setting': '${taskKey}_cron',
    'cron_expr': '0 2 * * *',
    'manual_trigger_allowed': manualTriggerAllowed,
    'last_task_run': lastTaskRun,
  };
}

void _enqueueDownloadTaskState(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> items,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-tasks',
    body: <String, dynamic>{
      'items': items,
      'page': 1,
      'page_size': 20,
      'total': items.length,
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: <Map<String, dynamic>>[
      {
        'id': 2,
        'name': 'qb-main',
        'base_url': 'http://qb:8080',
        'username': 'admin',
        'client_save_path': '/downloads',
        'local_root_path': '/mnt/qb',
        'media_library_id': 1,
        'has_password': true,
      },
    ],
  );
  // 不加 keepOpen：流发一次 heartbeat 就正常关闭，
  // 控制器会调度 1s 重连 timer；测试完成前需切走 tab 或让 widget dispose
  // 来取消 timer + subscription。
  bundle.adapter.enqueueSse(
    method: 'GET',
    path: '/download-tasks/stream',
    chunks: const <String>[
      'event: heartbeat\n'
          'data: {}\n\n',
    ],
  );
}

Map<String, dynamic> _downloadTaskJson({required int id}) {
  return <String, dynamic>{
    'id': id,
    'client_id': 2,
    'movie_number': 'ABC-00$id',
    'name': 'ABC-00$id',
    'info_hash': 'hash-$id',
    'save_path': '/mnt/qb/$id',
    'progress': 0.4,
    'download_state': 'downloading',
    'import_status': 'pending',
    'import_status_label': '等待导入',
    'created_at': '2026-07-10T08:0$id:00Z',
    'updated_at': '2026-07-10T08:0$id:00Z',
  };
}

ResponseBody _jsonResponseBody(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

TextStyle _textStyleOf(WidgetTester tester, Finder finder) {
  return tester.widget<Text>(finder).style!;
}
