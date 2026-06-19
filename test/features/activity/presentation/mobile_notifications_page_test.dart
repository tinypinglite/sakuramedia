import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/mobile_notifications_page.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders notification list with 全部/未读 segments', (
    WidgetTester tester,
  ) async {
    _setMobileViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101, title: '提醒通知', isRead: true),
      ],
      unreadCount: 0,
    );
    _enqueueStream(bundle);

    await _pumpNotificationsPage(tester, bundle: bundle);

    expect(find.byKey(const Key('mobile-notifications-page')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-notifications-segments')),
      findsOneWidget,
    );
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('未读'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-activity-notification-101')),
      findsOneWidget,
    );
    expect(find.text('提醒通知'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no notifications', (
    WidgetTester tester,
  ) async {
    _setMobileViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueBootstrap(bundle);
    _enqueueStream(bundle);

    await _pumpNotificationsPage(tester, bundle: bundle);

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('暂无消息'), findsOneWidget);
  });

  testWidgets('未读 segment filters to unread snapshot', (
    WidgetTester tester,
  ) async {
    _setMobileViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101, title: '未读通知', isRead: false),
        _notificationJson(id: 102, title: '已读通知', isRead: true),
      ],
      unreadCount: 1,
    );
    _enqueueStream(bundle);

    await _pumpNotificationsPage(tester, bundle: bundle);

    // 「全部」段：两条都在。
    expect(
      find.byKey(const Key('mobile-activity-notification-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-activity-notification-102')),
      findsOneWidget,
    );

    // 切到「未读」段：仅快照里的未读项保留，已读项隐藏。
    await tester.tap(find.text('未读'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-activity-notification-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-activity-notification-102')),
      findsNothing,
    );
  });

  testWidgets('全部已读 button clears all via read-all', (
    WidgetTester tester,
  ) async {
    _setMobileViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101, isRead: false),
        _notificationJson(id: 102, isRead: false),
      ],
      unreadCount: 2,
    );
    _enqueueStream(bundle);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/notifications/read-all',
      body: <String, dynamic>{'updated_count': 2, 'unread_count': 0},
    );

    await _pumpNotificationsPage(tester, bundle: bundle);

    expect(
      find.byKey(const Key('mobile-notifications-mark-all-read')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mobile-notifications-mark-all-read')));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('POST', '/system/notifications/read-all'),
      1,
    );
    // 走的是一键全部已读，而非逐条批量已读。
    expect(bundle.adapter.hitCount('POST', '/system/notifications/read'), 0);
  });
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

Future<void> _pumpNotificationsPage(
  WidgetTester tester, {
  required TestApiBundle bundle,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationCenterController>(
          create:
              (_) =>
                  NotificationCenterController(activityApi: bundle.activityApi),
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileNotificationsPage()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void _setMobileViewport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _enqueueStream(TestApiBundle bundle) {
  bundle.adapter.enqueueSse(
    method: 'GET',
    path: '/system/events/stream',
    chunks: const <String>[],
    keepOpen: true,
  );
}

void _enqueueBootstrap(
  TestApiBundle bundle, {
  int latestEventId = 120,
  List<Map<String, dynamic>> notifications = const <Map<String, dynamic>>[],
  int? notificationTotal,
  int unreadCount = 0,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'latest_event_id': latestEventId,
      'notifications': <String, dynamic>{
        'items': notifications,
        'page': 1,
        'page_size': 20,
        'total': notificationTotal ?? notifications.length,
      },
      'unread_count': unreadCount,
      'active_task_runs': const <Map<String, dynamic>>[],
      'task_runs': const <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    },
  );
}

Map<String, dynamic> _notificationJson({
  required int id,
  String category = 'reminder',
  String? title,
  bool isRead = false,
}) {
  return <String, dynamic>{
    'id': id,
    'category': category,
    'title': title ?? '通知 $id',
    'content': '通知内容 $id',
    'is_read': isRead,
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:10:00Z',
  };
}
