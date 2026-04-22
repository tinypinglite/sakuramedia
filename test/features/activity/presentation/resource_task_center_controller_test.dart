import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_center_controller.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_filter_state.dart';

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
      expiresAt: DateTime.parse('2030-01-01T00:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  test('initialize 加载 definitions 并默认选中第一个任务 + 拉取第一页记录', () async {
    _enqueueDefinitions(bundle);
    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      total: 1,
      items: <Map<String, dynamic>>[_recordJson(id: 1001)],
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.initialized, isTrue);
    expect(controller.definitions, hasLength(2));
    expect(controller.activeTaskKey, 'movie_desc_sync');
    expect(controller.activeDefinition?.displayName, '影片描述回填');
    expect(controller.activeRecords, hasLength(1));
    expect(controller.activeRecords.single.resourceId, 1001);
    expect(controller.hasLoadedActiveRecords, isTrue);
    expect(controller.isLoadingRecords, isFalse);
    expect(controller.hasMoreRecords, isFalse);
    expect(controller.initialErrorMessage, isNull);
    expect(controller.recordsLoadErrorMessage, isNull);
    expect(
      bundle.adapter.hitCount(
        'GET',
        '/system/resource-task-states/definitions',
      ),
      1,
    );
    expect(bundle.adapter.hitCount('GET', '/system/resource-task-states'), 1);
    final recordRequest =
        bundle.adapter.requests
            .where((req) => req.path == '/system/resource-task-states')
            .single;
    expect(recordRequest.uri.queryParameters['task_key'], 'movie_desc_sync');
    expect(recordRequest.uri.queryParameters['page'], '1');
    expect(recordRequest.uri.queryParameters['page_size'], '20');
    expect(recordRequest.uri.queryParameters.containsKey('state'), isFalse);
    expect(recordRequest.uri.queryParameters.containsKey('sort'), isFalse);
    expect(recordRequest.uri.queryParameters.containsKey('search'), isFalse);
  });

  test('selectTaskKey 切换到其他任务时触发首次加载并保留原分页', () async {
    _enqueueDefinitions(bundle);
    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      total: 1,
      items: <Map<String, dynamic>>[_recordJson(id: 1001)],
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    _enqueuePage(
      bundle,
      taskKey: 'media_thumbnail_generation',
      page: 1,
      total: 2,
      pageSize: 20,
      items: <Map<String, dynamic>>[
        _recordJson(id: 2001, taskKey: 'media_thumbnail_generation'),
        _recordJson(id: 2002, taskKey: 'media_thumbnail_generation'),
      ],
    );

    await controller.selectTaskKey('media_thumbnail_generation');

    expect(controller.activeTaskKey, 'media_thumbnail_generation');
    expect(controller.activeRecords, hasLength(2));

    // 切回原 task 不应再次请求。
    await controller.selectTaskKey('movie_desc_sync');
    expect(controller.activeTaskKey, 'movie_desc_sync');
    expect(controller.activeRecords, hasLength(1));
    expect(bundle.adapter.hitCount('GET', '/system/resource-task-states'), 2);
  });

  test('applyFilter 应用 state / search / sort 后触发重新加载', () async {
    _enqueueDefinitions(bundle);
    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      total: 1,
      items: <Map<String, dynamic>>[_recordJson(id: 1001)],
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      total: 1,
      items: <Map<String, dynamic>>[_recordJson(id: 1002, state: 'failed')],
    );

    await controller.applyFilter(
      const ResourceTaskRecordFilterState(
        stateFilter: ResourceTaskRecordStateFilter.failed,
        search: ' SSIS ',
        sort: ResourceTaskRecordSort.lastErrorAtDesc,
      ),
    );

    expect(controller.activeRecords, hasLength(1));
    expect(controller.activeRecords.single.resourceId, 1002);

    final requests =
        bundle.adapter.requests
            .where((req) => req.path == '/system/resource-task-states')
            .toList();
    expect(requests, hasLength(2));
    final filtered = requests.last;
    expect(filtered.uri.queryParameters['state'], 'failed');
    expect(filtered.uri.queryParameters['search'], 'SSIS');
    expect(filtered.uri.queryParameters['sort'], 'last_error_at:desc');
  });

  test('loadMoreRecords 成功时追加第二页', () async {
    _enqueueDefinitions(bundle);
    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      pageSize: 2,
      total: 3,
      items: <Map<String, dynamic>>[
        _recordJson(id: 1001),
        _recordJson(id: 1002),
      ],
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.activeRecords, hasLength(2));
    expect(controller.hasMoreRecords, isTrue);

    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 2,
      pageSize: 2,
      total: 3,
      items: <Map<String, dynamic>>[_recordJson(id: 1003)],
    );

    await controller.loadMoreRecords();

    expect(controller.activeRecords, hasLength(3));
    expect(controller.activeRecords.map((r) => r.resourceId), <int>[
      1001,
      1002,
      1003,
    ]);
    expect(controller.hasMoreRecords, isFalse);
    expect(controller.recordsLoadMoreErrorMessage, isNull);
    final pageRequest =
        bundle.adapter.requests
            .where((req) => req.path == '/system/resource-task-states')
            .last;
    expect(pageRequest.uri.queryParameters['page'], '2');
  });

  test('refreshRecords 重新拉取第一页并替换当前列表', () async {
    _enqueueDefinitions(bundle);
    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      total: 2,
      items: <Map<String, dynamic>>[
        _recordJson(id: 1001),
        _recordJson(id: 1002),
      ],
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      total: 1,
      items: <Map<String, dynamic>>[_recordJson(id: 1003)],
    );

    await controller.refreshRecords();

    expect(controller.activeRecords.map((r) => r.resourceId), <int>[1003]);
    expect(controller.hasMoreRecords, isFalse);
    final requests =
        bundle.adapter.requests
            .where((req) => req.path == '/system/resource-task-states')
            .toList();
    expect(requests, hasLength(2));
    expect(requests.last.uri.queryParameters['page'], '1');
  });

  test('openDetail / closeDetail 控制当前选中记录', () async {
    _enqueueDefinitions(bundle);
    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      total: 1,
      items: <Map<String, dynamic>>[_recordJson(id: 1001)],
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.isDetailOpen, isFalse);

    final record = controller.activeRecords.single;
    controller.openDetail(record);
    expect(controller.isDetailOpen, isTrue);
    expect(controller.selectedRecord?.recordKey, record.recordKey);

    controller.closeDetail();
    expect(controller.isDetailOpen, isFalse);
    expect(controller.selectedRecord, isNull);
  });

  test('initialize 失败时写入 initialErrorMessage', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/resource-task-states/definitions',
      statusCode: 500,
      body: <String, dynamic>{'message': '服务端异常'},
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.initialized, isFalse);
    expect(controller.initialErrorMessage, isNotNull);
    expect(controller.definitions, isEmpty);
    expect(controller.activeTaskKey, isNull);
  });

  test('loadMoreRecords 失败时设置 recordsLoadMoreErrorMessage', () async {
    _enqueueDefinitions(bundle);
    _enqueuePage(
      bundle,
      taskKey: 'movie_desc_sync',
      page: 1,
      pageSize: 2,
      total: 3,
      items: <Map<String, dynamic>>[
        _recordJson(id: 1001),
        _recordJson(id: 1002),
      ],
    );

    final controller = ResourceTaskCenterController(
      activityApi: bundle.activityApi,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/resource-task-states',
      statusCode: 503,
      body: <String, dynamic>{'message': '服务暂不可用'},
    );

    await controller.loadMoreRecords();

    expect(controller.activeRecords, hasLength(2));
    expect(controller.recordsLoadMoreErrorMessage, isNotNull);
    expect(controller.hasMoreRecords, isTrue);
  });
}

