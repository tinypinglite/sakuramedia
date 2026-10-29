import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: bundle.riverpodOverrides(),
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    sessionStore.dispose();
  });

  test('build loads task snapshot and enters polling state', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);

    final state = await container.read(activityCenterProvider.future);

    expect(state.initialized, isTrue);
    expect(state.connectionState, ActivityConnectionState.polling);
    expect(state.activeTaskRuns.single.id, 8);
    expect(state.taskRuns.single.id, 9);
    expect(state.isPollingFallback, isTrue);
    expect(
      bundle.adapter.requests.where(
        (request) => request.path.contains('/system/events/'),
      ),
      isEmpty,
    );
    expect(
      bundle.adapter.requests.where(
        (request) => request.path == '/system/task-runs/attention',
      ),
      isEmpty,
    );
  });

  test(
    'knownTaskKeyLabels prefers run names and falls back to job help',
    () async {
      final subscription = container.listen(activityCenterProvider, (_, __) {});
      addTearDown(subscription.close);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/jobs',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'task_key': 'gfriends_filetree_refresh',
            'cli_help': '拉取一次 GFriends Filetree 并写入本地缓存',
            'manual_trigger_allowed': true,
          },
          <String, dynamic>{
            'task_key': 'media_import',
            'cli_help': '执行一次媒体库导入',
            'manual_trigger_allowed': true,
          },
        ],
      );
      _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);

      final state = await container.read(activityCenterProvider.future);

      expect(state.knownTaskKeyLabels, <String, String>{
        'gfriends_filetree_refresh': '拉取一次 GFriends Filetree 并写入本地缓存',
        'media_import': '媒体导入',
      });
    },
  );

  test('refreshTaskHistory reads /system/task-runs', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 1, historyTaskId: 2);
    await container.read(activityCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: 10, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    await container.read(activityCenterProvider.notifier).refreshTaskHistory();

    expect(
      container.read(activityCenterProvider).requireValue.taskRuns.single.id,
      10,
    );
    expect(bundle.adapter.requests.last.path, '/system/task-runs');
  });

  test('resume polling refreshes the retained task snapshot', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 1, historyTaskId: 2);
    await container.read(activityCenterProvider.future);

    final controller = container.read(activityCenterProvider.notifier);
    controller.pausePolling();
    _enqueueTaskHistory(bundle, id: 12);
    _enqueueActiveTasks(bundle, id: 11);

    await controller.resumePolling();

    final state = container.read(activityCenterProvider).requireValue;
    expect(state.activeTaskRuns.single.id, 11);
    expect(state.taskRuns.single.id, 12);
  });

  test('polling keeps loaded pages and patches rows in place', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);

    final firstPage = <Map<String, dynamic>>[
      for (var id = 1; id <= 20; id++)
        _taskRunJson(id: id, state: 'completed', progressCurrent: 1),
    ];
    final secondPage = <Map<String, dynamic>>[
      for (var id = 21; id <= 40; id++)
        _taskRunJson(id: id, state: 'completed', progressCurrent: 1),
    ];
    _enqueueJobs(bundle);
    _enqueueBootstrapPage(bundle, items: firstPage, total: 40);
    await container.read(activityCenterProvider.future);

    final controller = container.read(activityCenterProvider.notifier);
    controller.pausePolling();

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': secondPage,
        'page': 2,
        'page_size': 20,
        'total': 40,
      },
    );
    await controller.loadMoreTasks();

    var state = container.read(activityCenterProvider).requireValue;
    expect(state.taskRuns, hasLength(40));
    expect(state.taskNextPage, 3);
    expect(state.hasMoreTasks, isFalse);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (var id = 1; id <= 20; id++)
            _taskRunJson(
              id: id,
              state: 'completed',
              progressCurrent: id == 1 ? 99 : 1,
            ),
        ],
        'page': 1,
        'page_size': 20,
        'total': 40,
      },
    );
    _enqueueActiveTasks(bundle, id: 999);
    await controller.resumePolling();

    state = container.read(activityCenterProvider).requireValue;
    expect(state.taskRuns, hasLength(40));
    expect(state.taskRuns.map((task) => task.id).toSet(), <int>{
      for (var id = 1; id <= 40; id++) id,
    });
    expect(state.taskNextPage, 3);
    expect(state.hasMoreTasks, isFalse);
    expect(
      state.taskRuns.firstWhere((task) => task.id == 1).progressCurrent,
      99,
    );
  });

  test('polling keeps a long-running task outside the history page', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);
    await container.read(activityCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/jobs/media_import/runs',
      body: const <String, dynamic>{
        'task_run_id': 10,
        'task_key': 'media_import',
        'state': 'pending',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: 9, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs/active',
      body: <Map<String, dynamic>>[
        _taskRunJson(id: 8, state: 'running', progressCurrent: 7),
        _taskRunJson(id: 10, state: 'pending'),
      ],
    );

    await container
        .read(activityCenterProvider.notifier)
        .triggerJob('media_import');

    final activeTask = container
        .read(activityCenterProvider)
        .requireValue
        .activeTaskRuns
        .firstWhere((task) => task.id == 8);
    expect(activeTask.id, 8);
    expect(activeTask.progressCurrent, 7);
    expect(
      bundle.adapter.requests
          .where((request) => request.path == '/system/task-runs/active')
          .length,
      1,
    );
  });

  test('polling with identical snapshot does not notify listeners', () async {
    var notifications = 0;
    final subscription = container.listen(activityCenterProvider, (_, __) {
      notifications++;
    });
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);
    await container.read(activityCenterProvider.future);

    final controller = container.read(activityCenterProvider.notifier);
    controller.pausePolling();
    // pause 会写 pollingState 从 polling 切 idle（记一次通知），基线取其后。
    final afterPause = notifications;
    expect(afterPause, greaterThan(0));
    // 与当前快照逐字段相同的响应：轮询应跳过写回，不产生新的通知。
    _enqueueTaskHistory(bundle, id: 9);
    _enqueueActiveTasks(bundle, id: 8);
    await controller.resumePolling();

    expect(notifications, afterPause);
    final state = container.read(activityCenterProvider).requireValue;
    expect(state.activeTaskRuns.single.id, 8);
    expect(state.taskRuns.single.id, 9);
  });

  test('default run scope is operations and filters switch to all', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);
    await container.read(activityCenterProvider.future);

    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.path == '/system/activity/bootstrap')
          .uri
          .queryParameters['task_scope'],
      'operations',
    );

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: 9, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    final controller = container.read(activityCenterProvider.notifier);
    await controller.applyTaskFilter(
      controller.taskFilter.copyWith(taskKey: 'media_import'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final filtered = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/system/task-runs',
    );
    expect(filtered.uri.queryParameters['task_key'], 'media_import');
    expect(filtered.uri.queryParameters['scope'], 'all');

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: 9, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    await controller.applyTaskFilter(controller.taskFilter.resetFilters());
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.path == '/system/task-runs')
          .uri
          .queryParameters['scope'],
      'operations',
    );
  });

  test('polling keeps the filter-driven run scope', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);
    await container.read(activityCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: 9, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    final controller = container.read(activityCenterProvider.notifier);
    await controller.applyTaskFilter(
      controller.taskFilter.copyWith(triggerType: 'scheduled'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    _enqueueTaskHistory(bundle, id: 9);
    _enqueueActiveTasks(bundle, id: 8);
    await controller.resumePolling();

    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.path == '/system/task-runs')
          .uri
          .queryParameters['scope'],
      'all',
    );
    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.path == '/system/task-runs')
          .uri
          .queryParameters['trigger_type'],
      'scheduled',
    );
  });

  test('refreshAll refreshes runs and jobs together', () async {
    final subscription = container.listen(activityCenterProvider, (_, __) {});
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);
    await container.read(activityCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: 44, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'media_import',
          'cli_help': '执行一次媒体库导入',
          'cron_expr': '0 3 * * *',
          'manual_trigger_allowed': true,
        },
      ],
    );

    final before = bundle.adapter.requests.length;
    await container.read(activityCenterProvider.notifier).refreshAll();

    final state = container.read(activityCenterProvider).requireValue;
    expect(state.taskRuns.single.id, 44);
    expect(state.jobs.single.taskKey, 'media_import');
    final paths = bundle.adapter.requests
        .skip(before)
        .map((request) => request.path)
        .toSet();
    expect(paths, containsAll(<String>['/system/task-runs', '/system/jobs']));
    expect(paths, isNot(contains('/system/task-runs/attention')));
  });

  test('polling with changed progress notifies listeners once', () async {
    var notifications = 0;
    final subscription = container.listen(activityCenterProvider, (_, __) {
      notifications++;
    });
    addTearDown(subscription.close);
    _enqueueJobs(bundle);
    _enqueueBootstrap(bundle, activeTaskId: 8, historyTaskId: 9);
    await container.read(activityCenterProvider.future);

    final controller = container.read(activityCenterProvider.notifier);
    controller.pausePolling();
    final afterPause = notifications;
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: 9, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs/active',
      body: <Map<String, dynamic>>[
        _taskRunJson(id: 8, state: 'running', progressCurrent: 7),
      ],
    );
    await controller.resumePolling();

    expect(notifications, greaterThan(afterPause));
    final state = container.read(activityCenterProvider).requireValue;
    expect(
      state.activeTaskRuns.singleWhere((task) => task.id == 8).progressCurrent,
      7,
    );
  });
}

