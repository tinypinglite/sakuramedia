import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/presentation/pages/desktop/download_tasks_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('renders download tasks with manual add entry', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _fallbackDownloadPage(
      bundle,
      tasks: <Map<String, dynamic>>[_downloadTaskJson(401)],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(_desktopApp(bundle));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('download-tasks-page')), findsOneWidget);
    expect(find.byKey(const Key('download-task-401')), findsOneWidget);
    expect(find.byKey(const Key('download-tasks-manual-add')), findsOneWidget);
    expect(
      find.byKey(const Key('download-tasks-selection-entry')),
      findsOneWidget,
    );
  });

  testWidgets('keeps filter header and fills skeleton list while loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    final gate = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/download-tasks',
      responder: (options, body) async {
        await gate.future;
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'items': <Map<String, dynamic>>[_downloadTaskJson(401)],
            'page': 1,
            'page_size': 20,
            'total': 1,
          }),
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(_desktopApp(bundle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 加载态也保留真实筛选栏，避免数据回来后头部突然多出一行。
    expect(find.byKey(const Key('download-filter-search')), findsOneWidget);
    expect(find.byKey(const Key('download-tasks-manual-add')), findsOneWidget);
    // 按视口补足的骨架卡：1400×900 下至少 5 张。
    expect(find.byKey(const Key('download-task--1')), findsOneWidget);
    expect(find.byKey(const Key('download-task--5')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('download-task-401')), findsOneWidget);
    expect(find.byKey(const Key('download-task--1')), findsNothing);
  });

  testWidgets('deep link applies movie number with all state filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _fallbackDownloadPage(bundle, tasks: const <Map<String, dynamic>>[]);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(
      _desktopApp(
        bundle,
        page: const DesktopDownloadTasksPage(
          initialDownloadMovieNumber: 'SSIS-801',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final requests = bundle.adapter.requests
        .where((request) => request.path == '/download-tasks')
        .toList(growable: false);
    expect(requests, isNotEmpty);
    final last = requests.last;
    expect(last.uri.queryParameters['movie_number'], 'SSIS-801');
    expect(last.uri.queryParameters.containsKey('state'), isFalse);
  });

  testWidgets('batch deletes selected download tasks with progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _fallbackDownloadPage(
      bundle,
      tasks: <Map<String, dynamic>>[
        _downloadTaskJson(401),
        _downloadTaskJson(402),
        _downloadTaskJson(403),
      ],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(_desktopApp(bundle));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download-tasks-selection-entry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('download-tasks-selection-header')),
      findsOneWidget,
    );
    expect(find.text('已选 0 个'), findsOneWidget);
    await tester.tap(find.byKey(const Key('download-tasks-select-all-button')));
    await tester.pumpAndSettle();
    expect(find.text('已选 3 个'), findsOneWidget);
    // 多选态行内动作让位。
    expect(find.byKey(const Key('download-task-delete-401')), findsNothing);

    await tester.tap(
      find.byKey(const Key('download-tasks-batch-delete-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('download-task-delete-dialog')),
      findsOneWidget,
    );
    expect(find.text('是否删除 3 个下载任务？'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('download-task-delete-files-checkbox')),
    );
    await tester.pumpAndSettle();

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/batch-operations',
      statusCode: 202,
      body: {
        'task_run_id': 7,
        'task_key': 'batch_operation',
        'state': 'pending',
      },
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('download-task-delete-dialog')),
        matching: find.text('删除'),
      ),
    );
    await tester.pumpAndSettle();

    final submit = bundle.adapter.requests
        .where((request) => request.path == '/batch-operations')
        .toList();
    expect(submit, hasLength(1));
    expect(submit.single.body, {
      'operation': 'download_task_delete',
      'ids': [401, 402, 403],
      'delete_files': true,
    });
    expect(
      bundle.adapter.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );
    // 提交后列表不即时变化，等任务完成后手动刷新。
    expect(find.byKey(const Key('download-task-401')), findsOneWidget);
    expect(
      find.byKey(const Key('download-tasks-selection-header')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('single delete keeps dialog open until request completes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _fallbackDownloadPage(
      bundle,
      tasks: <Map<String, dynamic>>[
        _downloadTaskJson(401),
        _downloadTaskJson(402),
      ],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );
    final gate = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'DELETE',
      path: '/download-tasks/401',
      responder: (options, body) async {
        await gate.future;
        return ResponseBody.fromBytes(const <int>[], 204);
      },
    );

    await tester.pumpWidget(_desktopApp(bundle));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download-task-delete-401')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('download-task-delete-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('download-task-delete-files-checkbox')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('download-task-delete-dialog')),
        matching: find.text('删除'),
      ),
    );
    // loading spinner 持续排帧，不能用 pumpAndSettle。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final deletes = bundle.adapter.requests
        .where((request) => request.method == 'DELETE')
        .toList(growable: false);
    expect(deletes, hasLength(1));
    expect(deletes.single.path, '/download-tasks/401');
    expect(deletes.single.uri.queryParameters['delete_files'], 'true');
    expect(deletes.single.uri.queryParameters['confirm_delete_files'], 'true');
    // 请求未完成：弹窗与任务行都还在，确认按钮转圈。
    expect(
      find.byKey(const Key('download-task-delete-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('download-task-401')), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.widgetWithText(AppButton, '删除')).isLoading,
      isTrue,
    );

    gate.complete();
    await tester.pumpAndSettle();

    // 删除成功后弹窗才关闭，任务行被移除。
    expect(find.byKey(const Key('download-task-delete-dialog')), findsNothing);
    expect(find.byKey(const Key('download-task-401')), findsNothing);
    expect(find.byKey(const Key('download-task-402')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed download task exposes files button and file list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _fallbackDownloadPage(
      bundle,
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          ..._downloadTaskJson(401),
          'state': 'completed',
          'progress': 1.0,
          'import_status': 'completed',
        },
        _downloadTaskJson(402),
      ],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(_desktopApp(bundle));
    await tester.pumpAndSettle();

    // 只有已完成任务的卡片带「查看文件」入口。
    expect(find.byKey(const Key('download-task-files-401')), findsOneWidget);
    expect(find.byKey(const Key('download-task-files-402')), findsNothing);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-tasks/401/files',
      body: [
        {
          'name': 'ABC-00401.mkv',
          'relative_path': 'ABC-00401/ABC-00401.mkv',
          'size_bytes': 1048576,
          'is_video': true,
        },
      ],
    );
    await tester.tap(find.byKey(const Key('download-task-files-401')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('download-task-files-modal')), findsOneWidget);
    expect(find.text('ABC-00401.mkv'), findsOneWidget);
  });

  testWidgets('manual submit switches to all when current filter hides task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _fallbackDownloadPage(bundle, tasks: const <Map<String, dynamic>>[]);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'qb-main', 'library_id': 1},
      ],
    );

    await tester.pumpWidget(_desktopApp(bundle));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download-tasks-manual-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual-download-modal')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ABC-001',
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'ABC-001',
        'parsed': true,
        'movie_number': 'ABC-001',
        'reason': null,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'movie_number': 'ABC-001',
            'title': 'Movie',
          },
        ],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('manual-download-movie-number-query-button')),
    );
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: <String, dynamic>{
        'task': <String, dynamic>{
          'id': 500,
          'client_id': 1,
          'movie_number': 'ABC-001',
          'name': 'ABC-001',
          'remote_id': 'remote-500',
          'state': 'queued',
          'progress': 0.0,
          'import_status': 'pending',
          'created_at': '2026-08-10T12:00:00Z',
          'updated_at': '2026-08-10T12:00:00Z',
        },
        'created': true,
      },
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-download-modal')), findsNothing);
    final requests = bundle.adapter.requests
        .where((request) => request.path == '/download-tasks')
        .toList(growable: false);
    expect(requests, isNotEmpty);
    expect(requests.last.uri.queryParameters.containsKey('state'), isFalse);
    // 等 OKToast 的提示计时器结束，避免测试结束时报 pending timer。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'manual submit falls back to all when search is a partial number',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sessionStore = await _loggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);
      _fallbackDownloadPage(bundle, tasks: const <Map<String, dynamic>>[]);
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/download-clients',
        body: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'name': 'qb-main', 'library_id': 1},
        ],
      );

      await tester.pumpWidget(_desktopApp(bundle));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('download-filter-search')),
        'ABC',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('download-tasks-manual-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('manual-download-link-field')),
        'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
      );
      await tester.enterText(
        find.byKey(const Key('manual-download-movie-number-field')),
        'ABC-001',
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        body: <String, dynamic>{
          'query': 'ABC-001',
          'parsed': true,
          'movie_number': 'ABC-001',
          'reason': null,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'movie_number': 'ABC-001',
              'title': 'Movie',
            },
          ],
          'page': 1,
          'page_size': 50,
          'total': 1,
        },
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('manual-download-movie-number-query-button')),
      );
      await tester.pumpAndSettle();
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-requests/manual',
        statusCode: 201,
        body: <String, dynamic>{
          'task': <String, dynamic>{
            'id': 501,
            'client_id': 1,
            'movie_number': 'ABC-001',
            'name': 'ABC-001',
            'remote_id': 'remote-501',
            'state': 'downloading',
            'progress': 0.0,
            'import_status': 'pending',
            'created_at': '2026-08-10T12:00:00Z',
            'updated_at': '2026-08-10T12:00:00Z',
          },
          'created': true,
        },
      );
      await tester.tap(find.byKey(const Key('manual-download-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final requests = bundle.adapter.requests
          .where((request) => request.path == '/download-tasks')
          .toList(growable: false);
      // 后端按精确番号过滤；部分搜索词 'ABC' 不会命中 'ABC-001'，所以前端必须
      // 切到「全部」而不是继续带着搜索词刷新。
      expect(
        requests.last.uri.queryParameters.containsKey('movie_number'),
        isFalse,
      );
      expect(requests.last.uri.queryParameters.containsKey('state'), isFalse);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('filtered empty state offers view all', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _fallbackDownloadPage(bundle, tasks: const <Map<String, dynamic>>[]);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(_desktopApp(bundle));
    await tester.pumpAndSettle();

    expect(find.text('没有符合筛选条件的下载任务'), findsOneWidget);
    expect(find.byKey(const Key('download-empty-view-all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('download-empty-view-all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final requests = bundle.adapter.requests
        .where((request) => request.path == '/download-tasks')
        .toList(growable: false);
    expect(requests.last.uri.queryParameters.containsKey('state'), isFalse);
    expect(find.text('暂无下载任务'), findsOneWidget);
    expect(find.byKey(const Key('download-empty-manual-add')), findsOneWidget);
  });
}

Widget _desktopApp(
  TestApiBundle bundle, {
  Widget page = const DesktopDownloadTasksPage(),
}) {
  return ProviderScope(
    overrides: bundle.riverpodOverrides(),
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      theme: sakuraDesktopThemeData,
      home: AppPlatformScope(
        platform: AppPlatform.desktop,
        child: OKToast(child: Scaffold(body: page)),
      ),
    ),
  );
}

void _fallbackDownloadPage(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> tasks,
}) {
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/download-tasks',
    body: <String, dynamic>{
      'items': tasks,
      'page': 1,
      'page_size': 20,
      'total': tasks.length,
    },
  );
}

Future<SessionStore> _loggedInSessionStore() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
  );
  return sessionStore;
}

Map<String, dynamic> _downloadTaskJson(int id) => <String, dynamic>{
  'id': id,
  'client_id': 1,
  'movie_number': 'ABC-00$id',
  'name': 'ABC-00$id',
  'remote_id': 'remote-$id',
  'state': 'downloading',
  'progress': 0.5,
  'import_status': 'pending',
  'import_status_label': '等待导入',
  'created_at': '2026-08-10T12:00:00Z',
  'updated_at': '2026-08-10T12:00:00Z',
};