void _enqueueDefinitions(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/resource-task-states/definitions',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'task_key': 'movie_desc_sync',
        'resource_type': 'movie',
        'display_name': '影片描述回填',
        'default_sort': 'last_attempted_at:desc',
        'allow_reset': true,
        'state_counts': <String, dynamic>{
          'pending': 5,
          'running': 1,
          'succeeded': 100,
          'failed': 2,
        },
      },
      <String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'resource_type': 'media',
        'display_name': '媒体缩略图生成',
        'default_sort': 'updated_at:desc',
        'allow_reset': true,
        'state_counts': <String, dynamic>{
          'pending': 0,
          'running': 0,
          'succeeded': 50,
          'failed': 0,
        },
      },
    ],
  );
}

void _enqueuePage(
  TestApiBundle bundle, {
  required String taskKey,
  required int page,
  required int total,
  required List<Map<String, dynamic>> items,
  int pageSize = 20,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/resource-task-states',
    body: <String, dynamic>{
      'items': items,
      'page': page,
      'page_size': pageSize,
      'total': total,
    },
  );
}

Map<String, dynamic> _recordJson({
  required int id,
  String taskKey = 'movie_desc_sync',
  String state = 'pending',
}) {
  return <String, dynamic>{
    'task_key': taskKey,
    'resource_type': taskKey.startsWith('media') ? 'media' : 'movie',
    'resource_id': id,
    'state': state,
    'attempt_count': 1,
    'last_attempted_at': '2026-04-18T10:00:00Z',
    'last_succeeded_at': null,
    'last_error': state == 'failed' ? 'timeout' : null,
    'last_error_at': state == 'failed' ? '2026-04-18T10:01:00Z' : null,
    'last_task_run_id': 99,
    'last_trigger_type': 'scheduled',
    'created_at': '2026-04-01T00:00:00Z',
    'updated_at': '2026-04-18T10:00:00Z',
    'resource': <String, dynamic>{
      'resource_id': id,
      'movie_number': 'SSIS-$id',
      'title': '示例-$id',
    },
  };
}
