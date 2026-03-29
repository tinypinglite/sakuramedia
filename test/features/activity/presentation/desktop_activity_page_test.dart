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
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop activity page hides read UI and still switches tabs', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101, isRead: true, relatedTaskRunId: 88),
      ],
      unreadCount: 1,
      activeTasks: <Map<String, dynamic>>[_taskJson(id: 88)],
      taskRuns: <Map<String, dynamic>>[_taskJson(id: 88)],
    );

    await _pumpActivityPage(tester, bundle: bundle);

    expect(find.byKey(const Key('desktop-activity-page')), findsOneWidget);
    expect(
      find.byKey(const Key('activity-notifications-unread-count')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('activity-notification-read-filter')),
      findsNothing,
    );
    expect(find.text('已读'), findsNothing);
    expect(find.text('未读 1 条'), findsNothing);

    await tester.tap(find.byKey(const Key('activity-tab-tasks')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-tasks-tab')), findsOneWidget);
    expect(find.byKey(const Key('activity-task-88')), findsNWidgets(2));
  });

  testWidgets('switching to shorter task tab shrinks page scroll extent', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester, size: const Size(1440, 720));
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      notifications: List<Map<String, dynamic>>.generate(
        20,
        (index) => _notificationJson(
          id: index + 1,
          title: '通知 ${index + 1}',
          content: '这是用于制造更长通知列表的内容 ${index + 1}',
          isRead: true,
        ),
      ),
      taskRuns: <Map<String, dynamic>>[
        _taskJson(id: 201, taskName: '历史任务 201', state: 'completed'),
      ],
    );

    await _pumpActivityPage(tester, bundle: bundle);

    final notificationsExtent = _pageMaxScrollExtent(tester);
    expect(notificationsExtent, greaterThan(0));

    await tester.tap(find.byKey(const Key('activity-tab-tasks')));
    await tester.pumpAndSettle();

    final tasksExtent = _pageMaxScrollExtent(tester);
    expect(tasksExtent, lessThan(notificationsExtent));
  });

  testWidgets(
    'notification filter shows adaptive spinner immediately and keeps current content',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, category: 'reminder', title: '提醒通知'),
        ],
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/system/notifications',
        responder: (_, __) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return _jsonResponseBody(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              _notificationJson(id: 202, category: 'exception', title: '异常通知'),
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          });
        },
      );

      await _pumpActivityPage(tester, bundle: bundle);

      await tester.tap(
        find.byKey(const Key('activity-notification-category-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('异常').last);
      await tester.pump();

      expect(
        find.byKey(const Key('activity-notification-filter-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activity-notification-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activity-notifications-tab')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('activity-notification-filter-loading')),
        findsNothing,
      );
      expect(find.byKey(const Key('activity-notification-101')), findsNothing);
      expect(
        find.byKey(const Key('activity-notification-202')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'notification category filter can switch back to first option and clears query',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, category: 'reminder', isRead: true),
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _notificationJson(id: 201, category: 'result', isRead: true),
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _notificationJson(id: 301, category: 'reminder', isRead: true),
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      await _pumpActivityPage(tester, bundle: bundle);

      await tester.tap(
        find.byKey(const Key('activity-notification-category-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('结果').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('activity-notification-category-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部分类').last);
      await tester.pumpAndSettle();

      final notificationRequests = bundle.adapter.requests
          .where((request) => request.path == '/system/notifications')
          .toList(growable: false);
      expect(notificationRequests, hasLength(3));
      expect(notificationRequests[1].uri.queryParameters['category'], 'result');
      expect(
        notificationRequests[2].uri.queryParameters.containsKey('category'),
        isFalse,
      );
      expect(
        find.byKey(const Key('activity-notification-301')),
        findsOneWidget,
      );
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
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, isRead: true),
        ],
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
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, isRead: true),
        ],
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
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, title: '提醒通知标题'),
        ],
        activeTasks: <Map<String, dynamic>>[
          _taskJson(id: 88, taskName: '活动任务标题'),
        ],
        taskRuns: <Map<String, dynamic>>[
          _taskJson(id: 201, taskName: '历史任务标题', state: 'completed'),
        ],
      );

      await _pumpActivityPage(tester, bundle: bundle);

      expect(_textStyleOf(tester, find.text('通知中心')).fontSize, 16);
      expect(_textStyleOf(tester, find.text('提醒通知标题')).fontSize, 14);
      expect(_defaultTextStyleOf(tester, find.text('全部分类')).fontSize, 13);

      await tester.tap(find.byKey(const Key('activity-tab-tasks')));
      await tester.pumpAndSettle();

      expect(_textStyleOf(tester, find.text('活动任务')).fontSize, 16);
      expect(_textStyleOf(tester, find.text('任务历史')).fontSize, 16);
      expect(_textStyleOf(tester, find.text('活动任务标题')).fontSize, 14);
      expect(_textStyleOf(tester, find.text('历史任务标题')).fontSize, 14);
      expect(_defaultTextStyleOf(tester, find.text('全部状态')).fontSize, 13);
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
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101, title: '提醒通知标题'),
      ],
      activeTasks: <Map<String, dynamic>>[
        _taskJson(id: 88, taskName: '活动任务标题'),
      ],
      taskRuns: <Map<String, dynamic>>[
        _taskJson(id: 201, taskName: '历史任务标题', state: 'completed'),
      ],
    );

    await _pumpActivityPage(tester, bundle: bundle);

    expect(find.text('通知中心'), findsOneWidget);
    expect(find.byType(AppContentCard), findsNothing);
    expect(find.byKey(const Key('activity-notification-101')), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-tab-tasks')));
    await tester.pumpAndSettle();

    expect(find.text('活动任务'), findsOneWidget);
    expect(find.text('任务历史'), findsOneWidget);
    expect(find.byType(AppContentCard), findsNothing);
    expect(find.byKey(const Key('activity-task-88')), findsOneWidget);
    expect(find.byKey(const Key('activity-task-201')), findsOneWidget);
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
        path: '/system/notifications',
        responder: (_, __) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _jsonResponseBody(<String, dynamic>{
            'items': <Map<String, dynamic>>[],
            'page': 1,
            'page_size': 20,
            'total': 0,
          });
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications/unread-count',
        body: <String, dynamic>{'unread_count': 0},
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs/active',
        body: const <Map<String, dynamic>>[],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 20,
          'total': 0,
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
      path: '/system/notifications',
      responder: (_, __) async => throw Exception('load failed'),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/notifications/unread-count',
      body: <String, dynamic>{'unread_count': 0},
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs/active',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );

    await _pumpActivityPage(tester, bundle: bundle);

    expect(find.text('活动中心'), findsOneWidget);
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byType(AppContentCard), findsNothing);
  });

  testWidgets(
    'notifications auto load more on scroll and keep retry footer on failure',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        notifications: List<Map<String, dynamic>>.generate(
          20,
          (index) => _notificationJson(
            id: index + 1,
            title: '通知 ${index + 1}',
            content: '通知内容 ${index + 1}',
            isRead: true,
          ),
        ),
        notificationTotal: 30,
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/system/notifications',
        responder: (_, __) async => throw Exception('load more failed'),
      );

      await _pumpActivityPage(tester, bundle: bundle);
      await _scrollToBottom(tester);

      expect(find.byKey(const Key('activity-notification-20')), findsOneWidget);
      expect(find.text('加载更多通知失败，请点击重试'), findsOneWidget);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': List<Map<String, dynamic>>.generate(
            10,
            (index) => _notificationJson(
              id: index + 21,
              title: '通知 ${index + 21}',
              content: '通知内容 ${index + 21}',
              isRead: true,
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

      expect(bundle.adapter.hitCount('GET', '/system/notifications'), 3);
      expect(find.byKey(const Key('activity-notification-30')), findsOneWidget);
      expect(find.text('加载更多通知失败，请点击重试'), findsNothing);
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
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, isRead: true),
        ],
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

      expect(bundle.adapter.hitCount('GET', '/system/task-runs'), 3);
      expect(find.byKey(const Key('activity-task-30')), findsOneWidget);
      expect(find.text('加载更多任务失败，请点击重试'), findsNothing);
    },
  );

  testWidgets('notifications auto fill viewport when first page is too short', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester, size: const Size(1440, 1400));
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(
          id: 101,
          title: '通知 101',
          content: '通知内容 101',
          isRead: true,
        ),
      ],
      notificationTotal: 2,
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/notifications',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _notificationJson(
            id: 102,
            title: '通知 102',
            content: '通知内容 102',
            isRead: true,
          ),
        ],
        'page': 2,
        'page_size': 20,
        'total': 2,
      },
    );

    await _pumpActivityPage(tester, bundle: bundle);

    expect(bundle.adapter.hitCount('GET', '/system/notifications'), 2);
    expect(find.byKey(const Key('activity-notification-102')), findsOneWidget);
  });

  testWidgets('notifications lazily build far items only after scroll', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester, size: const Size(1440, 720));
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      notifications: List<Map<String, dynamic>>.generate(
        200,
        (index) => _notificationJson(
          id: index + 1,
          title: '通知 ${index + 1}',
          content: '通知内容 ${index + 1}',
          isRead: true,
        ),
      ),
      notificationTotal: 200,
    );

    await _pumpActivityPage(tester, bundle: bundle);

    expect(find.byKey(const Key('activity-notification-1')), findsOneWidget);
    expect(find.byKey(const Key('activity-notification-200')), findsNothing);

    await _scrollToBottom(tester);

    expect(find.byKey(const Key('activity-notification-200')), findsOneWidget);
  });

  testWidgets(
    'notification cards share the same visual style for read and unread items',
    (WidgetTester tester) async {
      _setDesktopViewport(tester);
      final sessionStore = await _createSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);

      _enqueueActivityState(
        bundle,
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, isRead: false, title: '未读通知'),
          _notificationJson(id: 102, isRead: true, title: '已读通知'),
        ],
      );

      await _pumpActivityPage(tester, bundle: bundle);

      final unreadContainer = tester.widget<Container>(
        find.byKey(const Key('activity-notification-101')),
      );
      final readContainer = tester.widget<Container>(
        find.byKey(const Key('activity-notification-102')),
      );
      final unreadDecoration = unreadContainer.decoration! as BoxDecoration;
      final readDecoration = readContainer.decoration! as BoxDecoration;
      final unreadBorder = unreadDecoration.border! as Border;
      final readBorder = readDecoration.border! as Border;

      expect(readDecoration.color, unreadDecoration.color);
      expect(readBorder.top.color, unreadBorder.top.color);
      expect(find.text('已读'), findsNothing);
      expect(find.text('未读'), findsNothing);
    },
  );

  testWidgets('notification does not auto mark as read after staying visible', (
    WidgetTester tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueActivityState(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(
          id: 101,
          title: '有新的影片可以播放了',
          content: '本次后台处理新增可播放影片 1 部：SSIS-123',
          isRead: false,
        ),
      ],
      unreadCount: 1,
    );

    await _pumpActivityPage(tester, bundle: bundle);

    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('PATCH', '/system/notifications/101/read'),
      0,
    );
    expect(find.text('已读'), findsNothing);
    expect(find.text('未读'), findsNothing);
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

