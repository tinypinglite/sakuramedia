import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_review_provider.dart';

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

  test('首次加载完成前，空列表按骨架处理', () {
    final subscription = container.listen(
      movieDetailReviewProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final state = container.read(movieDetailReviewProvider('ABC-001'));
    expect(state.hasLoaded, isFalse);
    expect(state.isInitialLoading, isFalse);
    expect(state.shouldShowInitialSkeleton, isTrue);
  });

  test('首次加载请求中和成功空结果的状态', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/reviews',
      body: const <Map<String, dynamic>>[],
    );
    final subscription = container.listen(
      movieDetailReviewProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(
      movieDetailReviewProvider('ABC-001').notifier,
    );

    final loadFuture = notifier.loadInitial();
    expect(
      container.read(movieDetailReviewProvider('ABC-001')).isInitialLoading,
      isTrue,
    );
    expect(
      container
          .read(movieDetailReviewProvider('ABC-001'))
          .shouldShowInitialSkeleton,
      isTrue,
    );

    await loadFuture;
    final state = container.read(movieDetailReviewProvider('ABC-001'));
    expect(state.hasLoaded, isTrue);
    expect(state.isInitialLoading, isFalse);
    expect(state.initialErrorMessage, isNull);
    expect(state.shouldShowInitialSkeleton, isFalse);
  });

  test('首次加载失败保留错误态，重试请求中回到骨架', () async {
    bundle.adapter
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/reviews',
        statusCode: 500,
        body: const <String, dynamic>{'detail': 'boom'},
      )
      ..enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/reviews',
        body: const <Map<String, dynamic>>[],
      );
    final subscription = container.listen(
      movieDetailReviewProvider('ABC-001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(
      movieDetailReviewProvider('ABC-001').notifier,
    );

    await notifier.loadInitial();
    final failed = container.read(movieDetailReviewProvider('ABC-001'));
    expect(failed.hasLoaded, isTrue);
    expect(failed.initialErrorMessage, isNotNull);
    expect(failed.shouldShowInitialSkeleton, isFalse);

    final retryFuture = notifier.loadInitial();
    expect(
      container
          .read(movieDetailReviewProvider('ABC-001'))
          .shouldShowInitialSkeleton,
      isTrue,
    );

    await retryFuture;
    final recovered = container.read(movieDetailReviewProvider('ABC-001'));
    expect(recovered.hasLoaded, isTrue);
    expect(recovered.initialErrorMessage, isNull);
    expect(recovered.shouldShowInitialSkeleton, isFalse);
  });
}
