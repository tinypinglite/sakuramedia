import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/activity_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('shows task center without removed download tab', (tester) async {
    const pluginId = 'sakuramedia_115_provider';
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: const <dynamic>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: <String, dynamic>{
        'notifications': <String, dynamic>{
          'items': const <dynamic>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
        'unread_count': 0,
        'active_task_runs': const <dynamic>[],
        'task_runs': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 201,
              'task_key': 'media_import',
              'task_name': '媒体导入',
              'trigger_type': 'manual',
              'state': 'running',
              'progress_current': 1,
              'progress_total': 2,
              'progress_text': '处理中',
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-activity-page')), findsOneWidget);
    expect(find.byKey(const Key('activity-tasks-tab')), findsOneWidget);
    expect(find.byKey(const Key('activity-tab-download-tasks')), findsNothing);
    expect(find.byKey(const Key('activity-attention-section')), findsNothing);
    expect(
      find.byKey(const Key('download-tasks-selection-entry')),
      findsNothing,
    );
    expect(find.byKey(const Key('activity-task-201')), findsOneWidget);

    // 排序入口和筛选下拉在同一行、靠左，不能被 Wrap 的有界宽度拉满后居中。
    final sortCenter = tester.getCenter(
      find.byKey(const Key('activity-task-sort-trigger')),
    );
    final stateCenter = tester.getCenter(
      find.byKey(const Key('activity-task-state-filter')),
    );
    expect(sortCenter.dy, closeTo(stateCenter.dy, 1));
    expect(sortCenter.dx, greaterThan(stateCenter.dx));

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'core_job',
          'cli_help': '核心维护任务',
          'cron_expr': '0 1 * * *',
          'manual_trigger_allowed': true,
        },
        <String, dynamic>{
          'task_key': 'plugin_job_1',
          'plugin_id': pluginId,
          'cli_help': '插件任务一',
          'cron_expr': '0 2 * * *',
          'manual_trigger_allowed': true,
        },
        <String, dynamic>{
          'task_key': 'plugin_job_2',
          'plugin_id': pluginId,
          'cli_help': '插件任务二',
          'cron_expr': '0 3 * * *',
          'manual_trigger_allowed': true,
        },
      ],
    );

    await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.requests.where((r) => r.path == '/system/jobs'),
      hasLength(2),
    );
    expect(find.byKey(const Key('activity-job-plugin-filter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-job-plugin-filter')));
    await tester.pumpAndSettle();

    expect(find.text('系统任务'), findsOneWidget);
    expect(find.text(pluginId), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('activity-job-plugin-filter'))).width,
      moreOrLessEquals(
        sakuraDesktopThemeData.appLayoutTokens.dialogWidthMd -
            sakuraDesktopThemeData.appSpacing.xl * 2,
        epsilon: 0.1,
      ),
    );
    await tester.tap(find.text(pluginId));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-job-core_job')), findsNothing);
    expect(find.byKey(const Key('activity-job-plugin_job_1')), findsOneWidget);
    expect(find.byKey(const Key('activity-job-plugin_job_2')), findsOneWidget);
  });

  testWidgets('disabled optional-service job shows 未启用 and cannot trigger', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: <String, dynamic>{
        'notifications': <String, dynamic>{
          'items': const <dynamic>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
        'unread_count': 0,
        'active_task_runs': const <dynamic>[],
        'task_runs': <String, dynamic>{
          'items': const <dynamic>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: const <dynamic>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'image_search_index',
          'cli_help': '图像搜索索引构建',
          'cron_expr': '0 5 * * *',
          'manual_trigger_allowed': false,
          'disabled_reason': '图片与文字搜图未启用',
        },
      ],
    );
    await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('activity-job-image_search_index')),
      findsOneWidget,
    );
    expect(find.text('未启用'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('activity-job-trigger-image_search_index')),
    );
    await tester.pumpAndSettle();
    expect(bundle.adapter.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('task key filter lists chinese task names but filters by key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: const <dynamic>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: <String, dynamic>{
        'notifications': <String, dynamic>{
          'items': const <dynamic>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
        'unread_count': 0,
        'active_task_runs': const <dynamic>[],
        'task_runs': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 601,
              'task_key': 'download_task_sync',
              'task_name': '下载任务状态同步',
              'trigger_type': 'scheduled',
              'state': 'completed',
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('activity-task-key-filter')));
    await tester.pumpAndSettle();

    expect(find.text('全部任务类型'), findsNWidgets(2));
    expect(find.text('下载任务状态同步'), findsWidgets);
    expect(find.text('download_task_sync'), findsNothing);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );
    await tester.tap(find.text('下载任务状态同步').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/system/task-runs',
    );
    expect(request.uri.queryParameters['task_key'], 'download_task_sync');
    expect(request.uri.queryParameters['scope'], 'all');
    expect(find.text('download_task_sync'), findsNothing);
  });

  testWidgets('plugin trigger source labeled and filterable', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: const <dynamic>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: <String, dynamic>{
        'notifications': <String, dynamic>{
          'items': const <dynamic>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
        'unread_count': 0,
        'active_task_runs': const <dynamic>[],
        'task_runs': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 701,
              'task_key': 'library_import',
              'task_name': '插件视频导入',
              'trigger_type': 'plugin',
              'state': 'completed',
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('插件触发'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-task-trigger-filter')));
    await tester.pumpAndSettle();

    expect(find.text('插件触发'), findsWidgets);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );
    await tester.tap(find.text('插件触发').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/system/task-runs',
    );
    expect(request.uri.queryParameters['trigger_type'], 'plugin');
    expect(request.uri.queryParameters['scope'], 'all');
  });

  testWidgets('completed import task exposes failed file handling entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: const <dynamic>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: <String, dynamic>{
        'notifications': <String, dynamic>{
          'items': const <dynamic>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
        'unread_count': 0,
        'active_task_runs': const <dynamic>[],
        'task_runs': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 301,
              'task_key': 'library_import',
              'task_name': 'JAV媒体库导入',
              'trigger_type': 'manual',
              'state': 'failed',
              'result_summary': <String, dynamic>{
                'failed_count': 1,
                'failed_files': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'failure-1',
                    'state': 'pending',
                    'reason': 'movie_number_not_found',
                    'kind': 'file',
                  },
                ],
              },
            },
            <String, dynamic>{
              'id': 302,
              'task_key': 'library_import',
              'task_name': '视频导入',
              'trigger_type': 'manual',
              'state': 'completed',
              'result_summary': <String, dynamic>{
                'failed_count': 0,
                'failed_files': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'skipped-1',
                    'state': 'pending',
                    'reason': 'unsupported_format',
                    'kind': 'skipped',
                  },
                  <String, dynamic>{
                    'id': 'skipped-2',
                    'state': 'pending',
                    'reason': 'file_too_small',
                    'kind': 'skipped',
                  },
                ],
              },
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/imports/301/failed-items',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'failure-1',
          'relative_path': 'release/no-number.mp4',
          'size_bytes': 2048,
          'is_video': true,
          'reason': 'movie_number_not_found',
          'detail': '无法从文件名识别番号',
          'kind': 'file',
          'state': 'pending',
          'retry_task_run_id': null,
          'resolved_movie_id': null,
          'resolved_media_id': null,
          'last_retry_error': null,
          'can_manual_search': true,
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('activity-task-failed-items-301'));
    expect(entry, findsOneWidget);
    expect(find.text('处理失败文件（1）'), findsOneWidget);
    expect(
      find.byKey(const Key('activity-task-failed-items-302')),
      findsOneWidget,
    );
    expect(find.text('查看跳过文件（2）'), findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('失败与跳过文件'), findsOneWidget);
    expect(find.text('no-number.mp4'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('retained task center follows visibility', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _RetainedActivityCenter.instance = null;

    var isVisible = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityCenterProvider.overrideWith(_RetainedActivityCenter.new),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return TickerMode(
                enabled: isVisible,
                child: const Scaffold(body: DesktopActivityPage()),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final activity = _RetainedActivityCenter.instance!;
    expect(activity.pauseCalls, 1);
    expect(activity.resumeCalls, 0);

    rebuild(() => isVisible = true);
    await tester.pumpAndSettle();
    expect(activity.resumeCalls, 1);

    rebuild(() => isVisible = false);
    await tester.pumpAndSettle();
    expect(activity.pauseCalls, 2);

    rebuild(() => isVisible = true);
    await tester.pumpAndSettle();
    expect(activity.resumeCalls, 2);
  });

  testWidgets(
    'executable jobs dialog fits short window and list scrolls to end',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');
      await sessionStore.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
      );
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);
      _enqueueActivityBootstrap(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/jobs',
        body: <Map<String, dynamic>>[
          for (var index = 1; index <= 8; index++)
            <String, dynamic>{
              'task_key': 'job_$index',
              'plugin_id': 'plugin_a',
              'cli_help': '插件任务 $index',
              'cron_expr': '0 $index * * *',
              'manual_trigger_allowed': true,
            },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            theme: sakuraDesktopThemeData,
            home: const Scaffold(body: DesktopActivityPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final listFinder = find.byKey(const Key('activity-executable-jobs-list'));
      expect(listFinder, findsOneWidget);
      expect(find.byKey(const Key('activity-job-job_1')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('activity-job-job_8')),
        120,
        scrollable: find.descendant(
          of: listFinder,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const Key('activity-job-job_8')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('executable jobs dialog keeps the previous simple layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    final jobs = <Map<String, dynamic>>[
      <String, dynamic>{
        'task_key': 'auto_ok',
        'cli_help': '正常定时任务',
        'cron_expr': '0 2 * * *',
        'manual_trigger_allowed': true,
        'last_task_run': <String, dynamic>{
          'id': 601,
          'task_key': 'auto_ok',
          'task_name': '正常定时任务',
          'trigger_type': 'scheduled',
          'state': 'completed',
          'finished_at': '2026-08-10T11:00:00Z',
        },
      },
      <String, dynamic>{
        'task_key': 'auto_bad',
        'cli_help': '异常定时任务',
        'cron_expr': '0 3 * * *',
        'manual_trigger_allowed': true,
        'last_task_run': <String, dynamic>{
          'id': 602,
          'task_key': 'auto_bad',
          'task_name': '异常定时任务',
          'trigger_type': 'scheduled',
          'state': 'failed',
          'error_message': '执行失败',
          'finished_at': '2026-08-10T11:00:00Z',
        },
      },
      <String, dynamic>{
        'task_key': 'manual_only',
        'cli_help': '手动任务',
        'manual_trigger_allowed': true,
      },
    ];
    bundle.adapter.enqueueJson(method: 'GET', path: '/system/jobs', body: jobs);
    _enqueueActivityBootstrap(bundle, withJobs: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('activity-executable-jobs-card')),
      findsOneWidget,
    );
    expect(find.text('可执行任务'), findsOneWidget);
    expect(find.text('3 个任务'), findsOneWidget);
    expect(find.text('自动任务'), findsNothing);
    expect(find.textContaining('需关注'), findsNothing);

    // 打开弹层会顺带刷新任务定义。
    bundle.adapter.enqueueJson(method: 'GET', path: '/system/jobs', body: jobs);
    await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-job-auto_ok')), findsOneWidget);
    expect(find.byKey(const Key('activity-job-auto_bad')), findsOneWidget);
    expect(find.byKey(const Key('activity-job-manual_only')), findsOneWidget);
    expect(find.byKey(const Key('activity-job-plugin-filter')), findsOneWidget);
    expect(find.byKey(const Key('activity-job-tab-auto')), findsNothing);
    expect(find.byKey(const Key('activity-job-tab-manual')), findsNothing);
    expect(find.byKey(const Key('activity-job-status-all')), findsNothing);
    expect(
      find.byKey(const Key('activity-job-status-attention')),
      findsNothing,
    );
    final historyButton = find.byKey(const Key('activity-job-history-auto_ok'));
    expect(historyButton, findsOneWidget);
    expect(find.textContaining('近 24 小时'), findsNothing);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 701,
            'task_key': 'auto_ok',
            'task_name': '正常定时任务',
            'trigger_type': 'scheduled',
            'state': 'completed',
            'finished_at': '2026-08-10T11:00:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    await tester.tap(historyButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-history-sheet')), findsOneWidget);
    expect(find.byKey(const Key('activity-task-701')), findsOneWidget);
    final historyRequest = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/system/task-runs',
    );
    expect(historyRequest.uri.queryParameters['task_key'], 'auto_ok');
    expect(historyRequest.uri.queryParameters['scope'], 'all');
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent operations defaults to operations scope', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _enqueueActivityBootstrap(bundle);

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近操作'), findsOneWidget);
    expect(find.text('运行记录'), findsNothing);
    expect(
      bundle.adapter.requests
          .firstWhere((request) => request.path == '/system/activity/bootstrap')
          .uri
          .queryParameters['task_scope'],
      'operations',
    );
    expect(tester.takeException(), isNull);
  });
}

void _enqueueActivityBootstrap(TestApiBundle bundle, {bool withJobs = true}) {
  if (withJobs) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: const <dynamic>[],
    );
  }
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
      'unread_count': 0,
      'active_task_runs': const <dynamic>[],
      'task_runs': <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    },
  );
}

class _RetainedActivityCenter extends ActivityCenter {
  static _RetainedActivityCenter? instance;

  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  Future<ActivityCenterState> build() async {
    instance = this;
    return ActivityCenterState.initial.copyWith(
      initialized: true,
      hasMoreTasks: false,
      connectionState: ActivityConnectionState.polling,
    );
  }

  @override
  void pausePolling() {
    pauseCalls++;
    state = AsyncData(current.copyWith(connectionMessage: '已暂停'));
  }

  @override
  Future<void> resumePolling() async {
    resumeCalls++;
    state = AsyncData(current.copyWith(connectionMessage: '轮询中'));
  }
}
