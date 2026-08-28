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
  });

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

    await container
        .read(activityCenterProvider.notifier)
        .refreshTaskHistory();

    expect(
      container.read(activityCenterProvider).requireValue.taskRuns.single.id,
      10,
    );
    expect(
      bundle.adapter.requests.last.path,
      '/system/task-runs',
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
      path: '/system/jobs/media_import/run',
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

Map<String, dynamic> _taskRunJson({
  required int id,
  required String state,
  int progressCurrent = 1,
}) =>
    <String, dynamic>{
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
