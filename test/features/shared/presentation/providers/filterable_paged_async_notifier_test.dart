import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

typedef _Fetcher =
    Future<PaginatedResponseDto<int>> Function(
      int page,
      int pageSize,
      int filter,
    );

final _fetcherProvider = Provider<_Fetcher>((ref) {
  throw UnimplementedError('override _fetcherProvider in test');
});

class _State {
  const _State({
    required this.paged,
    this.filter = 0,
    this.selected = const <int>{},
  });

  final PagedListState<int> paged;
  final int filter;
  final Set<int> selected;

  _State copyWith({
    PagedListState<int>? paged,
    int? filter,
    Set<int>? selected,
  }) => _State(
    paged: paged ?? this.paged,
    filter: filter ?? this.filter,
    selected: selected ?? this.selected,
  );
}

class _Notifier extends AsyncNotifier<_State>
    with
        PagedAsyncNotifierMixin<_State, int>,
        FilterablePagedAsyncNotifierMixin<_State, int, int> {
  @override
  int get pageSize => 3;

  @override
  Duration get filterDebounceDuration => const Duration(milliseconds: 20);

  @override
  String get initialLoadErrorText => 'initial-err';

  @override
  String get loadMoreErrorText => 'load-more-err';

  @override
  PagedListState<int> pagedOf(_State state) => state.paged;

  @override
  _State applyPaged(_State state, PagedListState<int> paged) =>
      state.copyWith(paged: paged);

  @override
  int get initialFilter => 0;

  @override
  _State applyFilterToState(_State state, int filter) =>
      state.copyWith(filter: filter, selected: const <int>{});

  @override
  Future<PaginatedResponseDto<int>> fetchPage(int page, int pageSize) =>
      ref.read(_fetcherProvider)(page, pageSize, activeFilter);

  @override
  Future<_State> build() async {
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return _State(paged: paged, filter: activeFilter);
  }
}

final _provider = AsyncNotifierProvider<_Notifier, _State>(
  _Notifier.new,
  retry: (_, __) => null,
);

PaginatedResponseDto<int> _page({
  required int page,
  required List<int> items,
  required int total,
}) => PaginatedResponseDto<int>(
  items: items,
  page: page,
  pageSize: 3,
  total: total,
  syncedAt: null,
);

