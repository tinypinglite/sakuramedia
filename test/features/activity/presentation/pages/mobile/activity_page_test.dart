import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/pages/mobile/activity_page.dart';
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
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-tasks',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 401,
            'client_id': 1,
            'movie_number': 'ABC-001',
            'name': 'ABC-001',
            'info_hash': 'hash-401',
            'save_path': '/downloads',
            'progress': 0.5,
            'download_state': 'downloading',
            'import_status': 'pending',
            'import_status_label': '等待导入',
            'created_at': '2026-08-10T12:00:00Z',
            'updated_at': '2026-08-10T12:00:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
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
    expect(find.byKey(const Key('activity-tab-tasks')), findsOneWidget);
    expect(
      find.byKey(const Key('activity-tab-download-tasks')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activity-task-201')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-activity-task-filter-button')),
      findsOneWidget,
    );

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
    await tester.tap(find.byKey(const Key('activity-tab-download-tasks')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('download-task-401')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-download-filter-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mobile-download-filter-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-download-filter-drawer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-download-filter-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
