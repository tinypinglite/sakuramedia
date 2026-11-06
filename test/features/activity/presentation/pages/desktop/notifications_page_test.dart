import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/notifications_page.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/preview_helpers.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('header is the only filter failure feedback surface', (
    tester,
  ) async {
    _enqueueBootstrap(bundle);
    await pumpPreviewApp(
      tester,
      home: const DesktopNotificationsPage(),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);
    expect(find.byKey(const Key('activity-notification-5')), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/notifications',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopNotificationsPage)),
    );
    await tester.runAsync(
      () => container
          .read(notificationCenterProvider.notifier)
          .refreshNotifications(),
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('app-filter-update-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _enqueueBootstrap(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 5,
            'category': 'reminder',
            'title': '通知',
            'content': '内容',
            'is_read': false,
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:10:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
      'unread_count': 1,
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
