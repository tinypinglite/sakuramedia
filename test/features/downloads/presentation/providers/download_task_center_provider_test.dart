import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';

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
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        downloadsApiProvider.overrideWithValue(bundle.downloadsApi),
        downloadClientsApiProvider.overrideWithValue(bundle.downloadClientsApi),
      ],
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    sessionStore.dispose();
  });

  test('build loads a list snapshot with the current task fields', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1)]);
    _enqueueClients(bundle);

    final state = await container.read(downloadTaskCenterProvider.future);

    expect(state.paged.items.single.task.id, 1);
    expect(state.paged.items.single.task.remoteId, 'remote-1');
    expect(state.paged.items.single.state, 'downloading');
    expect(state.clientOptions, const [
      DownloadClientOption(id: 2, name: 'qb-main'),
    ]);
    expect(state.clientNames, {2: 'qb-main'});
  });

  test('startPolling replaces the list with a fresh snapshot', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1)]);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    _enqueueTaskPage(bundle, [taskJson(id: 2)], total: 1);
    await container.read(downloadTaskCenterProvider.notifier).startPolling();

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.pollingState, DownloadTaskPollingState.polling);
    expect(state.paged.items.single.task.id, 2);
  });

  test('resumePolling refreshes the retained download snapshot', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1)]);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    final controller = container.read(downloadTaskCenterProvider.notifier);
    _enqueueTaskPage(bundle, [taskJson(id: 2)]);
    await controller.startPolling();
    controller.pausePolling();
    expect(
      container.read(downloadTaskCenterProvider).requireValue.pollingState,
      DownloadTaskPollingState.idle,
    );

    _enqueueTaskPage(bundle, [taskJson(id: 3)]);
    await controller.resumePolling();

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.pollingState, DownloadTaskPollingState.polling);
    expect(state.paged.items.single.task.id, 3);
  });

  test(
    'stopPolling after pause allows a remounted page to restart polling',
    () async {
      _enqueueTaskPage(bundle, [taskJson(id: 1)]);
      _enqueueClients(bundle);
      await container.read(downloadTaskCenterProvider.future);

      final controller = container.read(downloadTaskCenterProvider.notifier);
      _enqueueTaskPage(bundle, [taskJson(id: 2)]);
      await controller.startPolling();
      controller.pausePolling();
      controller.stopPolling();

      _enqueueTaskPage(bundle, [taskJson(id: 3)]);
      await controller.startPolling();

      final state = container.read(downloadTaskCenterProvider).requireValue;
      expect(state.pollingState, DownloadTaskPollingState.polling);
      expect(state.paged.items.single.task.id, 3);
    },
  );

  test('delete updates the current snapshot', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 3)]);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/download-tasks/3',
      statusCode: 204,
    );
    await container
        .read(downloadTaskCenterProvider.notifier)
        .deleteTask(3, deleteFiles: false);
    expect(
      container.read(downloadTaskCenterProvider).requireValue.paged.items,
      isEmpty,
    );
  });

  test('triggerImport posts and refreshes the snapshot to running', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 3)]);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    _enqueueTaskPage(bundle, [taskJson(id: 3)]);
    final controller = container.read(downloadTaskCenterProvider.notifier);
    await controller.startPolling();

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-tasks/3/import',
      statusCode: 202,
      body: <String, dynamic>{
        'task_id': 3,
        'task_run_id': 9,
        'status': 'accepted',
      },
    );
    _enqueueTaskPage(bundle, [
      taskJson(id: 3, importStatus: 'running', importStatusLabel: '导入中'),
    ]);
    await controller.triggerImport(3);

    final posts = bundle.adapter.requests.where(
      (request) =>
          request.method == 'POST' &&
          request.path == '/download-tasks/3/import',
    );
    expect(posts, hasLength(1));
    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.single.task.importStatus, 'running');
    expect(state.isTaskPending(3), isFalse);
  });

  test('loadMore stops when the next page brings no new rows', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1), taskJson(id: 2)], total: 4);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    _enqueueTaskPage(bundle, const [], page: 2, total: 4);
    final controller = container.read(downloadTaskCenterProvider.notifier);
    await controller.loadMore();

    var state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [1, 2]);
    expect(state.paged.isLoadingMore, isFalse);
    expect(state.paged.hasMore, isFalse);

    await controller.loadMore();
    expect(_downloadTaskRequestCount(bundle), 2);
    state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.hasMore, isFalse);
  });

  test('loadMore ignores rows already present in the list', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1), taskJson(id: 2)], total: 4);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    _enqueueTaskPage(
      bundle,
      [taskJson(id: 2), taskJson(id: 3)],
      page: 2,
      total: 4,
    );
    await container.read(downloadTaskCenterProvider.notifier).loadMore();

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [1, 2, 3]);
    expect(state.paged.hasMore, isTrue);
  });

  test('poll keeps loaded pages and patches rows in place', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1), taskJson(id: 2)], total: 4);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    _enqueueTaskPage(
      bundle,
      [taskJson(id: 3), taskJson(id: 4)],
      page: 2,
      total: 4,
    );
    final controller = container.read(downloadTaskCenterProvider.notifier);
    await controller.loadMore();

    _enqueueTaskPage(bundle, [
      taskJson(id: 1, progress: 0.9),
      taskJson(id: 2),
    ], total: 4);
    await controller.startPolling();

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [1, 2, 3, 4]);
    expect(state.paged.currentPage, 2);
    expect(state.paged.hasMore, isFalse);
    expect(state.paged.items.first.progress, 0.9);
    expect(state.paged.items[1].progress, 0.5);
    expect(state.pollingState, DownloadTaskPollingState.polling);
  });

  test('poll keeps pagination while a later page is in flight', () async {
    final firstPage = [for (var id = 1; id <= 20; id++) taskJson(id: id)];
    final secondPage = [for (var id = 21; id <= 40; id++) taskJson(id: id)];
    final thirdPage = [for (var id = 41; id <= 45; id++) taskJson(id: id)];
    _enqueueTaskPage(bundle, firstPage, total: 45);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    _enqueueTaskPage(bundle, secondPage, page: 2, total: 45);
    final controller = container.read(downloadTaskCenterProvider.notifier);
    await controller.loadMore();

    final gate = Completer<void>();
    _enqueueDeferredTaskPage(
      bundle,
      gate: gate,
      body: _taskPageJson(thirdPage, page: 3, total: 45),
    );
    final inFlight = controller.loadMore();
    await _waitForDownloadTaskRequests(bundle, 3);

    _enqueueTaskPage(bundle, firstPage, total: 45);
    await controller.startPolling();

    gate.complete();
    await inFlight;

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [
      for (var id = 1; id <= 45; id++) id,
    ]);
    expect(state.paged.currentPage, 3);
    expect(state.paged.hasMore, isFalse);
    expect(state.paged.isLoadingMore, isFalse);

    await controller.loadMore();
    expect(_downloadTaskRequestCount(bundle), 4);
  });

  test(
    'poll discards an in-flight loadMore while still on the first page',
    () async {
      _enqueueTaskPage(bundle, [taskJson(id: 1), taskJson(id: 2)], total: 4);
      _enqueueClients(bundle);
      await container.read(downloadTaskCenterProvider.future);

      final gate = Completer<void>();
      _enqueueDeferredTaskPage(
        bundle,
        gate: gate,
        body: _taskPageJson(
          [taskJson(id: 3), taskJson(id: 4)],
          page: 2,
          total: 4,
        ),
      );
      final controller = container.read(downloadTaskCenterProvider.notifier);
      final inFlight = controller.loadMore();
      await _waitForDownloadTaskRequests(bundle, 2);

      _enqueueTaskPage(bundle, [taskJson(id: 1), taskJson(id: 2)], total: 4);
      await controller.startPolling();

      gate.complete();
      await inFlight;

      final state = container.read(downloadTaskCenterProvider).requireValue;
      expect(state.paged.items.map((row) => row.task.id), [1, 2]);
      expect(state.paged.currentPage, 1);
      expect(state.paged.isLoadingMore, isFalse);
    },
  );

  test(
    'loadMore completes after the provider is invalidated while watched',
    () async {
      _enqueueTaskPage(bundle, [taskJson(id: 1), taskJson(id: 2)], total: 4);
      _enqueueClients(bundle);
      await container.read(downloadTaskCenterProvider.future);

      final subscription = container.listen(
        downloadTaskCenterProvider,
        (_, _) {},
      );

      _enqueueTaskPage(bundle, [taskJson(id: 1), taskJson(id: 2)], total: 4);
      _enqueueClients(bundle);
      container.invalidate(downloadTaskCenterProvider);
      await container.read(downloadTaskCenterProvider.future);

      _enqueueTaskPage(
        bundle,
        [taskJson(id: 3), taskJson(id: 4)],
        page: 2,
        total: 4,
      );
      await container.read(downloadTaskCenterProvider.notifier).loadMore();

      final state = container.read(downloadTaskCenterProvider).requireValue;
      expect(state.paged.items.map((row) => row.task.id), [1, 2, 3, 4]);
      expect(state.paged.isLoadingMore, isFalse);

      subscription.close();
    },
  );

  test(
    'polling with identical snapshot does not notify item listeners',
    () async {
      var notifications = 0;
      final subscription = container.listen(
        downloadTaskCenterProvider.select(
          (s) => s.value?.paged.items.first.progress,
        ),
        (_, __) {
          notifications++;
        },
      );
      addTearDown(subscription.close);
      _enqueueTaskPage(bundle, [taskJson(id: 1)]);
      _enqueueClients(bundle);
      await container.read(downloadTaskCenterProvider.future);

      final controller = container.read(downloadTaskCenterProvider.notifier);
      // startPolling 拉一次快照让轮询进入 polling 态，先行消耗掉状态翻转的通知。
      _enqueueTaskPage(bundle, [taskJson(id: 1)], total: 1);
      await controller.startPolling();
      controller.pausePolling();
      final afterPause = notifications;
      // 与当前快照逐字段相同的响应：轮询应跳过写回，行级订阅收不到新的通知。
      _enqueueTaskPage(bundle, [taskJson(id: 1)], total: 1);
      await controller.resumePolling();

      expect(notifications, afterPause);
      final state = container.read(downloadTaskCenterProvider).requireValue;
      expect(state.paged.items.single.task.id, 1);
    },
  );

  test('polling with changed progress notifies item listeners', () async {
    var notifications = 0;
    final subscription = container.listen(
      downloadTaskCenterProvider.select(
        (s) => s.value?.paged.items.first.progress,
      ),
      (_, __) {
        notifications++;
      },
    );
    addTearDown(subscription.close);
    _enqueueTaskPage(bundle, [taskJson(id: 1)]);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    final controller = container.read(downloadTaskCenterProvider.notifier);
    _enqueueTaskPage(bundle, [taskJson(id: 1)], total: 1);
    await controller.startPolling();
    controller.pausePolling();
    final afterPause = notifications;
    _enqueueTaskPage(bundle, [taskJson(id: 1, progress: 0.9)], total: 1);
    await controller.resumePolling();

    expect(notifications, greaterThan(afterPause));
    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.single.progress, 0.9);
  });
}

