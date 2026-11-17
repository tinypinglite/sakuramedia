import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore session;
  late TestApiBundle bundle;
  late ProviderContainer container;
  late List<MovieMediaChange> mediaChanges;
  late List<MovieSubscriptionChange> subscriptionChanges;
  setUp(() async {
    session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime(2099),
    );
    bundle = await createTestApiBundle(session);
    container = ProviderContainer(overrides: bundle.riverpodOverrides());
    mediaChanges = [];
    subscriptionChanges = [];
    container.listen(movieMediaEventsProvider, (_, next) {
      if (next.hasValue) mediaChanges.add(next.requireValue);
    });
    container.listen(movieSubscriptionEventsProvider, (_, next) {
      if (next.hasValue) subscriptionChanges.addAll(next.requireValue);
    });
  });
  tearDown(() {
    container.dispose();
    bundle.dispose();
    session.dispose();
  });

  void detail(String number, List<int> ids, {bool? canPlay}) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/$number',
      body: {
        'movie_number': number,
        'can_play': canPlay ?? ids.isNotEmpty,
        'is_subscribed': true,
        'media_items': [
          for (final id in ids) {'media_id': id, 'valid': false},
        ],
      },
    );
  }

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('按番号和媒体顺序串行删除，全部完成后一次批量取消且广播状态', () async {
    detail('A-1', [11, 12]);
    detail('A-1', []);
    detail('B-2', [21]);
    detail('B-2', []);
    final deleting = Completer<void>();
    final started = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'DELETE',
      path: '/media/11',
      responder: (_, _) async {
        started.complete();
        await deleting.future;
        return ResponseBody.fromBytes([], 204);
      },
    );
    for (final id in [12, 21]) {
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/$id',
        statusCode: 204,
      );
    }
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/unsubscriptions',
      body: {'requested_count': 2, 'updated_count': 2, 'skipped': []},
    );
    final notifier = container.read(movieSubscriptionToggleProvider.notifier);
    final progress = <MovieForceUnsubscribeProgress>[];
    final pending = notifier.forceUnsubscribeBatch([
      'A-1',
      'A-1',
      'B-2',
    ], onProgress: progress.add);
    await started.future;
    expect(container.read(movieSubscriptionToggleProvider), {'A-1', 'B-2'});
    expect(bundle.adapter.requests.map((r) => r.path), [
      '/movies/A-1',
      '/movies/B-2',
      '/media/11',
    ]);
    final duplicate = await notifier.forceUnsubscribeBatch(['A-1']);
    expect(duplicate.hasError, isTrue);
    deleting.complete();
    final result = await pending;
    await settle();
    expect(result.updatedCount, 2);
    expect(result.hasError, isFalse);
    expect(bundle.adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'GET /movies/A-1',
      'GET /movies/B-2',
      'DELETE /media/11',
      'DELETE /media/12',
      'GET /movies/A-1',
      'DELETE /media/21',
      'GET /movies/B-2',
      'POST /movies/unsubscriptions',
    ]);
    expect(bundle.adapter.requests.last.body, {
      'movie_numbers': ['A-1', 'B-2'],
    });
    expect(progress.take(2).map((p) => p.value), [null, null]);
    expect(progress.where((p) => p.value != null).map((p) => p.value), [
      0,
      1 / 3,
      1 / 3,
      2 / 3,
      2 / 3,
      1,
      1,
    ]);
    expect(progress.last.message, contains('正在批量取消订阅'));
    expect(mediaChanges.map((c) => c.canPlay), [false, false]);
    expect(subscriptionChanges.map((c) => c.movieNumber), ['A-1', 'B-2']);
    expect(subscriptionChanges.every((c) => !c.isSubscribed), isTrue);
    // 强制取消属于批量清场：广播必须携带来源标记供状态筛选视图即时移除。
    expect(subscriptionChanges.every((c) => c.fromBatch), isTrue);
    expect(container.read(movieSubscriptionToggleProvider), isEmpty);
  });

  test('删除中途失败停止后续操作，刷新实际媒体状态，重试只删除剩余媒体', () async {
    detail('A-1', [11, 12]);
    detail('A-1', [12], canPlay: false);
    detail('B-2', [21]);
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media/11',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media/12',
      statusCode: 500,
    );
    final notifier = container.read(movieSubscriptionToggleProvider.notifier);
    final result = await notifier.forceUnsubscribeBatch(['A-1', 'B-2']);
    await settle();
    expect(result.hasError, isTrue);
    expect(result.errorMessage, contains('已删除 1 个媒体'));
    expect(bundle.adapter.hitCount('POST', '/movies/unsubscriptions'), 0);
    expect(bundle.adapter.hitCount('DELETE', '/media/21'), 0);
    expect(subscriptionChanges, isEmpty);
    expect(mediaChanges.single.canPlay, isFalse);
    expect(container.read(movieSubscriptionToggleProvider), isEmpty);
    detail('A-1', [12]);
    detail('A-1', []);
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media/12',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/unsubscriptions',
      body: {'requested_count': 1, 'updated_count': 1, 'skipped': []},
    );
    expect((await notifier.forceUnsubscribeBatch(['A-1'])).hasError, isFalse);
    expect(bundle.adapter.hitCount('DELETE', '/media/11'), 1);
  });

  test('读取后续影片媒体失败也不开始删除', () async {
    detail('A-1', [11]);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/B-2',
      statusCode: 500,
    );
    final result = await container
        .read(movieSubscriptionToggleProvider.notifier)
        .forceUnsubscribeBatch(['A-1', 'B-2']);
    expect(result.hasError, isTrue);
    expect(bundle.adapter.requests.length, 2);
    expect(container.read(movieSubscriptionToggleProvider), isEmpty);
  });

  test('最终批量取消失败保留订阅，媒体状态仍反映已删除结果', () async {
    detail('A-1', [11]);
    detail('A-1', []);
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media/11',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/unsubscriptions',
      statusCode: 500,
    );
    final result = await container
        .read(movieSubscriptionToggleProvider.notifier)
        .forceUnsubscribeBatch(['A-1']);
    await settle();
    expect(result.errorMessage, contains('媒体已清理，但批量取消订阅失败'));
    expect(mediaChanges.single.canPlay, isFalse);
    expect(mediaChanges.single.isSubscribed, isTrue);
    expect(subscriptionChanges, isEmpty);
  });

  test('取消阶段仍被后端跳过的影片不广播取消，空输入无请求', () async {
    final notifier = container.read(movieSubscriptionToggleProvider.notifier);
    expect((await notifier.forceUnsubscribeBatch([])).requestedCount, 0);
    expect(bundle.adapter.requests, isEmpty);
    detail('A-1', []);
    detail('A-1', []);
    detail('B-2', []);
    detail('B-2', []);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/unsubscriptions',
      body: {
        'requested_count': 2,
        'updated_count': 1,
        'skipped': [
          {'movie_number': 'B-2', 'reason': 'has_media'},
        ],
      },
    );
    final result = await notifier.forceUnsubscribeBatch(['A-1', 'B-2']);
    await settle();
    expect(result.skippedHasMediaNumbers, ['B-2']);
    expect(subscriptionChanges.single.movieNumber, 'A-1');
    expect(subscriptionChanges.single.fromBatch, isTrue);
    expect(bundle.adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });
}
