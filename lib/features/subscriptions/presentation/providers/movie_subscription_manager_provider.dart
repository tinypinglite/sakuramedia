import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_status_counts_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscriptions_api_provider.dart';

part 'movie_subscription_manager_provider.g.dart';

/// 「订阅管理」页的列表控制器。
///
/// 职责边界：
/// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
/// - **重置**资源查询状态走本域 `/movie-subscriptions/search-resets`；
/// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
///   端点，这里也不绕过它。
///
/// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
/// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
/// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
/// 不整页重拉。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class MovieSubscriptionManager extends _$MovieSubscriptionManager
    with
        PagedAsyncNotifierMixin<
          MovieSubscriptionManagerState,
          MovieSubscriptionListItemDto
        >,
        FilterablePagedAsyncNotifierMixin<
          MovieSubscriptionManagerState,
          MovieSubscriptionListItemDto,
          MovieSubscriptionFilterState
        > {
  @override
  MovieSubscriptionFilterState get initialFilter =>
      MovieSubscriptionFilterState.initial;

  @override
  int get pageSize => 20;

  @override
  String get initialLoadErrorText => '订阅列表加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多订阅失败，请点击重试';

  @override
  PagedListState<MovieSubscriptionListItemDto> pagedOf(
    MovieSubscriptionManagerState s,
  ) => s.paged;

  @override
  MovieSubscriptionManagerState applyPaged(
    MovieSubscriptionManagerState s,
    PagedListState<MovieSubscriptionListItemDto> paged,
  ) => s.copyWith(paged: paged);

  @override
  Future<PaginatedResponseDto<MovieSubscriptionListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    final filter = activeFilter;
    return ref
        .read(movieSubscriptionsApiProvider)
        .getSubscriptions(
          page: page,
          pageSize: pageSize,
          status: filter.status,
          sort: filter.sort,
          search: filter.trimmedSearch,
        );
  }

  @override
  Future<MovieSubscriptionManagerState> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    // 页面离开后本 provider 没有监听者，Riverpod 会**挂起**这条入站订阅——但底层
    // 是 `StreamSubscription.pause()`，事件会缓冲、在页面回来恢复监听时补投，
    // 所以离屏期间别处的取消订阅不会丢，只是延到回来那一刻打补丁。
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final changes = next.value;
      if (changes != null) {
        _applyExternalSubscriptionChanges(changes);
      }
    });
    final paged = await loadInitialPage();
    return MovieSubscriptionManagerState.initial.copyWith(
      paged: paged,
      filter: activeFilter,
    );
  }

  // --- 筛选 -----------------------------------------------------------------

  /// 切换状态分段签。
  Future<void> applyStatus(MovieSubscriptionStatus? status) {
    return applyFilterState(activeFilter.copyWith(status: status));
  }

  @override
  MovieSubscriptionManagerState applyFilterToState(
    MovieSubscriptionManagerState state,
    MovieSubscriptionFilterState filter,
  ) => state.copyWith(
    filter: filter,
    selectionMode: false,
    selectedMovieNumbers: const <String>{},
  );

  @override
  Future<String?> refresh() async {
    unawaited(
      ref.read(movieSubscriptionStatusCountsProvider.notifier).refresh(),
    );
    return super.refresh();
  }

  // --- 多选 -----------------------------------------------------------------

  void enterSelectionMode() {
    final current = state.value;
    if (current == null || current.selectionMode) return;
    state = AsyncData(current.copyWith(selectionMode: true));
  }

  void exitSelectionMode() {
    final current = state.value;
    if (current == null || !current.selectionMode) return;
    state = AsyncData(
      current.copyWith(
        selectionMode: false,
        selectedMovieNumbers: const <String>{},
      ),
    );
  }

  void toggleSelection(String movieNumber) {
    final current = state.value;
    if (current == null) return;
    final next = Set<String>.of(current.selectedMovieNumbers);
    if (!next.remove(movieNumber)) next.add(movieNumber);
    state = AsyncData(current.copyWith(selectedMovieNumbers: next));
  }

  /// 全选 / 取消全选**当前已加载**的条目（非叠加所有页）。
  ///
  /// 已全选时再点即清空，对应工具条上「全选 ↔ 取消全选」的同一个按钮。
  void toggleSelectAllLoaded() {
    final current = state.value;
    if (current == null) return;
    final loaded = current.paged.items
        .map((item) => item.movieNumber)
        .where((number) => number.isNotEmpty)
        .toSet();
    final alreadyAll =
        loaded.isNotEmpty &&
        loaded.every(current.selectedMovieNumbers.contains);
    state = AsyncData(
      current.copyWith(
        selectedMovieNumbers: alreadyAll ? const <String>{} : loaded,
      ),
    );
  }

  void clearSelection() {
    final current = state.value;
    if (current == null || current.selectedMovieNumbers.isEmpty) return;
    state = AsyncData(current.copyWith(selectedMovieNumbers: const <String>{}));
  }

  // --- 重置订阅搜索状态 -------------------------------------------------------

  /// 重置指定影片的搜索状态（行内单条动作）。
  Future<MovieSubscriptionActionResult> resetSearch(String movieNumber) async {
    _markPending(<String>{movieNumber});
    try {
      return await _resetSearch(<String>[movieNumber]);
    } finally {
      _unmarkPending(<String>{movieNumber});
    }
  }

  /// 一键把全部「已放弃」的影片放回查询队列（不依赖多选）。
  Future<MovieSubscriptionActionResult> resetAllExhausted() async {
    final current = state.value;
    if (current != null && current.isBatchRunning) {
      return const MovieSubscriptionActionResult.success(0);
    }
    _setBatchAction(MovieSubscriptionBatchAction.resetAllExhausted);
    try {
      final response = await ref
          .read(movieSubscriptionsApiProvider)
          .resetSearches();
      unawaited(
        ref.read(movieSubscriptionStatusCountsProvider.notifier).refresh(),
      );
      await reload(
        updateBaseState: (s) => s.copyWith(
          selectionMode: false,
          selectedMovieNumbers: const <String>{},
        ),
      );
      return MovieSubscriptionActionResult.success(response.resetCount);
    } catch (error) {
      return MovieSubscriptionActionResult.failure(_resetErrorMessage(error));
    } finally {
      _setBatchAction(null);
    }
  }

  /// 调搜索重置接口后刷新当前列表。
  Future<MovieSubscriptionActionResult> _resetSearch(
    List<String> movieNumbers,
  ) async {
    // 后端 reset 接口收整数 movie id；选中项来自当前列表，直接映射。
    final items =
        state.value?.paged.items ?? const <MovieSubscriptionListItemDto>[];
    final numbers = movieNumbers.toSet();
    final numberById = <int, String>{
      for (final item in items)
        if (numbers.contains(item.movieNumber) && item.movieId > 0)
          item.movieId: item.movieNumber,
    };
    if (numberById.isEmpty) {
      return const MovieSubscriptionActionResult.success(0);
    }
    try {
      final response = await ref
          .read(movieSubscriptionsApiProvider)
          .resetSearches(movieIds: numberById.keys.toList(growable: false));
      await reload(
        updateBaseState: (s) => s.copyWith(
          selectionMode: false,
          selectedMovieNumbers: const <String>{},
        ),
      );
      unawaited(
        ref.read(movieSubscriptionStatusCountsProvider.notifier).refresh(),
      );
      return MovieSubscriptionActionResult.success(response.resetCount);
    } catch (error) {
      return MovieSubscriptionActionResult.failure(_resetErrorMessage(error));
    }
  }

  String _resetErrorMessage(Object error) {
    return apiErrorMessage(error, fallback: '重置订阅搜索状态失败');
  }

  // --- 取消订阅 --------------------------------------------------------------

  /// 取消订阅单条。返回值交给 `showMovieSubscriptionFeedback` 统一 toast。
  Future<MovieSubscriptionToggleResult> unsubscribe(String movieNumber) async {
    final current = state.value;
    if (current == null || current.isPending(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }
    _markPending(<String>{movieNumber});
    try {
      await ref
          .read(moviesApiProvider)
          .unsubscribeMovie(movieNumber: movieNumber);
      _removeRows(<String>{movieNumber});
      _broadcastUnsubscribed(<String>[movieNumber]);
      return const MovieSubscriptionToggleResult.unsubscribed();
    } catch (error) {
      if (isMovieSubscriptionBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(error, fallback: '取消订阅影片失败'),
      );
    } finally {
      _unmarkPending(<String>{movieNumber});
    }
  }

  /// 批量取消订阅已选影片，走后端「部分成功」语义。
  ///
  /// 被跳过的番号（库中无此番号 / 存在本地 media）**保持选中**，方便用户看清哪些
  /// 没处理并接着操作；结果交给 `showMovieSubscriptionBatchFeedback` 展开清单。
  Future<MovieSubscriptionBatchToggleResult> batchUnsubscribe() async {
    final current = state.value;
    if (current == null || current.isBatchRunning) {
      return const MovieSubscriptionBatchToggleResult(
        requestedCount: 0,
        updatedCount: 0,
        skippedMovieNotFoundNumbers: <String>[],
        skippedHasMediaNumbers: <String>[],
      );
    }
    // 按列表顺序取，保证反馈清单的番号顺序与用户看到的一致。
    final targets = current.paged.items
        .map((item) => item.movieNumber)
        .where(current.selectedMovieNumbers.contains)
        .toList(growable: false);
    if (targets.isEmpty) {
      return const MovieSubscriptionBatchToggleResult(
        requestedCount: 0,
        updatedCount: 0,
        skippedMovieNotFoundNumbers: <String>[],
        skippedHasMediaNumbers: <String>[],
      );
    }

    _setBatchAction(MovieSubscriptionBatchAction.unsubscribe);
    try {
      final response = await ref
          .read(moviesApiProvider)
          .batchUnsubscribeMovies(movieNumbers: targets);
      final skippedNotFound = response.movieNumbersSkippedBecause(
        MovieSubscriptionSkipReason.movieNotFound,
      );
      final skippedHasMedia = response.movieNumbersSkippedBecause(
        MovieSubscriptionSkipReason.hasMedia,
      );
      final skipped = <String>{...skippedNotFound, ...skippedHasMedia};
      final accepted = targets
          .where((number) => !skipped.contains(number))
          .toList();

      _removeRows(accepted.toSet(), keepSelected: skipped);
      if (accepted.isNotEmpty) {
        _broadcastUnsubscribed(accepted);
      }
      return MovieSubscriptionBatchToggleResult(
        requestedCount: response.requestedCount,
        updatedCount: response.updatedCount,
        skippedMovieNotFoundNumbers: skippedNotFound,
        skippedHasMediaNumbers: skippedHasMedia,
      );
    } catch (error) {
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: targets.length,
        message: apiErrorMessage(error, fallback: '批量取消订阅影片失败'),
      );
    } finally {
      _setBatchAction(null);
    }
  }

  // --- 内部补丁 --------------------------------------------------------------

  /// 广播给其它页面。
  ///
  /// 这条广播绕一圈也会回到本页的 [movieSubscriptionEventsProvider] 监听（届时
  /// 行已移除，补丁是空操作），并在那里统一触发计数刷新——所以本方法不自己刷计数。
  void _broadcastUnsubscribed(List<String> movieNumbers) {
    final notifier = ref.read(movieSubscriptionEventsProvider.notifier);
    if (movieNumbers.length == 1) {
      notifier.reportChange(
        movieNumber: movieNumbers.single,
        isSubscribed: false,
      );
      return;
    }
    notifier.reportBatch(<MovieSubscriptionChange>[
      for (final number in movieNumbers)
        MovieSubscriptionChange(movieNumber: number, isSubscribed: false),
    ]);
  }

  /// 消费全局订阅变更广播。
  ///
  /// 取消订阅 → 该行从本页消失（本页只列订阅中的影片）。新增订阅无法就地插入
  /// （拿不到它的资源查询状态，硬造一行会显示错误进度），只刷新计数让角标先对上，
  /// 行本身等下次 reload 自然出现。
  void _applyExternalSubscriptionChanges(
    List<MovieSubscriptionChange> changes,
  ) {
    final removed = <String>{
      for (final change in changes)
        if (!change.isSubscribed) change.movieNumber,
    };
    if (removed.isNotEmpty) {
      _removeRows(removed);
    }
    unawaited(
      ref.read(movieSubscriptionStatusCountsProvider.notifier).refresh(),
    );
  }

  /// 移除若干行 + 同步扣减 total、重算 hasMore、清理多选与进行中集合。
  ///
  /// [keepSelected] 里的番号即使被清出多选集合也会被放回——批量取消订阅要让被
  /// 跳过的项保持选中。
  void _removeRows(Set<String> movieNumbers, {Set<String>? keepSelected}) {
    final current = state.value;
    if (current == null || movieNumbers.isEmpty) return;

    final nextItems = current.paged.items
        .where((item) => !movieNumbers.contains(item.movieNumber))
        .toList(growable: false);
    final removedCount = current.paged.items.length - nextItems.length;

    final nextSelected = Set<String>.of(current.selectedMovieNumbers)
      ..removeAll(movieNumbers);
    if (keepSelected != null) {
      nextSelected.addAll(
        keepSelected.where(current.selectedMovieNumbers.contains),
      );
    }
    final nextPending = Set<String>.of(current.pendingMovieNumbers)
      ..removeAll(movieNumbers);

    if (removedCount <= 0) {
      state = AsyncData(
        current.copyWith(
          selectedMovieNumbers: nextSelected,
          pendingMovieNumbers: nextPending,
        ),
      );
      return;
    }

    final nextTotal = (current.paged.total - removedCount).clamp(
      0,
      current.paged.total,
    );
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          items: List<MovieSubscriptionListItemDto>.unmodifiable(nextItems),
          total: nextTotal,
          hasMore: nextItems.length < nextTotal,
        ),
        selectedMovieNumbers: nextSelected,
        pendingMovieNumbers: nextPending,
      ),
    );
  }

  void _markPending(Set<String> movieNumbers) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        pendingMovieNumbers: Set<String>.of(current.pendingMovieNumbers)
          ..addAll(movieNumbers),
      ),
    );
  }

  void _unmarkPending(Set<String> movieNumbers) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        pendingMovieNumbers: Set<String>.of(current.pendingMovieNumbers)
          ..removeAll(movieNumbers),
      ),
    );
  }

  void _setBatchAction(MovieSubscriptionBatchAction? action) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(runningBatchAction: action));
  }
}
