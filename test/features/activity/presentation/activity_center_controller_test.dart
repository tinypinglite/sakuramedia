import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/activity_center_controller.dart';

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

  test(
    'initialize loads bootstrap state and connects stream from latest_event_id',
    () async {
      _enqueueInitialActivityState(bundle, latestEventId: 120);
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: const <String>[
          'id: 121\n'
              'event: notification_created\n'
              'data: {"id":101,"category":"reminder","title":"有新的影片可以播放了","content":"本次后台处理新增可播放影片 1 部：SSIS-123","is_read":false,"archived":false,"related_task_run_id":88}\n\n',
        ],
        keepOpen: true,
      );

      final controller = ActivityCenterController(
        activityApi: bundle.activityApi,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.notifications, hasLength(1));
      expect(controller.notifications.single.id, 101);
      expect(controller.unreadCount, 1);
      expect(controller.connectionState, ActivityConnectionState.live);
      expect(bundle.adapter.hitCount('GET', '/system/activity/bootstrap'), 1);
      expect(bundle.adapter.hitCount('GET', '/system/events/stream'), 1);
      expect(controller.notificationFilter.category, 'reminder');
      expect(
        bundle.adapter.requests
            .where((request) => request.path == '/system/activity/bootstrap')
            .single
            .uri
            .queryParameters['notification_category'],
        'reminder',
      );
      expect(
        bundle.adapter.requests
            .where((request) => request.path == '/system/events/stream')
            .single
            .uri
            .queryParameters['after_event_id'],
        '120',
      );
    },
  );

  test('markNotificationRead updates unread count', () async {
    _enqueueInitialActivityState(
      bundle,
      notifications: <Map<String, dynamic>>[
        _notificationJson(id: 101, isRead: false),
      ],
      unreadCount: 1,
    );
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[],
      keepOpen: true,
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/system/notifications/101/read',
      body: <String, dynamic>{'id': 101, 'is_read': true},
    );

    final controller = ActivityCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.markNotificationRead(101);
    expect(controller.unreadCount, 0);
    expect(controller.notifications.single.isRead, isTrue);
  });

  test(
    'task_run_updated removes completed task from active list and keeps history',
    () async {
      _enqueueInitialActivityState(
        bundle,
        activeTasks: <Map<String, dynamic>>[_runningTaskJson()],
        taskRuns: <Map<String, dynamic>>[_runningTaskJson()],
      );
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: const <String>[
          'id: 122\n'
              'event: task_run_updated\n'
              'data: {"id":88,"task_key":"download_task_import","task_name":"下载任务导入 SSIS-123","trigger_type":"manual","state":"completed","progress_current":3,"progress_total":3,"progress_text":"导入完成","result_text":"新增影片 1 部","created_at":"2026-03-26T09:10:00Z","updated_at":"2026-03-26T09:20:00Z","started_at":"2026-03-26T09:10:00Z","finished_at":"2026-03-26T09:20:00Z"}\n\n',
        ],
        keepOpen: true,
      );

      final controller = ActivityCenterController(
        activityApi: bundle.activityApi,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.activeTaskRuns, isEmpty);
      expect(controller.taskRuns, hasLength(1));
      expect(controller.taskRuns.single.state, 'completed');
    },
  );

  test(
    'applyNotificationFilter refreshes only notifications and keeps stream connection',
    () async {
      _enqueueInitialActivityState(
        bundle,
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, category: 'reminder'),
        ],
        activeTasks: <Map<String, dynamic>>[_runningTaskJson()],
        taskRuns: <Map<String, dynamic>>[_completedTaskJson(id: 201)],
      );
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: const <String>[],
        keepOpen: true,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _notificationJson(id: 202, category: 'error'),
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      final controller = ActivityCenterController(
        activityApi: bundle.activityApi,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.applyNotificationFilter(
        controller.notificationFilter.copyWith(category: 'error'),
      );

      expect(controller.isRefreshingNotifications, isFalse);
      expect(controller.notifications.single.id, 202);
      expect(controller.activeTaskRuns.single.id, 88);
      expect(controller.taskRuns.single.id, 201);
      expect(bundle.adapter.hitCount('GET', '/system/activity/bootstrap'), 1);
      expect(bundle.adapter.hitCount('GET', '/system/events/stream'), 1);
      expect(
        bundle.adapter.requests
            .where((request) => request.path == '/system/notifications')
            .last
            .uri
            .queryParameters['category'],
        'error',
      );
    },
  );

  test(
    'applyTaskFilter refreshes only task history and keeps live stream open',
    () async {
      _enqueueInitialActivityState(
        bundle,
        notifications: <Map<String, dynamic>>[
          _notificationJson(id: 101, category: 'reminder'),
        ],
        activeTasks: <Map<String, dynamic>>[_runningTaskJson()],
        taskRuns: <Map<String, dynamic>>[_completedTaskJson(id: 201)],
      );
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: const <String>[],
        keepOpen: true,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[_failedTaskJson(id: 301)],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      final controller = ActivityCenterController(
        activityApi: bundle.activityApi,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.applyTaskFilter(
        controller.taskFilter.copyWith(state: 'failed'),
      );

      expect(controller.isRefreshingTaskHistory, isFalse);
      expect(controller.notifications.single.id, 101);
      expect(controller.activeTaskRuns.single.id, 88);
      expect(controller.taskRuns.single.id, 301);
      expect(bundle.adapter.hitCount('GET', '/system/activity/bootstrap'), 1);
      expect(bundle.adapter.hitCount('GET', '/system/events/stream'), 1);
      expect(
        bundle.adapter.requests
            .where((request) => request.path == '/system/task-runs')
            .last
            .uri
            .queryParameters['state'],
        'failed',
      );
    },
  );

  test(
    'last notification filter response wins when requests resolve out of order',
    () async {
      _enqueueInitialActivityState(bundle);
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: const <String>[],
        keepOpen: true,
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/system/notifications',
        responder: (_, __) async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return _jsonResponseBody(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              _notificationJson(id: 201, category: 'info'),
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          });
        },
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/system/notifications',
        responder: (_, __) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return _jsonResponseBody(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              _notificationJson(id: 202, category: 'error'),
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          });
        },
      );

      final controller = ActivityCenterController(
        activityApi: bundle.activityApi,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      final first = controller.applyNotificationFilter(
        controller.notificationFilter.copyWith(category: 'info'),
      );
      final second = controller.applyNotificationFilter(
        controller.notificationFilter.copyWith(category: 'error'),
      );
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(controller.notificationFilter.category, 'error');
      expect(controller.notifications.single.id, 202);
      expect(bundle.adapter.hitCount('GET', '/system/events/stream'), 1);
    },
  );

  test('heartbeat keeps live state without redundant notifications', () async {
    _enqueueInitialActivityState(bundle);
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunkInterval: const Duration(milliseconds: 20),
      chunks: const <String>[
        'id: 121\n'
            'event: heartbeat\n'
            'data: {}\n\n',
        'id: 122\n'
            'event: heartbeat\n'
            'data: {}\n\n',
      ],
      keepOpen: true,
    );

    final controller = ActivityCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    var listenerCallCount = 0;
    controller.addListener(() {
      listenerCallCount += 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 70));

    expect(controller.connectionState, ActivityConnectionState.live);
    expect(controller.connectionMessage, '实时连接中');
    expect(listenerCallCount, 0);
  });
}

