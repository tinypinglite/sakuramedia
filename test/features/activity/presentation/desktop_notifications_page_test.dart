import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/desktop_notifications_page.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders notification list and category filter', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
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

    expect(find.byKey(const Key('desktop-notifications-page')), findsOneWidget);
    expect(find.byKey(const Key('notification-category-filter')), findsOneWidget);
    expect(find.byKey(const Key('activity-notification-101')), findsOneWidget);
    expect(find.text('提醒通知'), findsOneWidget);
    // 分类筛选默认「全部」。
    expect(find.text('全部'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no notifications', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueBootstrap(bundle);
    _enqueueStream(bundle);

    await _pumpNotificationsPage(tester, bundle: bundle);

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('当前筛选下暂无通知'), findsOneWidget);
  });

  testWidgets(
    'auto-marks displayed notifications read without any manual control',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
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
        path: '/system/notifications/read',
        body: <String, dynamic>{'updated_count': 2, 'unread_count': 0},
      );

      await _pumpNotificationsPage(tester, bundle: bundle);

      // 展示后约 400ms 去抖触发一次批量已读。
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/system/notifications/read'), 1);
      final body =
          bundle.adapter.requests
              .firstWhere(
                (request) => request.path == '/system/notifications/read',
              )
              .body as Map<String, dynamic>;
      expect((body['ids'] as List<dynamic>).contains(101), isTrue);
      expect((body['ids'] as List<dynamic>).contains(102), isTrue);

      // 无逐条「标记已读」按钮、无多选——已读是无感的（全部已读是全局便捷入口）。
      expect(find.text('标记已读'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    },
  );

  testWidgets('全部已读 button clears all via read-all', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
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
      find.byKey(const Key('notifications-mark-all-read')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('notifications-mark-all-read')));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('POST', '/system/notifications/read-all'),
      1,
    );
    // 走的是一键全部已读，而非逐条批量已读。
    expect(bundle.adapter.hitCount('POST', '/system/notifications/read'), 0);
  });

  testWidgets('auto loads more notifications on scroll', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester, size: const Size(1440, 720));
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueBootstrap(
      bundle,
      notifications: List<Map<String, dynamic>>.generate(
        20,
        (index) => _notificationJson(
          id: index + 1,
          title: '通知 ${index + 1}',
          isRead: true,
        ),
      ),
      notificationTotal: 30,
    );
    _enqueueStream(bundle);
    // cacheExtent:0 下视口填充可能多触发一次加载，预备两份分页响应保证幂等。
    for (var i = 0; i < 2; i++) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': List<Map<String, dynamic>>.generate(
            10,
            (index) => _notificationJson(
              id: index + 21,
              title: '通知 ${index + 21}',
              isRead: true,
            ),
          ),
          'page': 2,
          'page_size': 20,
          'total': 30,
        },
      );
    }

    await _pumpNotificationsPage(tester, bundle: bundle);
    // 首次滚到底触发加载更多；新项追加到列表底部后再滚一次使其进入视口。
    await _scrollToBottom(tester);
    await _scrollToBottom(tester);

    expect(
      bundle.adapter.hitCount('GET', '/system/notifications'),
      greaterThanOrEqualTo(1),
    );
    expect(find.byKey(const Key('activity-notification-30')), findsOneWidget);
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
  bool settle = true,
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
          home: const Scaffold(body: DesktopNotificationsPage()),
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