Map<String, dynamic> taskJson({
  required int id,
  double progress = 0.5,
  String state = 'downloading',
  String importStatus = 'pending',
  String importStatusLabel = '等待导入',
}) => <String, dynamic>{
  'id': id,
  'client_id': 2,
  'movie_number': 'ABC-00$id',
  'name': 'ABC-00$id',
  'remote_id': 'remote-$id',
  'state': state,
  'progress': progress,
  'import_status': importStatus,
  'import_status_label': importStatusLabel,
  'created_at': '2026-07-10T08:00:00Z',
  'updated_at': '2026-07-10T08:01:00Z',
};

Map<String, dynamic> _taskPageJson(
  List<Map<String, dynamic>> items, {
  required int page,
  required int total,
}) => <String, dynamic>{
  'items': items,
  'page': page,
  'page_size': 20,
  'total': total,
};

void _enqueueDeferredTaskPage(
  TestApiBundle bundle, {
  required Completer<void> gate,
  required Map<String, dynamic> body,
}) {
  bundle.adapter.enqueueResponder(
    method: 'GET',
    path: '/download-tasks',
    responder: (_, _) async {
      await gate.future;
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    },
  );
}

int _downloadTaskRequestCount(TestApiBundle bundle) => bundle.adapter.requests
    .where((request) => request.path == '/download-tasks')
    .length;

Future<void> _waitForDownloadTaskRequests(
  TestApiBundle bundle,
  int count,
) async {
  for (var i = 0; i < 50 && _downloadTaskRequestCount(bundle) < count; i++) {
    await pumpEventQueue(times: 1);
  }
}

void _enqueueTaskPage(
  TestApiBundle bundle,
  List<Map<String, dynamic>> items, {
  int page = 1,
  int? total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-tasks',
    body: <String, dynamic>{
      'items': items,
      'page': page,
      'page_size': 20,
      'total': total ?? items.length,
    },
  );
}

void _enqueueClients(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 2,
        'name': 'qb-main',
        'library_id': 1,
        'provider_config': <String, dynamic>{'endpoint': 'http://qb:8080'},
      },
    ],
  );
}
