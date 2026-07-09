import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/presentation/desktop_media_import_page.dart';
import 'package:sakuramedia/features/videos/data/api/video_imports_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows empty state when there are no import jobs', (
    tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(bundle, jobs: const <Map<String, dynamic>>[], total: 0);
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);

    await _pumpPage(tester, bundle: bundle);

    expect(find.byKey(const Key('media-import-page')), findsOneWidget);
    expect(find.byKey(const Key('media-import-create-button')), findsOneWidget);
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('renders a job row with status badge and counts', (tester) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(id: 3, taskRunId: 42, state: 'completed', imported: 5),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);

    await _pumpPage(tester, bundle: bundle);

    expect(find.byKey(const Key('media-import-job-path-3')), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('导入 5'), findsOneWidget);
  });

  testWidgets('shows inline progress bar from a task_run SSE event', (
    tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(id: 3, taskRunId: 42, state: 'running', imported: 1),
      ],
      total: 1,
    );
    _enqueueVideoJobsPage(bundle);
    // 两个 controller 各连一路 SSE；两路都带同一条 JAV task_run 事件，
    // 保证无论 FIFO 出队顺序如何，JAV controller 都能拿到事件流（task_key 不匹配的 PornBox 流会忽略它）。
    for (var i = 0; i < 2; i++) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/activity/bootstrap',
        body: _bootstrapBody(latestEventId: 120),
      );
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: <String>[
          'id: 121\n'
              'event: task_run_updated\n'
              'data: ${jsonEncode(_taskRunJson(id: 42, current: 3, total: 10))}\n\n',
        ],
      );
    }

    await _pumpPage(tester, bundle: bundle);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('3/10'), findsOneWidget);
  });

  testWidgets('expands failed files and shows retry action', (tester) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(
          id: 3,
          taskRunId: 42,
          state: 'completed',
          imported: 5,
          failed: 1,
        ),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/3',
      body: _jobJson(
        id: 3,
        taskRunId: 42,
        state: 'completed',
        imported: 5,
        failed: 1,
        failedFiles: <Map<String, dynamic>>[
          <String, dynamic>{
            'path': '/mnt/incoming/movies/ABP-123.mp4',
            'reason': 'movie_number_not_found',
            'detail': '',
            'kind': 'file',
          },
        ],
      ),
    );

    await _pumpPage(tester, bundle: bundle);

    await tester.tap(find.byKey(const Key('media-import-job-toggle-3')));
    await tester.pumpAndSettle();

    expect(find.text('/mnt/incoming/movies/ABP-123.mp4'), findsOneWidget);
    expect(find.byKey(const Key('media-import-retry-all-3')), findsOneWidget);
    expect(find.text('重导'), findsOneWidget);
  });

  testWidgets(
    '纯跳过作业（failed=0、skipped>0）也能展开，渲染中文原因 + 已跳过徽标',
    (tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueJobsPage(
        bundle,
        jobs: <Map<String, dynamic>>[
          _jobJson(
            id: 7,
            taskRunId: 99,
            state: 'completed',
            imported: 3,
            skipped: 2,
          ),
        ],
        total: 1,
      );
      _enqueueBootstrapAndStream(bundle);
      _enqueueVideoJobsPage(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/import-jobs/7',
        body: _jobJson(
          id: 7,
          taskRunId: 99,
          state: 'completed',
          imported: 3,
          skipped: 2,
          failedFiles: <Map<String, dynamic>>[
            <String, dynamic>{
              'path': '/mnt/incoming/movies/DUP-001.mp4',
              'reason': 'already_indexed_path',
              'detail': '',
              'kind': 'skipped',
            },
            <String, dynamic>{
              'path': '/mnt/incoming/movies/DUP-002.mp4',
              'reason': 'duplicate_fingerprint',
              'detail': '',
              'kind': 'skipped',
            },
          ],
        ),
      );

      await _pumpPage(tester, bundle: bundle);

      // failedCount=0 但 skippedCount>0：展开按钮仍出现。
      final toggle = find.byKey(const Key('media-import-job-toggle-7'));
      expect(toggle, findsOneWidget);
      expect(find.text('查看失败/跳过文件'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.text('/mnt/incoming/movies/DUP-001.mp4'), findsOneWidget);
      expect(find.text('/mnt/incoming/movies/DUP-002.mp4'), findsOneWidget);
      expect(find.textContaining('已在库中'), findsOneWidget);
      expect(find.textContaining('内容重复'), findsOneWidget);
      // 两条都是 skipped → 两个「已跳过」徽标。
      expect(find.text('已跳过'), findsNWidgets(2));
      // actionable 为空 → 「重导全部失败」按钮不出现。
      expect(find.byKey(const Key('media-import-retry-all-7')), findsNothing);
      // 行内不应出现「重导」按钮（skipped 不可操作）。
      expect(find.text('重导'), findsNothing);
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required TestApiBundle bundle,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ActivityEventStreamClient>.value(
          value: bundle.activityEventStreamClient,
        ),
        Provider<ActivityApi>.value(value: bundle.activityApi),
        Provider<MediaImportApi>.value(value: bundle.mediaImportApi),
        Provider<VideoImportsApi>.value(value: bundle.videoImportsApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopMediaImportPage()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  // 卸载页面以触发 controller.dispose，取消 SSE 重连定时器，避免 pending timer 断言。
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
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

Future<SessionStore> _createSessionStore() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
  );
  return sessionStore;
}

void _enqueueJobsPage(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> jobs,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/import-jobs',
    body: <String, dynamic>{
      'items': jobs,
      'page': 1,
      'page_size': 20,
      'total': total,
    },
  );
}

/// 媒体导入页同时持有 JAV 与 PornBox 两个 controller，各自连一次 bootstrap + SSE。
/// 两路响应内容一致（FIFO 按 path 出队），因此每个共享端点入队两次。
void _enqueueBootstrapAndStream(TestApiBundle bundle) {
  for (var i = 0; i < 2; i++) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: _bootstrapBody(latestEventId: 120),
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
}

/// PornBox 标签作业列表（`/video-imports`）；JAV 聚焦用例下默认空列表即可。
void _enqueueVideoJobsPage(
  TestApiBundle bundle, {
  List<Map<String, dynamic>> jobs = const <Map<String, dynamic>>[],
  int total = 0,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/video-imports',
    body: <String, dynamic>{
      'items': jobs,
      'page': 1,
      'page_size': 20,
      'total': total,
    },
  );
}

Map<String, dynamic> _bootstrapBody({required int latestEventId}) {
  return <String, dynamic>{
    'latest_event_id': latestEventId,
    'notifications': <String, dynamic>{
      'items': <Map<String, dynamic>>[],
      'page': 1,
      'page_size': 20,
      'total': 0,
    },
    'unread_count': 0,
    'active_task_runs': <Map<String, dynamic>>[],
    'task_runs': <String, dynamic>{
      'items': <Map<String, dynamic>>[],
      'page': 1,
      'page_size': 20,
      'total': 0,
    },
  };
}

Map<String, dynamic> _jobJson({
  required int id,
  required int taskRunId,
  required String state,
  int imported = 0,
  int skipped = 0,
  int failed = 0,
  List<Map<String, dynamic>>? failedFiles,
}) {
  return <String, dynamic>{
    'id': id,
    'source_path': '/mnt/incoming/movies',
    'library_id': 1,
    'task_run_id': taskRunId,
    'state': state,
    'transfer_mode': 'auto',
    'imported_count': imported,
    'skipped_count': skipped,
    'failed_count': failed,
    'created_at': '2026-06-07 10:00:00',
    'updated_at': '2026-06-07 10:05:00',
    if (failedFiles != null) 'failed_files': failedFiles,
  };
}

Map<String, dynamic> _taskRunJson({
  required int id,
  required int current,
  required int total,
}) {
  return <String, dynamic>{
    'id': id,
    'task_key': 'media_directory_import',
    'task_name': '媒体导入',
    'trigger_type': 'manual',
    'state': 'running',
    'progress_current': current,
    'progress_total': total,
    'progress_text': '导入中',
    'result_text': null,
    'result_summary': <String, dynamic>{'import_job_id': 3},
    'error_message': null,
    'started_at': '2026-06-07 10:00:00',
    'finished_at': null,
    'created_at': '2026-06-07 10:00:00',
    'updated_at': '2026-06-07 10:01:00',
  };
}