Future<void> _pumpActivityPage(
  WidgetTester tester, {
  required TestApiBundle bundle,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ActivityEventStreamClient>.value(
          value: bundle.activityEventStreamClient,
        ),
        Provider<ActivityApi>.value(value: bundle.activityApi),
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

double _pageMaxScrollExtent(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  return scrollable.position.maxScrollExtent;
}

void _enqueueActivityState(
  TestApiBundle bundle, {
  List<Map<String, dynamic>> notifications = const <Map<String, dynamic>>[],
  int? notificationTotal,
  int unreadCount = 0,
  List<Map<String, dynamic>> activeTasks = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> taskRuns = const <Map<String, dynamic>>[],
  int? taskRunTotal,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/notifications',
    body: <String, dynamic>{
      'items': notifications,
      'page': 1,
      'page_size': 20,
      'total': notificationTotal ?? notifications.length,
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/notifications/unread-count',
    body: <String, dynamic>{'unread_count': unreadCount},
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/task-runs/active',
    body: activeTasks,
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/task-runs',
    body: <String, dynamic>{
      'items': taskRuns,
      'page': 1,
      'page_size': 20,
      'total': taskRunTotal ?? taskRuns.length,
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
}

Map<String, dynamic> _notificationJson({
  required int id,
  String category = 'reminder',
  String level = 'info',
  String? title,
  String? content,
  bool isRead = false,
  bool archived = false,
  int? relatedTaskRunId,
}) {
  return <String, dynamic>{
    'id': id,
    'category': category,
    'level': level,
    'title': title ?? '通知 $id',
    'content': content ?? '通知内容 $id',
    'is_read': isRead,
    'archived': archived,
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:10:00Z',
    'related_task_run_id': relatedTaskRunId,
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

TextStyle _defaultTextStyleOf(WidgetTester tester, Finder finder) {
  return tester
      .widget<DefaultTextStyle>(
        find
            .ancestor(of: finder, matching: find.byType(DefaultTextStyle))
            .first,
      )
      .style;
}
