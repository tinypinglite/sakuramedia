import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'paged_async_notifier.dart';

/// 分页页面本体只关心的字段。
///
/// [PagedListState.isLoadingMore] / [PagedListState.loadMoreErrorMessage] 由
/// 独立页脚订阅，因此不进入本快照。翻页开始/结束时 items 仍是同一个列表，
/// Riverpod 的 record 相等判断会跳过页面重建；只有新一页合并后才通知。
typedef PagedViewSnapshot<T> = ({
  List<T> items,
  int total,
  FilterUpdateState filterUpdate,
  bool isInitialLoading,
  Object? initialError,
});

PagedViewSnapshot<T> pagedViewSnapshot<S, T>(
  AsyncValue<S> asyncState,
  PagedListState<T> Function(S state) pagedOf,
) {
  final state = asyncState.value;
  final paged = state == null ? null : pagedOf(state);
  return (
    items: paged?.items ?? const <Never>[],
    total: paged?.total ?? 0,
    filterUpdate: paged?.filterUpdate ?? const FilterUpdateState.idle(),
    isInitialLoading: asyncState.isLoading && !asyncState.hasValue,
    initialError: asyncState.hasError && !asyncState.hasValue
        ? asyncState.error
        : null,
  );
}