void _enqueueTaskHistory(TestApiBundle bundle, {required int id}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/task-runs',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[_taskRunJson(id: id, state: 'completed')],
      'page': 1,
      'page_size': 20,
      'total': 1,
    },
  );
}

void _enqueueActiveTasks(TestApiBundle bundle, {required int id}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/task-runs/active',
    body: <Map<String, dynamic>>[_taskRunJson(id: id, state: 'running')],
  );
}

void _enqueueJobs(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/jobs',
    body: const <dynamic>[],
  );
}

void _enqueueBootstrap(
  TestApiBundle bundle, {
  required int activeTaskId,
  required int historyTaskId,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
      'unread_count': 0,
      'active_task_runs': <Map<String, dynamic>>[
        _taskRunJson(id: activeTaskId, state: 'running'),
      ],
      'task_runs': <String, dynamic>{
        'items': <Map<String, dynamic>>[
          _taskRunJson(id: historyTaskId, state: 'completed'),
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    },
  );
}

void _enqueueBootstrapPage(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> items,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
      'unread_count': 0,
      'active_task_runs': const <dynamic>[],
      'task_runs': <String, dynamic>{
        'items': items,
        'page': 1,
        'page_size': 20,
        'total': total,
      },
    },
  );
}

Map<String, dynamic> _taskRunJson({
  required int id,
  required String state,
  int progressCurrent = 1,
}) => <String, dynamic>{
  'id': id,
  'task_key': 'media_import',
  'task_name': '媒体导入',
  'trigger_type': 'manual',
  'state': state,
  'progress_current': progressCurrent,
  'progress_total': 2,
  'progress_text': '处理中',
  'created_at': '2026-03-26T09:10:00Z',
  'updated_at': '2026-03-26T09:11:00Z',
};
