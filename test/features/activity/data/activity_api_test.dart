import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  test('getBootstrap maps snapshot data without an event cursor', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: <String, dynamic>{
        'notifications': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 101,
              'category': 'reminder',
              'title': '有新的影片可以播放了',
              'content': 'ok',
              'event_type': 'media_ready',
              'dedupe_key': 'media:101',
              'resource_type': 'media',
              'resource_id': 8,
              'is_read': false,
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
        'unread_count': 3,
        'active_task_runs': <Map<String, dynamic>>[
          _taskRunJson(id: 88, state: 'running'),
        ],
        'task_runs': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _taskRunJson(id: 201, state: 'completed'),
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      },
    );

    final response = await bundle.activityApi.getBootstrap(
      notificationCategory: 'reminder',
      taskState: 'running',
      taskKey: 'download_task_import',
      taskTriggerType: 'manual',
      taskSort: 'started_at:desc',
      taskScope: 'operations',
    );

    final notification = response.notifications.items.single;
    expect(notification.eventType, 'media_ready');
    expect(notification.resourceId, 8);
    expect(response.unreadCount, 3);
    expect(response.activeTaskRuns.single.id, 88);
    expect(response.taskRuns.items.single.id, 201);
    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters['notification_category'], 'reminder');
    expect(request.uri.queryParameters['task_state'], 'running');
    expect(request.uri.queryParameters['task_key'], 'download_task_import');
    expect(request.uri.queryParameters['task_trigger_type'], 'manual');
    expect(request.uri.queryParameters['task_sort'], 'started_at:desc');
    expect(request.uri.queryParameters['task_scope'], 'operations');
  });

  test('getNotifications maps read filter and pagination', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/notifications',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'category': 'reminder',
            'title': 'title',
            'content': 'content',
            'is_read': true,
          },
        ],
        'page': 2,
        'page_size': 10,
        'total': 1,
      },
    );

    final response = await bundle.activityApi.getNotifications(
      page: 2,
      pageSize: 10,
      category: 'reminder',
      isRead: true,
    );

    expect(response.items.single.isRead, isTrue);
    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters['page_size'], '10');
    expect(request.uri.queryParameters['category'], 'reminder');
    expect(request.uri.queryParameters['is_read'], 'true');
  });

  test(
    'getTaskRuns is the polling endpoint for task progress and results',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              ..._taskRunJson(id: 42, state: 'completed'),
              'result_text': '导入完成',
              'result_summary': <String, dynamic>{'imported': 2},
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      final response = await bundle.activityApi.getTaskRuns(
        page: 1,
        pageSize: 20,
        state: 'completed',
        taskKey: 'media_import',
        triggerType: 'manual',
        sort: 'updated_at:desc',
        scope: 'all',
      );

      expect(response.items.single.resultSummary?['imported'], 2);
      expect(response.items.single.displaySummary(_zh), '导入完成');
      final request = bundle.adapter.requests.single;
      expect(request.uri.queryParameters['state'], 'completed');
      expect(request.uri.queryParameters['task_key'], 'media_import');
      expect(request.uri.queryParameters['trigger_type'], 'manual');
      expect(request.uri.queryParameters['sort'], 'updated_at:desc');
      expect(request.uri.queryParameters['scope'], 'all');
    },
  );

  test(
    'task run warnings parse defensively and drive attention flags',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              ..._taskRunJson(id: 51, state: 'completed'),
              'has_warning': true,
            },
            _taskRunJson(id: 52, state: 'completed'),
            _taskRunJson(id: 53, state: 'failed'),
          ],
          'page': 1,
          'page_size': 20,
          'total': 3,
        },
      );

      final response = await bundle.activityApi.getTaskRuns(
        scope: 'operations',
      );

      expect(response.items[0].hasWarning, isTrue);
      expect(response.items[0].needsAttention, isTrue);
      expect(response.items[1].hasWarning, isFalse);
      expect(response.items[1].needsAttention, isFalse);
      expect(response.items[2].needsAttention, isTrue);
      expect(
        bundle.adapter.requests.single.uri.queryParameters['scope'],
        'operations',
      );
    },
  );

  test('jobs expose schedule flags and ignore legacy stats', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'media_import',
          'cli_help': '执行一次媒体库导入',
          'cron_expr': '0 3 * * *',
          'manual_trigger_allowed': true,
          'recent_run_count': 24,
          'recent_failure_count': 2,
        },
        <String, dynamic>{
          'task_key': 'manual_only',
          'cli_help': '手动任务',
          'manual_trigger_allowed': true,
        },
      ],
    );

    final jobs = await bundle.activityApi.getJobs();

    expect(jobs.first.isScheduled, isTrue);
    expect(jobs.last.isScheduled, isFalse);
  });

  test('getActiveTaskRuns maps the complete active task snapshot', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs/active',
      body: <Map<String, dynamic>>[
        _taskRunJson(id: 88, state: 'running', progressCurrent: 7),
      ],
    );

    final response = await bundle.activityApi.getActiveTaskRuns();

    expect(response.single.id, 88);
    expect(response.single.progressCurrent, 7);
    expect(bundle.adapter.requests.single.path, '/system/task-runs/active');
  });

  test(
    'media transfer task displays structured counts instead of wire keys',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              ..._taskRunJson(id: 43, state: 'completed'),
              'task_key': 'media_storage_transfer',
              'result_text': 'transferred_count=2 skipped_count=1',
              'result_summary': <String, dynamic>{
                'transferred_count': 2,
                'skipped_count': 1,
                'cleanup_incomplete_count': 1,
                'unexecuted_media_ids': <int>[99],
              },
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      final response = await bundle.activityApi.getTaskRuns();

      expect(
        response.items.single.displaySummary(_zh),
        '已迁移 2 项 · 已跳过 1 项 · 源文件待确认 1 项 · 未执行 1 项',
      );
    },
  );

  test(
    'batch operation task displays succeeded/failed counts instead of wire keys',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              ..._taskRunJson(id: 44, state: 'completed'),
              'task_key': 'batch_operation',
              'result_text':
                  'operation=media_delete total=3 succeeded_count=2 failed_count=1',
              'result_summary': <String, dynamic>{
                'operation': 'media_delete',
                'total': 3,
                'succeeded_count': 2,
                'failed_count': 1,
              },
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      final response = await bundle.activityApi.getTaskRuns();

      expect(response.items.single.displaySummary(_zh), '成功 2 项 · 失败 1 项');
    },
  );

  test(
    'batch operation task without failures only shows the succeeded count',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/task-runs',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              ..._taskRunJson(id: 45, state: 'completed'),
              'task_key': 'batch_operation',
              'result_summary': <String, dynamic>{
                'operation': 'media_delete',
                'total': 2,
                'succeeded_count': 2,
                'failed_count': 0,
              },
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      final response = await bundle.activityApi.getTaskRuns();

      expect(response.items.single.displaySummary(_zh), '成功 2 项');
    },
  );

  test('notification mutations use the current response contract', () async {
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/system/notifications',
      body: <String, dynamic>{'updated_count': 2, 'unread_count': 4},
    );
    final result = await bundle.activityApi.markNotificationsRead(<int>[1, 2]);
    expect(result.updatedCount, 2);
    expect(result.unreadCount, 4);
    expect(bundle.adapter.requests.single.body, <String, dynamic>{
      'ids': <int>[1, 2],
      'is_read': true,
    });

    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/system/notifications',
      body: <String, dynamic>{'updated_count': 4, 'unread_count': 0},
    );
    final all = await bundle.activityApi.markAllNotificationsRead();
    expect(all.updatedCount, 4);
    expect(all.unreadCount, 0);
  });
}

Map<String, dynamic> _taskRunJson({
  required int id,
  required String state,
  int? progressCurrent,
}) => <String, dynamic>{
  'id': id,
  'task_key': 'media_import',
  'task_name': '媒体导入',
  'trigger_type': 'manual',
  'state': state,
  'progress_current': progressCurrent ?? (state == 'completed' ? 2 : 1),
  'progress_total': 2,
  'progress_text': '处理中',
  'created_at': '2026-03-26T09:10:00Z',
  'updated_at': '2026-03-26T09:11:00Z',
};

final _zh = AppLocalizationsZh();
