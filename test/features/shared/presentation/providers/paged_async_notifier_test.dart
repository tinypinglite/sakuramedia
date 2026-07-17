import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

typedef _Fetcher =
    Future<PaginatedResponseDto<int>> Function(int page, int pageSize);

/// 测试用 fetcher provider；每个 test 通过 override 塞入具体行为。
final _fetcherProvider = Provider<_Fetcher>((ref) {
  throw UnimplementedError('override _fetcherProvider in test');
});

/// 简单场景：`S == PagedListState<int>`，`pagedOf`/`applyPaged` 恒等。
class _PlainNotifier extends AsyncNotifier<PagedListState<int>>
    with PagedAsyncNotifierMixin<PagedListState<int>, int> {
  @override
  int get pageSize => 3;

  @override
  String get initialLoadErrorText => 'initial-err';

  @override
  String get loadMoreErrorText => 'load-more-err';

  @override
  PagedListState<int> pagedOf(PagedListState<int> state) => state;

  @override
  PagedListState<int> applyPaged(
    PagedListState<int> state,
    PagedListState<int> paged,
  ) => paged;

  @override
  Future<PaginatedResponseDto<int>> fetchPage(int page, int pageSize) =>
      ref.read(_fetcherProvider)(page, pageSize);

  @override
  Future<PagedListState<int>> build() async {
    attachDisposeGuard();
    return loadInitialPage();
  }
}

final _plainProvider =
    AsyncNotifierProvider<_PlainNotifier, PagedListState<int>>(
      _PlainNotifier.new,
      retry: (_, __) => null,
    );

/// 组合场景：S 携带 paged 段 + 额外字段（这里用 `selected` 模拟多选）。
class _CompositeState {
  const _CompositeState({required this.paged, this.selected = const <int>{}});

  final PagedListState<int> paged;
  final Set<int> selected;

  _CompositeState copyWith({PagedListState<int>? paged, Set<int>? selected}) {
    return _CompositeState(
      paged: paged ?? this.paged,
      selected: selected ?? this.selected,
    );
  }
}

class _CompositeNotifier extends AsyncNotifier<_CompositeState>
    with PagedAsyncNotifierMixin<_CompositeState, int> {
  @override
  int get pageSize => 3;

  @override
  String get initialLoadErrorText => 'initial-err';

  @override
  String get loadMoreErrorText => 'load-more-err';

  @override
  PagedListState<int> pagedOf(_CompositeState state) => state.paged;

  @override
  _CompositeState applyPaged(_CompositeState state, PagedListState<int> paged) =>
      state.copyWith(paged: paged);

  @override
  Future<PaginatedResponseDto<int>> fetchPage(int page, int pageSize) =>
      ref.read(_fetcherProvider)(page, pageSize);

  @override
  Future<_CompositeState> build() async {
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return _CompositeState(paged: paged);
  }

  void toggleSelection(int id) {
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.selected);
    if (!next.remove(id)) next.add(id);
    state = AsyncData(current.copyWith(selected: next));
  }
}

final _compositeProvider =
    AsyncNotifierProvider<_CompositeNotifier, _CompositeState>(
      _CompositeNotifier.new,
      retry: (_, __) => null,
    );

ProviderContainer _makeContainer(_Fetcher fetcher) => ProviderContainer(
  overrides: [_fetcherProvider.overrideWithValue(fetcher)],
);

