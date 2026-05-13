import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';

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
    'getBootstrap maps snapshot payload and bootstrap query names',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/activity/bootstrap',
        body: <String, dynamic>{
          'latest_event_id': 321,
          'notifications': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 101,
                'category': 'reminder',
                'title': '有新的影片可以播放了',
                'content': '本次后台处理新增可播放影片 1 部：SSIS-123',
                'is_read': false,
                'archived': false,
                'created_at': '2026-03-26T09:10:00Z',
                'updated_at': '2026-03-26T09:10:00Z',
              },
            ],
            'page': 1,
            'page_size': 20,
            'total': 24,
          },
          'unread_count': 3,
          'active_task_runs': <Map<String, dynamic>>[
            <String, dynamic>{
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
            },
          ],
          'task_runs': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 201,
                'task_key': 'download_task_import',
                'task_name': '下载任务导入 201',
                'trigger_type': 'manual',
                'state': 'completed',
                'progress_current': 3,
                'progress_total': 3,
                'progress_text': '导入完成',
                'created_at': '2026-03-26T09:10:00Z',
                'updated_at': '2026-03-26T09:20:00Z',
              },
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          },
        },
      );

      final response = await bundle.activityApi.getBootstrap(
        notificationCategory: 'reminder',
        notificationArchived: false,
        taskState: 'running',
        taskKey: 'download_task_import',
        taskTriggerType: 'manual',
        taskSort: 'started_at:desc',
      );

      expect(response.latestEventId, 321);
      expect(response.notifications.items.single.id, 101);
      expect(response.unreadCount, 3);
      expect(response.activeTaskRuns.single.id, 88);
      expect(response.taskRuns.items.single.id, 201);
      final request = bundle.adapter.requests.single;
      expect(request.uri.queryParameters['notification_category'], 'reminder');
      expect(
        request.uri.queryParameters.containsKey('notification_level'),
        isFalse,
      );
      expect(request.uri.queryParameters['notification_archived'], 'false');
      expect(request.uri.queryParameters['task_state'], 'running');
      expect(request.uri.queryParameters['task_key'], 'download_task_import');
      expect(request.uri.queryParameters['task_trigger_type'], 'manual');
      expect(request.uri.queryParameters['task_sort'], 'started_at:desc');
    },
  );

  test('getNotifications maps filters and pagination', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/notifications',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'category': 'reminder',
            'title': '有新的影片可以播放了',
            'content': '本次后台处理新增可播放影片 1 部：SSIS-123',
            'is_read': false,
            'archived': false,
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:10:00Z',
          },
        ],
        'page': 2,
        'page_size': 10,
        'total': 24,
      },
    );

    final response = await bundle.activityApi.getNotifications(
      page: 2,
      pageSize: 10,
      category: 'reminder',
      archived: false,
    );

    expect(response.items.single.id, 101);
    expect(response.total, 24);
    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters['page_size'], '10');
    expect(request.uri.queryParameters['category'], 'reminder');
    expect(request.uri.queryParameters.containsKey('level'), isFalse);
    expect(request.uri.queryParameters['archived'], 'false');
  });

  test('getTaskRuns maps filters and sort', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
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
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final response = await bundle.activityApi.getTaskRuns(
      state: 'running',
      taskKey: 'download_task_import',
      triggerType: 'manual',
      sort: 'started_at:desc',
    );

    expect(response.items.single.taskKey, 'download_task_import');
    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters['state'], 'running');
    expect(request.uri.queryParameters['task_key'], 'download_task_import');
    expect(request.uri.queryParameters['trigger_type'], 'manual');
    expect(request.uri.queryParameters['sort'], 'started_at:desc');
  });

  test('getJobs maps system job metadata and last task run', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'ranking_sync',
          'log_name': 'ranking-sync',
          'cli_name': 'sync-rankings',
          'cli_help': '执行一次排行榜同步',
          'cron_setting': 'ranking_sync_cron',
          'cron_expr': '0 2 * * *',
          'manual_trigger_allowed': true,
          'last_task_run': <String, dynamic>{
            'id': 88,
            'task_key': 'ranking_sync',
            'task_name': '排行榜同步',
            'trigger_type': 'manual',
            'state': 'completed',
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:20:00Z',
          },
        },
        <String, dynamic>{
          'task_key': 'metadata_provider_license_renew',
          'log_name': 'metadata-provider-license-renew',
          'cli_name': 'renew-metadata-provider-license',
          'cli_help': '执行一次元数据授权续租',
          'cron_setting': 'metadata_provider_license_renew_cron',
          'cron_expr': '0 3 * * *',
          'manual_trigger_allowed': false,
          'last_task_run': null,
        },
      ],
    );

    final jobs = await bundle.activityApi.getJobs();

    expect(jobs, hasLength(2));
    expect(jobs.first.taskKey, 'ranking_sync');
    expect(jobs.first.manualTriggerAllowed, isTrue);
    expect(jobs.first.lastTaskRun?.id, 88);
    expect(jobs.last.manualTriggerAllowed, isFalse);
    expect(jobs.last.lastTaskRun, isNull);
    expect(bundle.adapter.hitCount('GET', '/system/jobs'), 1);
  });

  test('triggerJob maps manual job run endpoint', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/jobs/ranking_sync/run',
      body: <String, dynamic>{
        'task_run_id': 13,
        'task_key': 'ranking_sync',
        'state': 'pending',
      },
    );

    final response = await bundle.activityApi.triggerJob(
      taskKey: 'ranking_sync',
    );

    expect(response.taskRunId, 13);
    expect(response.taskKey, 'ranking_sync');
    expect(response.state, 'pending');
    expect(bundle.adapter.hitCount('POST', '/system/jobs/ranking_sync/run'), 1);
  });

  test('streamEvents maps notification and task payloads', () async {
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[
        'id: 121\n'
            'event: notification_created\n'
            'data: {"id":101,"category":"reminder","title":"有新的影片可以播放了","content":"ok","is_read":false,"archived":false}\n\n',
        'id: 122\n'
            'event: task_run_updated\n'
            'data: {"id":88,"task_key":"download_task_import","task_name":"下载任务导入 SSIS-123","trigger_type":"manual","state":"running","progress_current":2,"progress_total":3,"progress_text":"正在导入影片文件 SSIS-123","created_at":"2026-03-26T09:10:00Z","updated_at":"2026-03-26T09:11:00Z"}\n\n',
      ],
    );

    final events =
        await bundle.activityApi.streamEvents(afterEventId: 120).toList();

    expect(events[0].id, 121);
    expect(events[0].notification?.id, 101);
    expect(events[1].id, 122);
    expect(events[1].taskRun?.id, 88);
  });
}
