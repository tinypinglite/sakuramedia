import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/pages/mobile/activity_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('renders task center at mobile width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: <String, dynamic>{
        'notifications': <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
        },
        'unread_count': 0,
        'active_task_runs': const <Map<String, dynamic>>[],
        'task_runs': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            for (var index = 1; index <= 20; index++)
              <String, dynamic>{
                'id': 200 + index,
                'task_key': 'media_import',
                'task_name': '媒体导入 $index',
                'trigger_type': 'manual',
                'state': 'running',
                'progress_current': 1,
                'progress_total': 2,
                'progress_text': '处理中',
              },
          ],
          'page': 1,
          'page_size': 20,
          'total': 20,
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
          theme: sakuraMobileThemeData,
          home: const AppPlatformScope(
            platform: AppPlatform.mobile,
            child: Scaffold(body: MobileActivityPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-activity-page')), findsOneWidget);
    expect(find.byKey(const Key('activity-tabs')), findsOneWidget);
    expect(find.byKey(const Key('activity-tab-overview')), findsOneWidget);
    expect(find.byKey(const Key('activity-tab-history')), findsOneWidget);
    expect(find.byKey(const Key('activity-tab-download-tasks')), findsNothing);
    expect(find.byKey(const Key('activity-task-201')), findsNothing);
    expect(
      find.byKey(const Key('activity-executable-jobs-toolbar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('activity-tab-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-task-201')), findsOneWidget);
    final filterButton = find.byKey(
      const Key('mobile-activity-task-filter-button'),
    );
    expect(filterButton, findsOneWidget);
    expect(
      find.descendant(of: filterButton, matching: find.text('全部任务')),
      findsOneWidget,
    );

    final tabTop = tester.getTopLeft(find.byKey(const Key('activity-tabs')));
    final filterTop = tester.getTopLeft(
      find.byKey(const Key('activity-history-filter-header')),
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('activity-history-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.byKey(const Key('activity-history-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.getTopLeft(find.byKey(const Key('activity-tabs'))), tabTop);
    expect(
      tester.getTopLeft(
        find.byKey(const Key('activity-history-filter-header')),
      ),
      filterTop,
    );

    await tester.tap(filterButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-activity-task-filter-drawer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-activity-task-state-filter')),
      findsOneWidget,
    );

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
    await tester.tap(
      find.byKey(const Key('mobile-activity-task-state-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('失败').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final filteredRequest = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/system/task-runs',
    );
    expect(filteredRequest.uri.queryParameters['state'], 'failed');
    expect(
      find.descendant(of: filterButton, matching: find.text('失败')),
      findsOneWidget,
    );

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
    await tester.tap(find.text('重置'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final resetRequest = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/system/task-runs',
    );
    expect(resetRequest.uri.queryParameters.containsKey('state'), isFalse);
    expect(
      find.descendant(of: filterButton, matching: find.text('全部任务')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview uses a single column with long job descriptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
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
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'download_task_sync',
          'cli_help': '同步所有下载器的任务状态并更新下载进度',
          'cron_expr': '*/5 * * * *',
          'manual_trigger_allowed': true,
          'last_task_run': <String, dynamic>{
            'id': 903,
            'task_key': 'download_task_sync',
            'task_name': '同步所有下载器的任务状态并更新下载进度',
            'trigger_type': 'scheduled',
            'state': 'failed',
            'error_message': '下载器连接失败',
            'finished_at': '2026-08-10T11:00:00Z',
          },
        },
        <String, dynamic>{
          'task_key': 'media_file_scan',
          'cli_help': '执行一次很长的媒体文件扫描任务，用于验证移动端卡片标题换行与布局稳定性',
          'cron_expr': '0 4 * * *',
          'manual_trigger_allowed': true,
        },
      ],
    );
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
          theme: sakuraMobileThemeData,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const AppPlatformScope(
            platform: AppPlatform.mobile,
            child: Scaffold(body: MobileActivityPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstCard = tester.getTopLeft(
      find.byKey(const Key('activity-job-overview-download_task_sync')),
    );
    final secondCard = tester.getTopLeft(
      find.byKey(const Key('activity-job-overview-media_file_scan')),
    );
    expect(firstCard.dx, closeTo(secondCard.dx, 1));
    expect(secondCard.dy, greaterThan(firstCard.dy));
    expect(find.text('常用任务'), findsOneWidget);
    expect(find.text('系统任务'), findsNothing);
    expect(find.text('执行一次很长的媒体文件扫描任务，用于验证移动端卡片标题换行与布局稳定性'), findsOneWidget);
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
