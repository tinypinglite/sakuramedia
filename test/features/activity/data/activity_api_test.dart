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

  test('getNotifications maps filters and pagination', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/notifications',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'category': 'reminder',
            'level': 'info',
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
      level: 'info',
      archived: false,
    );

    expect(response.items.single.id, 101);
    expect(response.total, 24);
    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters['page_size'], '10');
    expect(request.uri.queryParameters['category'], 'reminder');
    expect(request.uri.queryParameters['level'], 'info');
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

  test('streamEvents maps notification and task payloads', () async {
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[
        'id: 121\n'
            'event: notification_created\n'
            'data: {"id":101,"category":"reminder","level":"info","title":"有新的影片可以播放了","content":"ok","is_read":false,"archived":false}\n\n',
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