PaginatedResponseDto<int> _page({
  required int page,
  required List<int> items,
  required int total,
  int pageSize = 3,
  DateTime? syncedAt,
}) => PaginatedResponseDto<int>(
  items: items,
  page: page,
  pageSize: pageSize,
  total: total,
  syncedAt: syncedAt,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedListState', () {
    test('fromFirstPage sets hasMore when items < total', () {
      final s = PagedListState<int>.fromFirstPage(
        _page(page: 1, items: [1, 2, 3], total: 5),
      );
      expect(s.items, [1, 2, 3]);
      expect(s.currentPage, 1);
      expect(s.total, 5);
      expect(s.hasMore, isTrue);
    });

    test('fromFirstPage sets hasMore false when items == total', () {
      final s = PagedListState<int>.fromFirstPage(
        _page(page: 1, items: [1], total: 1),
      );
      expect(s.hasMore, isFalse);
    });

    test('copyWith syncedAt sentinel: omit keeps, explicit null clears', () {
      final at = DateTime.parse('2026-01-01T00:00:00');
      final s = PagedListState<int>(items: const [1], syncedAt: at);
      expect(s.copyWith().syncedAt, at);
      expect(s.copyWith(syncedAt: null).syncedAt, isNull);
      final at2 = DateTime.parse('2026-02-02T00:00:00');
      expect(s.copyWith(syncedAt: at2).syncedAt, at2);
    });

    test('copyWith loadMoreErrorMessage sentinel behavior', () {
      final s = PagedListState<int>(
        items: const [1],
        loadMoreErrorMessage: 'e',
      );
      expect(s.copyWith().loadMoreErrorMessage, 'e');
      expect(s.copyWith(loadMoreErrorMessage: null).loadMoreErrorMessage, isNull);
      expect(
        s.copyWith(loadMoreErrorMessage: 'x').loadMoreErrorMessage,
        'x',
      );
    });

    test('equality compares items element-wise', () {
      const a = PagedListState<int>(items: [1, 2, 3], total: 3);
      const b = PagedListState<int>(items: [1, 2, 3], total: 3);
      const c = PagedListState<int>(items: [1, 2], total: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('PagedAsyncNotifierMixin (plain: S == PagedListState<T>)', () {
    test('build loads first page and exposes paged fields', () async {
      final container = _makeContainer(
        (page, size) async => _page(page: 1, items: [1, 2, 3], total: 5),
      );
      addTearDown(container.dispose);

      final state = await container.read(_plainProvider.future);

      expect(state.items, [1, 2, 3]);
      expect(state.currentPage, 1);
      expect(state.total, 5);
      expect(state.hasMore, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.loadMoreErrorMessage, isNull);
    });

    test('build error surfaces as AsyncError (no auto-retry)', () async {
      var calls = 0;
      final container = _makeContainer((page, size) async {
        calls += 1;
        throw StateError('boom');
      });
      addTearDown(container.dispose);

      await container
          .read(_plainProvider.future)
          .catchError((_) => const PagedListState<int>());

      expect(container.read(_plainProvider).hasError, isTrue);
      expect(calls, 1);
      // 无 retry 策略：短暂等待后不会重复调用
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, 1);
      expect(container.read(_plainProvider).value, isNull);
    });

    test('loadMore appends and updates hasMore', () async {
      var call = 0;
      final container = _makeContainer((page, size) async {
        call += 1;
        if (page == 1) return _page(page: 1, items: [1, 2, 3], total: 5);
        if (page == 2) return _page(page: 2, items: [4, 5], total: 5);
        throw StateError('unexpected page $page');
      });
      addTearDown(container.dispose);

      await container.read(_plainProvider.future);
      await container.read(_plainProvider.notifier).loadMore();

      final s = container.read(_plainProvider).requireValue;
      expect(s.items, [1, 2, 3, 4, 5]);
      expect(s.currentPage, 2);
      expect(s.hasMore, isFalse);
      expect(call, 2);
    });

    test('loadMore short-circuits when !hasMore', () async {
      var call = 0;
      final container = _makeContainer((page, size) async {
        call += 1;
        return _page(page: 1, items: [1, 2, 3], total: 3);
      });
      addTearDown(container.dispose);

      await container.read(_plainProvider.future);
      await container.read(_plainProvider.notifier).loadMore();

      expect(call, 1);
    });

    test('loadMore failure preserves items + sets loadMoreErrorMessage', () async {
      final container = _makeContainer((page, size) async {
        if (page == 1) return _page(page: 1, items: [1, 2, 3], total: 6);
        throw StateError('boom');
      });
      addTearDown(container.dispose);

      await container.read(_plainProvider.future);
      await container.read(_plainProvider.notifier).loadMore();

      final s = container.read(_plainProvider).requireValue;
      expect(s.items, [1, 2, 3]);
      expect(s.loadMoreErrorMessage, 'load-more-err');
      expect(s.isLoadingMore, isFalse);
      expect(s.hasMore, isTrue); // items < total
    });

    test('reload clears items and reloads page 1', () async {
      var version = 0;
      final container = _makeContainer((page, size) async {
        version += 1;
        return _page(page: 1, items: [version * 10], total: 1);
      });
      addTearDown(container.dispose);

      await container.read(_plainProvider.future);
      await container.read(_plainProvider.notifier).reload();

      final s = container.read(_plainProvider).requireValue;
      expect(s.items, [20]);
      expect(version, 2);
    });

    test('reload after initial error re-runs build', () async {
      var call = 0;
      final container = _makeContainer((page, size) async {
        call += 1;
        if (call == 1) throw StateError('first fails');
        return _page(page: 1, items: [7], total: 1);
      });
      addTearDown(container.dispose);

      await container
          .read(_plainProvider.future)
          .catchError((_) => const PagedListState<int>());
      expect(container.read(_plainProvider).hasError, isTrue);

      await container.read(_plainProvider.notifier).reload();
      // Wait for the invalidated rebuild.
      await container.read(_plainProvider.future);

      final s = container.read(_plainProvider).requireValue;
      expect(s.items, [7]);
      expect(call, 2);
    });

    test('refresh returns null on success and swaps items atomically', () async {
      var version = 0;
      final container = _makeContainer((page, size) async {
        version += 1;
        return _page(page: 1, items: [version], total: 1);
      });
      addTearDown(container.dispose);

      await container.read(_plainProvider.future);
      final message = await container.read(_plainProvider.notifier).refresh();

      expect(message, isNull);
      final s = container.read(_plainProvider).requireValue;
      expect(s.items, [2]);
    });

    test('refresh returns fallback message on failure and keeps items', () async {
      final container = _makeContainer((page, size) async {
        if (page == 1 && !_refreshFailed) {
          return _page(page: 1, items: [1, 2], total: 2);
        }
        throw StateError('boom');
      });
      addTearDown(container.dispose);

      await container.read(_plainProvider.future);
      _refreshFailed = true;
      final message = await container.read(_plainProvider.notifier).refresh();
      _refreshFailed = false;

      expect(message, 'initial-err');
      final s = container.read(_plainProvider).requireValue;
      expect(s.items, [1, 2]);
    });

    test(
      'reload during in-flight loadMore discards stale response '
      '(no items overwrite)',
      () async {
        // 场景：loadMore 的 page 2 请求还没回来时 reload 触发，
        // reload 用一份「全新的第一页」覆盖 State；loadMore 的旧响应
        // 回来后应该识别到「代次已变」直接丢弃，不把旧 items 拼上去。
        final page2Completer = Completer<PaginatedResponseDto<int>>();
        var page1Calls = 0;
        final container = _makeContainer((page, size) async {
          if (page == 1) {
            page1Calls += 1;
            if (page1Calls == 1) {
              return _page(page: 1, items: [1, 2, 3], total: 6);
            }
            return _page(page: 1, items: [100, 200, 300], total: 3);
          }
          if (page == 2) return page2Completer.future;
          throw StateError('unexpected page $page');
        });
        addTearDown(container.dispose);

        await container.read(_plainProvider.future);

        final loadMoreFuture =
            container.read(_plainProvider.notifier).loadMore();
        // reload 期间 loadMore 尚未回；reload 用新首页覆盖状态。
        await container.read(_plainProvider.notifier).reload();

        final reloaded = container.read(_plainProvider).requireValue;
        expect(reloaded.items, [100, 200, 300]);
        expect(reloaded.hasMore, isFalse);

        // 触发 loadMore 的旧响应回来——它应当被丢弃。
        page2Completer.complete(_page(page: 2, items: [4, 5, 6], total: 6));
        await loadMoreFuture;

        final finalState = container.read(_plainProvider).requireValue;
        expect(finalState.items, [100, 200, 300]);
        expect(finalState.currentPage, 1);
        expect(finalState.total, 3);
        expect(finalState.isLoadingMore, isFalse);
      },
    );

    test('dispose during in-flight loadMore does not throw', () async {
      final completer = Completer<PaginatedResponseDto<int>>();
      final container = _makeContainer((page, size) async {
        if (page == 1) return _page(page: 1, items: [1], total: 3);
        return completer.future;
      });

      await container.read(_plainProvider.future);
      final future = container.read(_plainProvider.notifier).loadMore();
      container.dispose();
      completer.complete(_page(page: 2, items: [2], total: 3));

      // Should not throw even though state is written after dispose is guarded.
      await future;
    });
  });

  group('PagedAsyncNotifierMixin (composite: S carries extra fields)', () {
    test('loadMore preserves selection set from other mutations', () async {
      final container = _makeContainer((page, size) async {
        if (page == 1) return _page(page: 1, items: [1, 2, 3], total: 5);
        return _page(page: 2, items: [4, 5], total: 5);
      });
      addTearDown(container.dispose);

      await container.read(_compositeProvider.future);
      container.read(_compositeProvider.notifier).toggleSelection(2);
      await container.read(_compositeProvider.notifier).loadMore();

      final s = container.read(_compositeProvider).requireValue;
      expect(s.paged.items, [1, 2, 3, 4, 5]);
      expect(s.selected, {2}); // selection preserved through loadMore
    });

    test('reload with updateBaseState applies patch before fetching', () async {
      final container = _makeContainer(
        (page, size) async => _page(page: 1, items: [1], total: 1),
      );
      addTearDown(container.dispose);

      await container.read(_compositeProvider.future);
      container.read(_compositeProvider.notifier).toggleSelection(99);
      expect(container.read(_compositeProvider).requireValue.selected, {99});

      await container.read(_compositeProvider.notifier).reload(
        updateBaseState: (s) => s.copyWith(selected: const <int>{}),
      );

      final s = container.read(_compositeProvider).requireValue;
      expect(s.selected, isEmpty);
      expect(s.paged.items, [1]);
    });
  });
}

bool _refreshFailed = false;
