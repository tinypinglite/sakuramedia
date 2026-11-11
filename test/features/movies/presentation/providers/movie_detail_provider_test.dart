import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';

import '../../../../support/test_api_bundle.dart';

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
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: bundle.riverpodOverrides(),
      retry: null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
  });

  test('load 上报浏览；refresh 不上报，页面手势 reportView 才补报', () async {
    bundle.adapter
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: const <String, dynamic>{'items': <dynamic>[]},
      )
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: const <String, dynamic>{'items': <dynamic>[]},
      );
    final subscription = container.listen(
      movieDetailProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(movieDetailProvider('ABC-001').notifier).load();
    await _waitForViewHistoryPosts(bundle, 1);
    expect(bundle.adapter.hitCount('POST', '/view-history'), 1);
    expect(_lastViewHistoryBody(bundle), <String, dynamic>{
      'entity_type': 'movie',
      'entity_id': 5,
    });

    // refresh 也服务后台同步（媒体管理页删版本），不能顺带上报。
    await container.read(movieDetailProvider('ABC-001').notifier).refresh();
    await _settle();
    expect(bundle.adapter.hitCount('POST', '/view-history'), 1);

    // 页面手势刷新成功后由页面显式补报。
    container.read(movieDetailProvider('ABC-001').notifier).reportView();
    await _waitForViewHistoryPosts(bundle, 2);
    expect(_lastViewHistoryBody(bundle), <String, dynamic>{
      'entity_type': 'movie',
      'entity_id': 5,
    });
  });

  test('load 暖重进不闪骨架：不置 isLoading、不清空相似影片', () async {
    bundle.adapter
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: <dynamic>[_similarJson()],
      )
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: <dynamic>[_similarJson()],
      );
    final subscription = container.listen(
      movieDetailProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(movieDetailProvider('ABC-001').notifier);

    await notifier.load();
    expect(container.read(movieDetailProvider('ABC-001')).movie, isNotNull);
    expect(
      container.read(movieDetailProvider('ABC-001')).similarMovies,
      hasLength(1),
    );

    // 记录暖重进期间所有状态：isLoading 不得为 true，相似列表不得被清空。
    final seen = <MovieDetailState>[];
    final warmSubscription = container.listen<MovieDetailState>(
      movieDetailProvider('ABC-001'),
      (_, next) => seen.add(next),
    );
    addTearDown(warmSubscription.close);

    await notifier.load();
    await _settle();

    expect(seen.any((state) => state.isLoading), isFalse);
    expect(seen.any((state) => state.similarMovies.isEmpty), isFalse);
    expect(
      container.read(movieDetailProvider('ABC-001')).similarMovies,
      hasLength(1),
    );
    // 暖重进照样静默刷新并上报，与过去每次进入上报保持一致。
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001'), 2);
    await _waitForViewHistoryPosts(bundle, 2);
    expect(bundle.adapter.hitCount('POST', '/view-history'), 2);
  });

  test('load 暖重进失败保留旧内容', () async {
    bundle.adapter
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: const <String, dynamic>{'items': <dynamic>[]},
      )
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        statusCode: 500,
        body: const <String, dynamic>{'detail': 'boom'},
      );
    final subscription = container.listen(
      movieDetailProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(movieDetailProvider('ABC-001').notifier);

    await notifier.load();
    expect(container.read(movieDetailProvider('ABC-001')).movie, isNotNull);

    // 暖重进的后台同步失败：旧内容常驻，不进 error。
    await notifier.load();
    await _settle();

    final state = container.read(movieDetailProvider('ABC-001'));
    expect(state.movie, isNotNull);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('并发 refresh 共享在途请求', () async {
    bundle.adapter
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: const <String, dynamic>{'items': <dynamic>[]},
      )
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: const <String, dynamic>{'items': <dynamic>[]},
      );
    final subscription = container.listen(
      movieDetailProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(movieDetailProvider('ABC-001').notifier);

    await notifier.load();
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001'), 1);

    // 两个并发 refresh 共享在途 Future：详情与相似影片都只再发一次。
    await Future.wait<void>([notifier.refresh(), notifier.refresh()]);
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001'), 2);
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001/similar'), 2);
  });

  test('reportView 成功后 invalidate 最近浏览列表', () async {
    bundle.adapter
      ..enqueueJson(method: 'GET', path: '/movies/ABC-001', body: _movieJson())
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: const <String, dynamic>{'items': <dynamic>[]},
      )
      ..enqueueJson(method: 'POST', path: '/view-history', statusCode: 204)
      ..enqueueJson(
        method: 'GET',
        path: '/view-history',
        body: const <String, dynamic>{'items': <dynamic>[]},
      )
      ..enqueueJson(
        method: 'GET',
        path: '/view-history',
        body: const <String, dynamic>{'items': <dynamic>[]},
      );
    final detailSubscription = container.listen(
      movieDetailProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(detailSubscription.close);
    final viewsSubscription = container.listen(
      recentViewsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(viewsSubscription.close);

    await container.read(movieDetailProvider('ABC-001').notifier).load();
    await _waitForViewHistoryPosts(bundle, 1);

    // 上报成功触发的 invalidate 让存活的「最近浏览」重拉一次。
    for (
      var attempt = 0;
      attempt < 100 && bundle.adapter.hitCount('GET', '/view-history') < 2;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(bundle.adapter.hitCount('GET', '/view-history'), 2);
  });
}

Map<String, dynamic> _similarJson() => <String, dynamic>{
  'movie_number': 'SIM-001',
  'title': 'Similar movie',
  'cover_image': null,
  'release_date': '2024-01-02',
  'duration_minutes': 120,
  'heat': 18,
  'is_subscribed': true,
  'can_play': true,
  'similarity_score': 0.91,
};

Map<String, dynamic> _lastViewHistoryBody(TestApiBundle bundle) {
  return bundle.adapter.requests
          .lastWhere(
            (request) =>
                request.method == 'POST' && request.path == '/view-history',
          )
          .body
      as Map<String, dynamic>;
}

Future<void> _waitForViewHistoryPosts(
  TestApiBundle bundle,
  int expected,
) async {
  for (
    var attempt = 0;
    attempt < 100 &&
        bundle.adapter.hitCount('POST', '/view-history') < expected;
    attempt++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Map<String, dynamic> _movieJson() => <String, dynamic>{
  'id': 5,
  'movie_number': 'ABC-001',
  'title': 'Movie 1',
  'cover_image': null,
  'release_date': '2024-01-02',
  'duration_minutes': 120,
  'is_collection': false,
  'is_subscribed': true,
  'can_play': true,
  'summary': '',
  'actors': const <Map<String, dynamic>>[],
  'tags': const <Map<String, dynamic>>[],
  'plot_images': const <Map<String, dynamic>>[],
  'media_items': const <Map<String, dynamic>>[],
  'playlists': const <Map<String, dynamic>>[],
};
