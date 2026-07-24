import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';

import '../../../../support/test_api_bundle.dart';

/// 覆盖迁 Riverpod 后 DownloadTaskCenter 的核心用户路径：
/// 首页加载 + 加载更多、筛选切换（保留 items + isReloading）、
/// 暂停/恢复/删除 mutation。SSE 消费由集成路径覆盖，此处不重复。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-07-10T10:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: [
        downloadsApiProvider.overrideWithValue(bundle.downloadsApi),
        downloadClientsApiProvider.overrideWithValue(bundle.downloadClientsApi),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    sessionStore.dispose();
  });

  Map<String, dynamic> taskJson({
    required int id,
    String downloadState = 'downloading',
    String importStatus = 'pending',
    String importStatusLabel = '等待导入',
    double progress = 0.0,
  }) {
    return <String, dynamic>{
      'id': id,
      'client_id': 2,
      'movie_number': 'ABC-00$id',
      'name': 'ABC-00$id',
      'info_hash': 'hash-$id',
      'save_path': '/mnt/$id',
      'progress': progress,
      'download_state': downloadState,
      'import_status': importStatus,
      'import_status_label': importStatusLabel,
      'created_at': '2026-07-10T08:0$id:00Z',
      'updated_at': '2026-07-10T08:0$id:00Z',
    };
  }

  void enqueueTaskPage(
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

  void enqueueClients({List<Map<String, dynamic>>? clients}) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: clients ??
          <Map<String, dynamic>>[
            {
              'id': 2,
              'name': 'qb-main',
              'kind': 'qbittorrent',
              'base_url': 'http://qb:8080',
              'username': 'admin',
              'client_save_path': '/downloads',
              'local_root_path': '/mnt/qb',
              'media_library_id': 1,
              'has_password': true,
            },
          ],
    );
  }

  test('build loads first page with default filter', () async {
    enqueueTaskPage([taskJson(id: 1)]);
    enqueueClients();

    final state = await container.read(downloadTaskCenterProvider.future);

    expect(state.paged.items, hasLength(1));
    expect(state.paged.items.first.task.id, 1);
    expect(state.filter, DownloadTaskFilterState.initial);
    expect(state.isReloading, isFalse);
    final taskRequest = bundle.adapter.requests
        .firstWhere((r) => r.uri.path.endsWith('/download-tasks'));
    expect(
      taskRequest.uri.queryParameters,
      containsPair('download_state', 'downloading'),
    );
  });

  test('loadMore appends next page and preserves live overlay', () async {
    enqueueTaskPage([taskJson(id: 1)], total: 3);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    enqueueTaskPage([taskJson(id: 2), taskJson(id: 3)], page: 2, total: 3);

    await container.read(downloadTaskCenterProvider.notifier).loadMore();

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [1, 2, 3]);
    expect(state.paged.hasMore, isFalse);
  });

  test(
    'applyFilter keeps old items visible via isReloading + fetches with new params',
    () async {
      enqueueTaskPage([taskJson(id: 1)]);
      enqueueClients();
      await container.read(downloadTaskCenterProvider.future);

      enqueueTaskPage([taskJson(id: 42, downloadState: 'paused')]);

      final future = container
          .read(downloadTaskCenterProvider.notifier)
          .applyFilter(
            DownloadTaskFilterState.initial.copyWith(
              stateFilter: DownloadTaskStateFilter.paused,
            ),
          );

      // 切换过程中：filter 已更新，isReloading = true，旧 items 仍在。
      final duringSwitch = container
          .read(downloadTaskCenterProvider)
          .requireValue;
      expect(duringSwitch.isReloading, isTrue);
      expect(duringSwitch.filter.stateFilter, DownloadTaskStateFilter.paused);
      expect(duringSwitch.paged.items.first.task.id, 1);

      await future;

      final done = container.read(downloadTaskCenterProvider).requireValue;
      expect(done.isReloading, isFalse);
      expect(done.paged.items.map((row) => row.task.id), [42]);
      expect(
        bundle.adapter.requests.last.uri.queryParameters,
        containsPair('download_state', 'paused'),
      );
    },
  );

  test('applyFilter short-circuits when equal filter is supplied', () async {
    enqueueTaskPage([taskJson(id: 1)]);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    final beforeHits = bundle.adapter.hitCount('GET', '/download-tasks');
    await container
        .read(downloadTaskCenterProvider.notifier)
        .applyFilter(DownloadTaskFilterState.initial);

    expect(bundle.adapter.hitCount('GET', '/download-tasks'), beforeHits);
  });

  test('pauseTask patches downloadState + clears pending on success', () async {
    enqueueTaskPage([taskJson(id: 5)]);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-tasks/5/pause',
      body: <String, dynamic>{},
    );
    await container.read(downloadTaskCenterProvider.notifier).pauseTask(5);

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.single.downloadState, 'paused');
    expect(state.isTaskPending(5), isFalse);
  });

  test('pauseTask turns a seeding task directly into completed', () async {
    enqueueTaskPage([
      taskJson(
        id: 6,
        downloadState: 'seeding',
        importStatus: 'completed',
        progress: 1.0,
      ),
    ]);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-tasks/6/pause',
      body: <String, dynamic>{},
    );
    await container.read(downloadTaskCenterProvider.notifier).pauseTask(6);

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.single.downloadState, 'completed');
    expect(state.isTaskPending(6), isFalse);
  });

  test('resumeTask flips state to downloading', () async {
    enqueueTaskPage([taskJson(id: 7, downloadState: 'paused')]);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-tasks/7/resume',
      body: <String, dynamic>{},
    );
    await container.read(downloadTaskCenterProvider.notifier).resumeTask(7);

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.single.downloadState, 'downloading');
    expect(state.isTaskPending(7), isFalse);
  });

  test('deleteTask removes row + decrements total', () async {
    enqueueTaskPage([taskJson(id: 3), taskJson(id: 4)], total: 5);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/download-tasks/3',
      body: <String, dynamic>{},
    );
    await container
        .read(downloadTaskCenterProvider.notifier)
        .deleteTask(3, deleteFiles: false);

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [4]);
    expect(state.paged.total, 4);
    expect(state.paged.hasMore, isTrue); // 1/4
  });
}
