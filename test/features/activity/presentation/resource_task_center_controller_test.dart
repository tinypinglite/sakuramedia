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
    expect(recordRequest.uri.queryParameters['state'], 'failed');
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

  group('批量重置 (media_thumbnail_generation)', () {
    Future<ResourceTaskCenterController> initMediaTab(
      List<Map<String, dynamic>> mediaItems,
    ) async {
      _enqueueDefinitions(bundle);
      _enqueuePage(
        bundle,
        taskKey: 'movie_desc_sync',
        page: 1,
        total: 0,
        items: const <Map<String, dynamic>>[],
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
        pageSize: 20,
        total: mediaItems.length,
        items: mediaItems,
      );
      await controller.selectTaskKey('media_thumbnail_generation');
      return controller;
    }

    test('supportsBatchReset 仅在 media_thumbnail_generation 为 true', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[]);
      expect(controller.supportsBatchReset, isTrue);
      _enqueuePage(
        bundle,
        taskKey: 'movie_desc_sync',
        page: 1,
        total: 0,
        items: const <Map<String, dynamic>>[],
      );
      await controller.selectTaskKey('movie_desc_sync');
      expect(controller.supportsBatchReset, isFalse);
    });

    test('enterSelectionMode 在非 media tab 无效', () async {
      _enqueueDefinitions(bundle);
      _enqueuePage(
        bundle,
        taskKey: 'movie_desc_sync',
        page: 1,
        total: 1,
        items: <Map<String, dynamic>>[_recordJson(id: 1001, state: 'failed')],
      );
      final controller = ResourceTaskCenterController(
        activityApi: bundle.activityApi,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      controller.enterSelectionMode();
      expect(controller.selectionMode, isFalse);
    });

    test('toggleRecordSelection 达到 200 上限时拒绝新增', () async {
      final records = List<Map<String, dynamic>>.generate(
        205,
        (i) => _recordJson(
          id: 3000 + i,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      );
      final controller = await initMediaTab(records);
      controller.enterSelectionMode();

      for (var i = 0; i < 200; i++) {
        final ok = controller.toggleRecordSelection(3000 + i);
        expect(ok, isTrue);
      }
      expect(controller.selectedCount, 200);
      final rejected = controller.toggleRecordSelection(3200);
      expect(rejected, isFalse);
      expect(controller.selectedCount, 200);
      // 取消已选的仍可 → true
      final toggledOff = controller.toggleRecordSelection(3000);
      expect(toggledOff, isTrue);
      expect(controller.selectedCount, 199);
    });

    test('toggleSelectAllVisibleFailed 只勾 failed 并截取前 200', () async {
      final records = <Map<String, dynamic>>[
        _recordJson(
          id: 100,
          taskKey: 'media_thumbnail_generation',
          state: 'succeeded',
        ),
        ...List<Map<String, dynamic>>.generate(
          250,
          (i) => _recordJson(
            id: 200 + i,
            taskKey: 'media_thumbnail_generation',
            state: 'failed',
          ),
        ),
      ];
      final controller = await initMediaTab(records);
      controller.enterSelectionMode();
      controller.toggleSelectAllVisibleFailed();

      expect(controller.selectedCount, 200);
      expect(controller.isRecordSelected(100), isFalse);
      expect(controller.isRecordSelected(200), isTrue);
      expect(controller.isRecordSelected(200 + 199), isTrue);
      expect(controller.isRecordSelected(200 + 200), isFalse);
      expect(controller.isAllVisibleFailedSelected, isTrue);

      // 再次调用 → 清空
      controller.toggleSelectAllVisibleFailed();
      expect(controller.selectedCount, 0);
      expect(controller.isAllVisibleFailedSelected, isFalse);
    });

    test('toggleSelectAllVisibleFailed 跳过失效与已删除媒体', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[
        _recordJson(
          id: 410,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
          valid: true,
        ),
        _recordJson(
          id: 411,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
          valid: false,
        ),
        _recordJson(
          id: 412,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
          hasResource: false,
        ),
        // valid 未下发 → 视为未知，不拦截，交由后端判定。
        _recordJson(
          id: 413,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      ]);

      // visibleFailedCount 只数可勾选的（410/413），失效与已删除媒体不算。
      expect(controller.visibleFailedCount, 2);
      // visibleFailedTotalCount 数所有 failed（410/411/412/413），给"全选可重置(N/M)"的 M。
      expect(controller.visibleFailedTotalCount, 4);

      controller.enterSelectionMode();
      controller.toggleSelectAllVisibleFailed();

      expect(controller.selectedCount, 2);
      expect(controller.isRecordSelected(410), isTrue);
      expect(controller.isRecordSelected(411), isFalse);
      expect(controller.isRecordSelected(412), isFalse);
      expect(controller.isRecordSelected(413), isTrue);
      expect(controller.isAllVisibleFailedSelected, isTrue);
    });

    test('切换 tab 自动退出多选并清空已选', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[
        _recordJson(
          id: 501,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      ]);
      controller.enterSelectionMode();
      controller.toggleRecordSelection(501);
      expect(controller.selectionMode, isTrue);
      expect(controller.selectedCount, 1);

      _enqueuePage(
        bundle,
        taskKey: 'movie_desc_sync',
        page: 1,
        total: 0,
        items: const <Map<String, dynamic>>[],
      );
      await controller.selectTaskKey('movie_desc_sync');
      expect(controller.selectionMode, isFalse);
      expect(controller.selectedCount, 0);
    });

    test('applyFilter 自动退出多选', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[
        _recordJson(
          id: 601,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      ]);
      controller.enterSelectionMode();
      controller.toggleRecordSelection(601);

      _enqueuePage(
        bundle,
        taskKey: 'media_thumbnail_generation',
        page: 1,
        total: 0,
        items: const <Map<String, dynamic>>[],
      );
      await controller.applyFilter(
        const ResourceTaskRecordFilterState(
          stateFilter: ResourceTaskRecordStateFilter.all,
        ),
      );
      expect(controller.selectionMode, isFalse);
      expect(controller.selectedCount, 0);
    });

    test('resetSelectedFailed 成功：移除记录 + counts 补丁 + 退出选择', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[
        _recordJson(
          id: 701,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
        _recordJson(
          id: 702,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
        _recordJson(
          id: 703,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      ]);
      // 让 definition 的 failed 计数有个已知值，方便断言补丁。
      // definitions helper 里 media 是 failed=0, 但我们下面 refreshDefinitions
      // 一次自定义响应把它改成 failed=5 更贴近真实场景。
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
              'pending': 1,
              'running': 0,
              'succeeded': 50,
              'failed': 5,
            },
          },
        ],
      );
      await controller.refreshDefinitions();

      controller.enterSelectionMode();
      controller.toggleRecordSelection(701);
      controller.toggleRecordSelection(702);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/system/resource-task-states/media_thumbnail_generation/reset',
        body: <String, dynamic>{
          'task_key': 'media_thumbnail_generation',
          'state': 'pending',
          'reset_count': 2,
          'resource_ids': <int>[701, 702],
        },
      );

      final result = await controller.resetSelectedFailed();

      expect(result?.resetCount, 2);
      expect(controller.selectionMode, isFalse);
      expect(controller.selectedCount, 0);
      expect(controller.isResetting, isFalse);
      expect(
        controller.activeRecords.map((r) => r.resourceId),
        <int>[703],
      );
      final mediaDef = controller.definitions.firstWhere(
        (d) => d.taskKey == 'media_thumbnail_generation',
      );
      expect(mediaDef.stateCounts.failed, 3);
      expect(mediaDef.stateCounts.pending, 3);
    });

    test('resetSelectedFailed 部分成功：只移除已重置，跳过项保留选中', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[
        _recordJson(
          id: 901,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
        _recordJson(
          id: 902,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
        _recordJson(
          id: 903,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      ]);
      controller.enterSelectionMode();
      controller.toggleRecordSelection(901);
      controller.toggleRecordSelection(902);
      controller.toggleRecordSelection(903);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/system/resource-task-states/media_thumbnail_generation/reset',
        body: <String, dynamic>{
          'task_key': 'media_thumbnail_generation',
          'state': 'pending',
          'reset_count': 1,
          'resource_ids': <int>[901],
          'skipped_count': 2,
          'skipped': <Map<String, dynamic>>[
            <String, dynamic>{'resource_id': 902, 'reason': 'media_invalid'},
            <String, dynamic>{'resource_id': 903, 'reason': 'not_failed'},
          ],
        },
      );

      final result = await controller.resetSelectedFailed();

      expect(result?.resetCount, 1);
      expect(result?.skippedCount, 2);
      expect(controller.isResetting, isFalse);
      // 只有 901 真正被重置 → 只有它从列表里移除。
      expect(
        controller.activeRecords.map((r) => r.resourceId),
        <int>[902, 903],
      );
      // 跳过项保持选中，方便用户定位。
      expect(controller.selectionMode, isTrue);
      expect(controller.selectedCount, 2);
      expect(controller.isRecordSelected(901), isFalse);
      expect(controller.isRecordSelected(902), isTrue);
      expect(controller.isRecordSelected(903), isTrue);
    });

    test('resetSelectedFailed 全部跳过：不移除任何记录', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[
        _recordJson(
          id: 951,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
        _recordJson(
          id: 952,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      ]);
      controller.enterSelectionMode();
      controller.toggleRecordSelection(951);
      controller.toggleRecordSelection(952);

      // 后端部分成功语义：全部不合格时仍返回 200 + reset_count = 0。
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/system/resource-task-states/media_thumbnail_generation/reset',
        body: <String, dynamic>{
          'task_key': 'media_thumbnail_generation',
          'state': 'pending',
          'reset_count': 0,
          'resource_ids': <int>[],
          'skipped_count': 2,
          'skipped': <Map<String, dynamic>>[
            <String, dynamic>{'resource_id': 951, 'reason': 'media_not_found'},
            <String, dynamic>{'resource_id': 952, 'reason': 'media_invalid'},
          ],
        },
      );

      final result = await controller.resetSelectedFailed();

      expect(result?.resetCount, 0);
      // 一条都没重置 → 列表原封不动（旧实现会在这里把两条全抹掉）。
      expect(
        controller.activeRecords.map((r) => r.resourceId),
        <int>[951, 952],
      );
      expect(controller.selectionMode, isTrue);
      expect(controller.selectedCount, 2);
      final mediaDef = controller.definitions.firstWhere(
        (d) => d.taskKey == 'media_thumbnail_generation',
      );
      expect(mediaDef.stateCounts.failed, 0);
      expect(mediaDef.stateCounts.pending, 0);
    });

    test('resetSelectedFailed 失败：保留已选 + rethrow', () async {
      final controller = await initMediaTab(<Map<String, dynamic>>[
        _recordJson(
          id: 801,
          taskKey: 'media_thumbnail_generation',
          state: 'failed',
        ),
      ]);
      controller.enterSelectionMode();
      controller.toggleRecordSelection(801);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/system/resource-task-states/media_thumbnail_generation/reset',
        statusCode: 422,
        body: <String, dynamic>{'message': '仅允许重置失败的媒体缩略图任务'},
      );

      await expectLater(controller.resetSelectedFailed(), throwsA(anything));

      expect(controller.isResetting, isFalse);
      expect(controller.selectionMode, isTrue);
      expect(controller.selectedCount, 1);
      expect(controller.isRecordSelected(801), isTrue);
      expect(controller.activeRecords, hasLength(1));
    });
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
  bool? valid,
  bool hasResource = true,
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
    'resource':
        hasResource
            ? <String, dynamic>{
              'resource_id': id,
              'movie_number': 'SSIS-$id',
              'title': '示例-$id',
              if (valid != null) 'valid': valid,
            }
            : null,
  };
}