void main() {
  late List<(int, int)> requests;
  late ProviderContainer container;

  setUp(() {
    requests = <(int, int)>[];
    container = ProviderContainer(
      overrides: [
        _fetcherProvider.overrideWithValue((page, pageSize, filter) async {
          requests.add((page, filter));
          return _page(
            page: page,
            items: List<int>.generate(3, (i) => filter * 100 + i),
            total: 3,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  test('筛选条件同步更新并保留旧列表，防抖后原子替换结果', () async {
    await container.read(_provider.future);
    final notifier = container.read(_provider.notifier);
    notifier.state = AsyncData(
      notifier.state.value!.copyWith(selected: const <int>{1, 2}),
    );
    final before = notifier.state.value!.paged.items;

    final future = notifier.applyFilterState(1);
    final during = container.read(_provider).requireValue;
    expect(during.filter, 1);
    expect(during.selected, isEmpty);
    expect(during.paged.items, before);
    expect(during.paged.filterUpdate.isWaiting, isTrue);
    expect(requests, [(1, 0)]);

    await future;
    final after = container.read(_provider).requireValue;
    expect(after.paged.items, [100, 101, 102]);
    expect(after.paged.filterUpdate.isIdle, isTrue);
  });

  test('防抖结束、实际请求开始后才进入 loading', () async {
    final firstPageGate = Completer<PaginatedResponseDto<int>>();
    final staged = ProviderContainer(
      overrides: [
        _fetcherProvider.overrideWithValue((page, pageSize, filter) {
          if (filter == 1) return firstPageGate.future;
          return Future.value(
            _page(
              page: page,
              items: List<int>.generate(3, (i) => filter * 100 + i),
              total: 3,
            ),
          );
        }),
      ],
    );
    addTearDown(staged.dispose);
    await staged.read(_provider.future);

    final future = staged.read(_provider.notifier).applyFilterState(1);
    expect(
      staged.read(_provider).requireValue.paged.filterUpdate.isWaiting,
      isTrue,
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      staged.read(_provider).requireValue.paged.filterUpdate.isLoading,
      isTrue,
    );

    firstPageGate.complete(_page(page: 1, items: const [100], total: 1));
    await future;
    expect(
      staged.read(_provider).requireValue.paged.filterUpdate.isIdle,
      isTrue,
    );
  });

  test('防抖窗口内连续筛选只请求最终条件', () async {
    await container.read(_provider.future);
    final notifier = container.read(_provider.notifier);

    final first = notifier.applyFilterState(1);
    final second = notifier.applyFilterState(2);
    final third = notifier.applyFilterState(3);
    await Future.wait([first, second, third]);

    expect(requests, [(1, 0), (1, 3)]);
    expect(container.read(_provider).requireValue.filter, 3);
    expect(container.read(_provider).requireValue.paged.items, [300, 301, 302]);
  });

  test('旧请求晚返回不会覆盖较新的筛选结果', () async {
    final firstGate = Completer<PaginatedResponseDto<int>>();
    final raced = ProviderContainer(
      overrides: [
        _fetcherProvider.overrideWithValue((page, pageSize, filter) {
          if (filter == 1) return firstGate.future;
          return Future.value(
            _page(page: page, items: [filter * 100], total: 1),
          );
        }),
      ],
    );
    addTearDown(raced.dispose);
    await raced.read(_provider.future);
    final notifier = raced.read(_provider.notifier);

    final first = notifier.applyFilterState(1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final second = notifier.applyFilterState(2);
    await second;
    expect(raced.read(_provider).requireValue.paged.items, [200]);

    firstGate.complete(_page(page: 1, items: const [100], total: 1));
    await first;
    expect(raced.read(_provider).requireValue.filter, 2);
    expect(raced.read(_provider).requireValue.paged.items, [200]);
  });

  test('失败保留旧结果和新筛选，并通过状态提供重试', () async {
    var fail = true;
    final failing = ProviderContainer(
      overrides: [
        _fetcherProvider.overrideWithValue((page, pageSize, filter) async {
          if (filter == 1 && fail) throw Exception('boom');
          return _page(page: page, items: [filter * 100], total: 1);
        }),
      ],
    );
    addTearDown(failing.dispose);
    await failing.read(_provider.future);
    final notifier = failing.read(_provider.notifier);

    await notifier.applyFilterState(1);
    final failed = failing.read(_provider).requireValue;
    expect(failed.filter, 1);
    expect(failed.paged.items, [0]);
    expect(failed.paged.filterUpdate.hasFailed, isTrue);

    fail = false;
    await notifier.retryFilter();
    final retried = failing.read(_provider).requireValue;
    expect(retried.paged.items, [100]);
    expect(retried.paged.filterUpdate.isIdle, isTrue);
  });

  test('筛选更新期间阻止 loadMore，并作废已在途的旧分页', () async {
    final loadMoreGate = Completer<PaginatedResponseDto<int>>();
    var pageTwoCalls = 0;
    final gated = ProviderContainer(
      overrides: [
        _fetcherProvider.overrideWithValue((page, pageSize, filter) async {
          if (page == 2) {
            pageTwoCalls++;
            return loadMoreGate.future;
          }
          return _page(
            page: 1,
            items: [filter * 100, filter * 100 + 1, filter * 100 + 2],
            total: filter == 0 ? 10 : 3,
          );
        }),
      ],
    );
    addTearDown(gated.dispose);
    await gated.read(_provider.future);
    final notifier = gated.read(_provider.notifier);

    final oldLoadMore = notifier.loadMore();
    expect(gated.read(_provider).requireValue.paged.isLoadingMore, isTrue);
    final filterFuture = notifier.applyFilterState(1);
    expect(gated.read(_provider).requireValue.paged.isLoadingMore, isFalse);
    await notifier.loadMore();
    expect(pageTwoCalls, 1);

    await filterFuture;
    loadMoreGate.complete(_page(page: 2, items: const [99], total: 10));
    await oldLoadMore;
    expect(gated.read(_provider).requireValue.paged.items, [100, 101, 102]);
  });

  test('等价筛选短路，不发送请求', () async {
    await container.read(_provider.future);
    await container.read(_provider.notifier).applyFilterState(0);
    expect(requests, [(1, 0)]);
  });

  test('销毁时取消排队请求并正常结束调用 Future', () async {
    await container.read(_provider.future);
    final pending = container.read(_provider.notifier).applyFilterState(1);
    container.dispose();
    await pending;
    expect(requests, [(1, 0)]);
  });
}
