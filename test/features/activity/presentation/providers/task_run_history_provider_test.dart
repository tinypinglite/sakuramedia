import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/providers/task_run_history_provider.dart';

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

  test('build reads page 1 with task_key and full run scope', () async {
    final subscription = container.listen(
      taskRunHistoryProvider('media_import'),
      (_, __) {},
    );
    addTearDown(subscription.close);
    _enqueuePage(bundle, page: 1, ids: <int>[31, 30], total: 3);

    final state = await container.read(
      taskRunHistoryProvider('media_import').future,
    );

    expect(state.runs.map((run) => run.id), <int>[31, 30]);
    expect(state.nextPage, 2);
    expect(state.hasMore, isTrue);
    expect(state.canAutoLoadMore, isTrue);

    final request = bundle.adapter.requests.single;
    expect(request.path, '/system/task-runs');
    expect(request.uri.queryParameters['task_key'], 'media_import');
    expect(request.uri.queryParameters['scope'], 'all');
    expect(request.uri.queryParameters['page'], '1');
    expect(request.uri.queryParameters['page_size'], '20');
    expect(request.uri.queryParameters['sort'], 'started_at:desc');
  });

  test('loadMore appends the next page without duplicates', () async {
    final subscription = container.listen(
      taskRunHistoryProvider('media_import'),
      (_, __) {},
    );
    addTearDown(subscription.close);
    _enqueuePage(bundle, page: 1, ids: <int>[31, 30], total: 3);
    await container.read(taskRunHistoryProvider('media_import').future);

    _enqueuePage(bundle, page: 2, ids: <int>[30, 29], total: 3);
    final controller = container.read(
      taskRunHistoryProvider('media_import').notifier,
    );
    await controller.loadMore();

    final state = container
        .read(taskRunHistoryProvider('media_import'))
        .requireValue;
    expect(state.runs.map((run) => run.id), <int>[31, 30, 29]);
    expect(state.nextPage, 3);
    expect(state.hasMore, isFalse);
    expect(
      bundle.adapter.requests.last.uri.queryParameters['task_key'],
      'media_import',
    );
    expect(bundle.adapter.requests.last.uri.queryParameters['scope'], 'all');
  });

  test('loadMore stops when the next page only repeats loaded ids', () async {
    final subscription = container.listen(
      taskRunHistoryProvider('media_import'),
      (_, __) {},
    );
    addTearDown(subscription.close);
    _enqueuePage(bundle, page: 1, ids: <int>[31, 30], total: 3);
    await container.read(taskRunHistoryProvider('media_import').future);

    _enqueuePage(
      bundle,
      page: 2,
      ids: <int>[31, 30],
      total: 3,
      taskName: '媒体导入（已更新）',
    );
    final controller = container.read(
      taskRunHistoryProvider('media_import').notifier,
    );
    await controller.loadMore();

    var state = container
        .read(taskRunHistoryProvider('media_import'))
        .requireValue;
    expect(state.runs.map((run) => run.id), <int>[31, 30]);
    expect(state.hasMore, isFalse);
    expect(state.isLoadingMore, isFalse);

    await controller.loadMore();
    expect(bundle.adapter.requests, hasLength(2));
  });

  test('refresh replaces the first page and clears errors', () async {
    final subscription = container.listen(
      taskRunHistoryProvider('media_import'),
      (_, __) {},
    );
    addTearDown(subscription.close);
    _enqueuePage(bundle, page: 1, ids: <int>[31], total: 2);
    await container.read(taskRunHistoryProvider('media_import').future);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      statusCode: 500,
      body: const <String, dynamic>{'detail': 'boom'},
    );
    final controller = container.read(
      taskRunHistoryProvider('media_import').notifier,
    );
    await controller.loadMore();
    var state = container
        .read(taskRunHistoryProvider('media_import'))
        .requireValue;
    expect(state.loadMoreErrorMessage, isNotNull);
    expect(state.canAutoLoadMore, isFalse);

    _enqueuePage(bundle, page: 1, ids: <int>[40, 39], total: 2);
    await controller.refresh();

    state = container.read(taskRunHistoryProvider('media_import')).requireValue;
    expect(state.runs.map((run) => run.id), <int>[40, 39]);
    expect(state.loadMoreErrorMessage, isNull);
    expect(state.refreshErrorMessage, isNull);
  });

  test('initial failure surfaces through the AsyncNotifier', () async {
    final subscription = container.listen(
      taskRunHistoryProvider('media_import'),
      (_, __) {},
    );
    addTearDown(subscription.close);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      statusCode: 500,
      body: const <String, dynamic>{'detail': 'boom'},
    );

    await expectLater(
      container.read(taskRunHistoryProvider('media_import').future),
      throwsA(isA<Object>()),
    );
    expect(
      container.read(taskRunHistoryProvider('media_import')).hasError,
      isTrue,
    );
    // 历史弹层不参与轮询：只发了首屏一次请求。
    expect(bundle.adapter.requests, hasLength(1));
  });
}

void _enqueuePage(
  TestApiBundle bundle, {
  required int page,
  required List<int> ids,
  required int total,
  String taskName = '媒体导入',
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/task-runs',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        for (final id in ids) _taskRunJson(id: id, taskName: taskName),
      ],
      'page': page,
      'page_size': 20,
      'total': total,
    },
  );
}

Map<String, dynamic> _taskRunJson({
  required int id,
  String taskName = '媒体导入',
}) => <String, dynamic>{
  'id': id,
  'task_key': 'media_import',
  'task_name': taskName,
  'trigger_type': 'manual',
  'state': 'completed',
  'progress_current': 2,
  'progress_total': 2,
  'created_at': '2026-03-26T09:10:00Z',
  'updated_at': '2026-03-26T09:11:00Z',
};
