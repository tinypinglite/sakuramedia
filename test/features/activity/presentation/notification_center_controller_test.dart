import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T10:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  test('initialize loads notifications and connects stream from latest_event_id', () async {
    _enqueueBootstrap(
      bundle,
      latestEventId: 120,
      notifications: <Map<String, dynamic>>[_notificationJson(id: 101)],
      unreadCount: 3,
    );
    _enqueueStream(bundle);

    final controller = NotificationCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.notifications.single.id, 101);
    expect(controller.unreadCount, 3);
    expect(controller.connectionState, NotificationConnectionState.live);
    expect(
      bundle.adapter.requests
          .where((request) => request.path == '/system/events/stream')
          .single
          .uri
          .queryParameters['after_event_id'],
      '120',
    );
  });

  test('onNotificationDisplayed debounces and batch-marks displayed ids read', () async {
    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101),
        _notificationJson(id: 102),
      ],
      unreadCount: 2,
    );
    _enqueueStream(bundle);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/notifications/read',
      body: <String, dynamic>{'updated_count': 2, 'unread_count': 0},
    );

    final controller = NotificationCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    controller.onNotificationDisplayed(101);
    controller.onNotificationDisplayed(102);
    // 去抖窗口内重复触发不应产生第二次请求。
    controller.onNotificationDisplayed(101);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(bundle.adapter.hitCount('POST', '/system/notifications/read'), 1);
    final body =
        bundle.adapter.requests
            .firstWhere(
              (request) => request.path == '/system/notifications/read',
            )
            .body;
    expect(body, <String, dynamic>{
      'ids': <int>[101, 102],
    });
    expect(controller.notifications.every((item) => item.isRead), isTrue);
    expect(controller.unreadCount, 0);
  });

  test('onNotificationDisplayed ignores already-read notifications', () async {
    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101, isRead: true),
      ],
      unreadCount: 0,
    );
    _enqueueStream(bundle);

    final controller = NotificationCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    controller.onNotificationDisplayed(101);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(bundle.adapter.hitCount('POST', '/system/notifications/read'), 0);
  });

  test('markAllRead posts read-all, marks all read and zeroes the badge', () async {
    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101),
        _notificationJson(id: 102),
      ],
      unreadCount: 2,
    );
    _enqueueStream(bundle);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/notifications/read-all',
      body: <String, dynamic>{'updated_count': 2, 'unread_count': 0},
    );

    final controller = NotificationCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.markAllRead();

    expect(
      bundle.adapter.hitCount('POST', '/system/notifications/read-all'),
      1,
    );
    expect(controller.notifications.every((item) => item.isRead), isTrue);
    expect(controller.unreadCount, 0);
  });

  test('failed batch read rolls notifications back to unread', () async {
    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[_notificationJson(id: 101)],
      unreadCount: 1,
    );
    _enqueueStream(bundle);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/notifications/read',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    final controller = NotificationCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    controller.onNotificationDisplayed(101);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(bundle.adapter.hitCount('POST', '/system/notifications/read'), 1);
    expect(controller.notifications.single.isRead, isFalse);
  });

  test('SSE notifications_read marks ids read and refreshes unread count', () async {
    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101),
        _notificationJson(id: 102),
      ],
      unreadCount: 2,
    );
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[
        'id: 121\n'
            'event: notifications_read\n'
            'data: {"ids":[101],"unread_count":1}\n\n',
      ],
      keepOpen: true,
    );

    final controller = NotificationCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(
      controller.notifications.firstWhere((item) => item.id == 101).isRead,
      isTrue,
    );
    expect(
      controller.notifications.firstWhere((item) => item.id == 102).isRead,
      isFalse,
    );
    expect(controller.unreadCount, 1);
  });

  test('SSE notifications_read_all marks all read and zeroes the badge', () async {
    _enqueueBootstrap(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101),
        _notificationJson(id: 102),
      ],
      unreadCount: 2,
    );
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[
        'id: 121\n'
            'event: notifications_read_all\n'
            'data: {"unread_count":0}\n\n',
      ],
      keepOpen: true,
    );

    final controller = NotificationCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.notifications.every((item) => item.isRead), isTrue);
    expect(controller.unreadCount, 0);
  });
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
        'total': notifications.length,
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
  bool isRead = false,
}) {
  return <String, dynamic>{
    'id': id,
    'category': category,
    'title': '通知 $id',
    'content': '通知内容 $id',
    'is_read': isRead,
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:10:00Z',
  };
}
