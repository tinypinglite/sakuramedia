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
    expect(find.byKey(const Key('activity-tasks-tab')), findsOneWidget);
    expect(find.byKey(const Key('activity-tab-download-tasks')), findsNothing);
    expect(find.byKey(const Key('activity-task-201')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-activity-task-filter-button')),
      findsOneWidget,
    );

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'new_plugin_job',
          'plugin_id': 'new_plugin',
          'cli_help': '新插件任务',
          'cron_expr': '0 4 * * *',
          'manual_trigger_allowed': true,
        },
      ],
    );
    await tester.tap(find.byKey(const Key('activity-jobs-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('新插件任务'), findsOneWidget);
    expect(
      bundle.adapter.requests.where((r) => r.path == '/system/jobs'),
      hasLength(2),
    );
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('mobile-activity-task-filter-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-activity-task-filter-drawer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-activity-task-state-filter')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