void _enqueueInitialActivityState(
  TestApiBundle bundle, {
  int latestEventId = 120,
  List<Map<String, dynamic>> notifications = const <Map<String, dynamic>>[],
  int unreadCount = 0,
  List<Map<String, dynamic>> activeTasks = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> taskRuns = const <Map<String, dynamic>>[],
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
      'active_task_runs': activeTasks,
      'task_runs': <String, dynamic>{
        'items': taskRuns,
        'page': 1,
        'page_size': 20,
        'total': taskRuns.length,
      },
    },
  );
}

Map<String, dynamic> _notificationJson({
  required int id,
  String category = 'reminder',
  bool isRead = false,
  bool archived = false,
}) {
  return <String, dynamic>{
    'id': id,
    'category': category,
    'title': '通知 $id',
    'content': '通知内容 $id',
    'is_read': isRead,
    'archived': archived,
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:10:00Z',
  };
}

Map<String, dynamic> _runningTaskJson() {
  return <String, dynamic>{
    'id': 88,
    'task_key': 'download_task_import',
    'task_name': '下载任务导入 SSIS-123',
    'trigger_type': 'manual',
    'state': 'running',
    'progress_current': 1,
    'progress_total': 3,
    'progress_text': '正在导入影片文件 SSIS-123',
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:11:00Z',
    'started_at': '2026-03-26T09:10:00Z',
    'finished_at': null,
  };
}

Map<String, dynamic> _completedTaskJson({required int id}) {
  return <String, dynamic>{
    'id': id,
    'task_key': 'download_task_import',
    'task_name': '下载任务导入 $id',
    'trigger_type': 'manual',
    'state': 'completed',
    'progress_current': 3,
    'progress_total': 3,
    'progress_text': '导入完成',
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:20:00Z',
    'started_at': '2026-03-26T09:10:00Z',
    'finished_at': '2026-03-26T09:20:00Z',
  };
}

Map<String, dynamic> _failedTaskJson({required int id}) {
  return <String, dynamic>{
    'id': id,
    'task_key': 'download_task_sync',
    'task_name': '下载任务失败 $id',
    'trigger_type': 'manual',
    'state': 'failed',
    'progress_current': 1,
    'progress_total': 3,
    'progress_text': '同步失败',
    'created_at': '2026-03-26T09:10:00Z',
    'updated_at': '2026-03-26T09:20:00Z',
    'started_at': '2026-03-26T09:10:00Z',
    'finished_at': '2026-03-26T09:20:00Z',
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
