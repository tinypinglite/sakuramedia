import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/rankings_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'ranking_summary_provider.g.dart';

/// 桌面和移动榜单共用的缓存状态。
///
/// 排行榜的筛选元数据与分页数据具有依赖关系，所以把来源、榜单、周期、排序和
/// 订阅 busy 状态放在同一个不可变 state 中；请求顺序与旧 entry 保持一致。
@Riverpod(retry: kNoAsyncNotifierRetry)
class RankingSummary extends _$RankingSummary
    with
        PagedAsyncNotifierMixin<RankingSummaryState, RankedMovieListItemDto>,
        OptimisticPatchMixin<RankingSummaryState> {
  KeepAliveLink? _cacheLink;
  RankingFilterState _activeFilters = RankingFilterState.initial;
  int _filterGeneration = 0;
  late final DebouncedLatestRequest _filterRequests = DebouncedLatestRequest();

  KeepAliveLink? get cacheLink => _cacheLink;

  @override
  bool get isOptimisticPatchDisposed => isDisposed;

  @override
  int get pageSize => 24;

  @override
  String get initialLoadErrorText => '排行榜加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多失败，请点击重试';

  @override
  PagedListState<RankedMovieListItemDto> pagedOf(RankingSummaryState state) =>
      state.paged;

  @override
  RankingSummaryState applyPaged(
    RankingSummaryState state,
    PagedListState<RankedMovieListItemDto> paged,
  ) => state.copyWith(paged: paged);

  @override
  Future<RankingSummaryState> build(RankingSummaryScope scope) async {
    _cacheLink ??= ref.keepAlive();
    attachDisposeGuard();
    ref.onDispose(_filterRequests.dispose);
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final changes = next.value;
      if (changes != null) {
        _applySubscriptionChanges(changes);
      }
    });

    final filters = await _loadInitialFilters();
    _activeFilters = filters;
    if (filters.errorMessage != null || filters.sources.isEmpty) {
      return RankingSummaryState(
        paged: const PagedListState<RankedMovieListItemDto>(),
        filters: filters,
      );
    }
    return _loadFirstPageForBuild(filters);
  }

  @override
  Future<PaginatedResponseDto<RankedMovieListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    final source = _activeFilters.selectedSource;
    final board = _activeFilters.selectedBoard;
    final period = _activeFilters.selectedPeriod;
    if (source == null || board == null || period == null) {
      return Future.value(
        PaginatedResponseDto<RankedMovieListItemDto>(
          items: const <RankedMovieListItemDto>[],
          page: page,
          pageSize: pageSize,
          total: 0,
        ),
      );
    }
    return ref
        .read(rankingsApiProvider)
        .getRankingItems(
          sourceKey: source.sourceKey,
          boardKey: board.boardKey,
          period: period,
          page: page,
          pageSize: pageSize,
          sort: _activeFilters.sortExpression,
        );
  }

  Future<void> reloadFiltersAndData() async {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      try {
        await future;
      } catch (_) {}
      return;
    }
    final generation = ++_filterGeneration;
    _filterRequests.cancel();
    state = AsyncData(
      current.copyWith(
        filters: current.filters.copyWith(isLoading: true, errorMessage: null),
      ),
    );
    final filters = await _loadInitialFilters(base: current.filters);
    if (isDisposed || generation != _filterGeneration) {
      return;
    }
    _activeFilters = filters;
    if (filters.errorMessage != null || filters.sources.isEmpty) {
      state = AsyncData(
        (state.value ?? current).copyWith(
          filters: filters,
          isListLoading: false,
          initialErrorMessage: null,
          paged: current.paged.copyWith(
            filterUpdate: FilterUpdateState.failed(
              filters.errorMessage ?? '排行榜筛选加载失败，请稍后重试',
            ),
          ),
        ),
      );
      return;
    }
    _activeFilters = filters;
    final now = state.value ?? current;
    state = AsyncData(
      now.copyWith(
        filters: filters,
        paged: now.paged.copyWith(
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    await _filterRequests.runNow(_reloadItems);
  }

  Future<void> selectSource(RankingSourceDto source) {
    final current = state.value;
    if (current == null ||
        source.sourceKey == current.filters.selectedSource?.sourceKey) {
      return Future<void>.value();
    }
    _filterGeneration++;
    invalidateInFlightLoadMore();
    final filters = current.filters.copyWith(
      isLoading: true,
      errorMessage: null,
      selectedSource: source,
      boards: const <RankingBoardDto>[],
      selectedBoard: null,
      selectedPeriod: null,
    );
    _activeFilters = filters;
    state = AsyncData(
      current.copyWith(
        filters: filters,
        paged: current.paged.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    return _filterRequests.schedule(
      (requestId) => _loadSource(requestId, source),
    );
  }

  Future<void> _loadSource(int requestId, RankingSourceDto source) async {
    try {
      final boards = await ref
          .read(rankingsApiProvider)
          .getRankingBoards(sourceKey: source.sourceKey);
      if (isDisposed || !_filterRequests.isCurrent(requestId)) {
        return;
      }
      final board = boards.isEmpty ? null : boards.first;
      final current = state.value;
      if (current == null) return;
      final filters = current.filters.copyWith(
        isLoading: false,
        errorMessage: null,
        selectedSource: source,
        boards: boards,
        selectedBoard: board,
        selectedPeriod: board == null ? null : _defaultPeriod(board),
      );
      _activeFilters = filters;
      state = AsyncData(current.copyWith(filters: filters));
      await _reloadItems(requestId);
    } catch (error) {
      if (isDisposed || !_filterRequests.isCurrent(requestId)) {
        return;
      }
      final current = state.value;
      if (current == null) return;
      final message = apiErrorMessage(error, fallback: '排行榜筛选加载失败，请稍后重试');
      state = AsyncData(
        current.copyWith(
          filters: current.filters.copyWith(
            isLoading: false,
            errorMessage: message,
          ),
          paged: current.paged.copyWith(
            filterUpdate: FilterUpdateState.failed(message),
          ),
        ),
      );
    }
  }

  Future<void> selectBoard(RankingBoardDto board) {
    final current = state.value;
    if (current == null ||
        current.filters.isLoading ||
        board.boardKey == current.filters.selectedBoard?.boardKey) {
      return Future<void>.value();
    }
    final filters = current.filters.copyWith(
      errorMessage: null,
      selectedBoard: board,
      selectedPeriod: _defaultPeriod(board),
    );
    return _applyFiltersAndReload(current, filters);
  }

  Future<void> selectPeriod(String period) {
    final current = state.value;
    if (current == null ||
        current.filters.isLoading ||
        period == current.filters.selectedPeriod) {
      return Future<void>.value();
    }
    return _applyFiltersAndReload(
      current,
      current.filters.copyWith(errorMessage: null, selectedPeriod: period),
    );
  }

  Future<void> selectSort(RankingSortField? field, SortDirection direction) {
    final current = state.value;
    if (current == null ||
        (field == current.filters.selectedSortField &&
            direction == current.filters.selectedSortDirection)) {
      return Future<void>.value();
    }
    return _applyFiltersAndReload(
      current,
      current.filters.copyWith(
        errorMessage: null,
        selectedSortField: field,
        selectedSortDirection: direction,
      ),
    );
  }

  @override
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null || current.filters.isLoading) {
      return null;
    }
    if (current.paged.isLoadingMore) {
      return null;
    }
    invalidateInFlightLoadMore();
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    await _filterRequests.runNow(_reloadItems);
    return state.value?.paged.filterUpdate.errorMessage;
  }

  Future<MovieSubscriptionToggleResult> toggleSubscription(
    String movieNumber,
  ) async {
    final current = state.value;
    final movie = current?.paged.items
        .where((item) => item.movieNumber == movieNumber)
        .firstOrNull;
    if (movie == null || isInFlight(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }
    _setSubscriptionUpdating(movieNumber, true);
    final subscribe = !movie.isSubscribed;
    try {
      final api = ref.read(moviesApiProvider);
      if (subscribe) {
        await api.subscribeMovie(movieNumber: movieNumber);
      } else {
        await api.unsubscribeMovie(
          movieNumber: movieNumber,
          deleteMedia: false,
        );
      }
      if (isDisposed) {
        return const MovieSubscriptionToggleResult.ignored();
      }
      _patchSubscription(movieNumber, subscribe);
      _reportSubscriptionChanges(<MovieSubscriptionChange>[
        MovieSubscriptionChange(
          movieNumber: movieNumber,
          isSubscribed: subscribe,
        ),
      ]);
      return subscribe
          ? const MovieSubscriptionToggleResult.subscribed()
          : const MovieSubscriptionToggleResult.unsubscribed();
    } catch (error) {
      if (isMovieSubscriptionBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: subscribe ? '订阅影片失败' : '取消订阅影片失败',
        ),
      );
    } finally {
      if (!isDisposed) {
        _setSubscriptionUpdating(movieNumber, false);
      }
    }
  }

  Future<MovieSubscriptionBatchToggleResult> batchToggleSubscription({
    required Iterable<String> movieNumbers,
    required bool subscribe,
  }) async {
    final ordered = <String>[];
    final seen = <String>{};
    for (final movieNumber in movieNumbers) {
      if (movieNumber.isNotEmpty && seen.add(movieNumber)) {
        ordered.add(movieNumber);
      }
    }
    if (ordered.isEmpty) {
      return const MovieSubscriptionBatchToggleResult(
        requestedCount: 0,
        updatedCount: 0,
        skippedMovieNotFoundNumbers: <String>[],
        skippedHasMediaNumbers: <String>[],
      );
    }

    final patched = <String>{};
    MovieSubscriptionBatchResultDto? response;
    final result =
        await withBatchOptimisticPatch<String, MovieSubscriptionBatchResultDto>(
          keys: ordered,
          apply: (current, applying) {
            final items = current.paged.items
                .map((item) {
                  if (!applying.contains(item.movieNumber) ||
                      item.isSubscribed == subscribe) {
                    return item;
                  }
                  patched.add(item.movieNumber);
                  return item.copyWith(isSubscribed: subscribe);
                })
                .toList(growable: false);
            return current.copyWith(
              paged: current.paged.copyWith(items: List.unmodifiable(items)),
            );
          },
          action: (numbers) async {
            final api = ref.read(moviesApiProvider);
            response = subscribe
                ? await api.batchSubscribeMovies(movieNumbers: numbers.toList())
                : await api.batchUnsubscribeMovies(
                    movieNumbers: numbers.toList(),
                  );
            return response!;
          },
          skippedFromResult: (value) => <String>{
            ...value.movieNumbersSkippedBecause(
              MovieSubscriptionSkipReason.movieNotFound,
            ),
            ...value.movieNumbersSkippedBecause(
              MovieSubscriptionSkipReason.hasMedia,
            ),
          },
          rollback: _restoreSubscriptionStatuses,
          errorMessageOf: (error) => apiErrorMessage(
            error,
            fallback: subscribe ? '批量订阅影片失败' : '批量取消订阅影片失败',
          ),
        );
    if (result.errorMessage != null || response == null) {
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: ordered.length,
        message: result.errorMessage ?? (subscribe ? '批量订阅影片失败' : '批量取消订阅影片失败'),
      );
    }

    final resolved = response!;
    final skippedNotFound = resolved.movieNumbersSkippedBecause(
      MovieSubscriptionSkipReason.movieNotFound,
    );
    final skippedHasMedia = resolved.movieNumbersSkippedBecause(
      MovieSubscriptionSkipReason.hasMedia,
    );
    if (!isDisposed) {
      final acceptedPatched = result.accepted.intersection(patched);
      _reportSubscriptionChanges(<MovieSubscriptionChange>[
        for (final movieNumber in ordered)
          if (acceptedPatched.contains(movieNumber))
            MovieSubscriptionChange(
              movieNumber: movieNumber,
              isSubscribed: subscribe,
            ),
      ]);
    }
    return MovieSubscriptionBatchToggleResult(
      requestedCount: resolved.requestedCount,
      updatedCount: resolved.updatedCount,
      skippedMovieNotFoundNumbers: skippedNotFound,
      skippedHasMediaNumbers: skippedHasMedia,
    );
  }

  Future<RankingFilterState> _loadInitialFilters({
    RankingFilterState? base,
  }) async {
    final previous = base ?? RankingFilterState.initial;
    try {
      final sources = await ref.read(rankingsApiProvider).getRankingSources();
      if (sources.isEmpty) {
        return previous.copyWith(
          isLoading: false,
          errorMessage: null,
          sources: const <RankingSourceDto>[],
          boards: const <RankingBoardDto>[],
          selectedSource: null,
          selectedBoard: null,
          selectedPeriod: null,
        );
      }
      final source = sources.first;
      final boards = await ref
          .read(rankingsApiProvider)
          .getRankingBoards(sourceKey: source.sourceKey);
      final board = boards.isEmpty ? null : boards.first;
      return previous.copyWith(
        isLoading: false,
        errorMessage: null,
        sources: sources,
        boards: boards,
        selectedSource: source,
        selectedBoard: board,
        selectedPeriod: board == null ? null : _defaultPeriod(board),
      );
    } catch (error) {
      return previous.copyWith(
        isLoading: false,
        errorMessage: apiErrorMessage(error, fallback: '排行榜筛选加载失败，请稍后重试'),
      );
    }
  }

  Future<RankingSummaryState> _loadFirstPageForBuild(
    RankingFilterState filters,
  ) async {
    try {
      final paged = await loadInitialPage();
      return RankingSummaryState(paged: paged, filters: filters);
    } catch (_) {
      return RankingSummaryState(
        paged: const PagedListState<RankedMovieListItemDto>(),
        filters: filters,
        initialErrorMessage: initialLoadErrorText,
      );
    }
  }

  Future<void> _applyFiltersAndReload(
    RankingSummaryState current,
    RankingFilterState filters,
  ) {
    _activeFilters = filters;
    invalidateInFlightLoadMore();
    state = AsyncData(
      current.copyWith(
        filters: filters,
        paged: current.paged.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    return _filterRequests.schedule(_reloadItems);
  }

  Future<void> _reloadItems(int requestId) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    try {
      final paged = await loadInitialPage();
      if (isDisposed || !_filterRequests.isCurrent(requestId)) {
        return;
      }
      final currentAfter = state.value ?? current;
      state = AsyncData(
        currentAfter.copyWith(
          paged: paged,
          isListLoading: false,
          initialErrorMessage: null,
        ),
      );
    } catch (error) {
      if (isDisposed || !_filterRequests.isCurrent(requestId)) {
        return;
      }
      final currentAfter = state.value ?? current;
      state = AsyncData(
        currentAfter.copyWith(
          isListLoading: false,
          initialErrorMessage: null,
          paged: currentAfter.paged.copyWith(
            filterUpdate: FilterUpdateState.failed(
              apiErrorMessage(error, fallback: '筛选结果更新失败，请重试'),
            ),
          ),
        ),
      );
    }
  }

  Future<void> retryFilter() {
    final current = state.value;
    if (current == null) {
      return Future<void>.value();
    }
    final source = current.filters.selectedSource;
    if (source != null &&
        (current.filters.selectedBoard == null ||
            current.filters.errorMessage != null)) {
      final filters = current.filters.copyWith(
        isLoading: true,
        errorMessage: null,
      );
      _activeFilters = filters;
      state = AsyncData(
        current.copyWith(
          filters: filters,
          paged: current.paged.copyWith(
            filterUpdate: const FilterUpdateState.loading(),
          ),
        ),
      );
      return _filterRequests.runNow(
        (requestId) => _loadSource(requestId, source),
      );
    }
    if (current.filters.isLoading) return Future<void>.value();
    invalidateInFlightLoadMore();
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    return _filterRequests.runNow(_reloadItems);
  }

  @override
  Future<void> loadMore() {
    final current = state.value;
    if (current != null && !current.paged.filterUpdate.isIdle) {
      return Future<void>.value();
    }
    return super.loadMore();
  }

  void _applySubscriptionChanges(List<MovieSubscriptionChange> changes) {
    final current = state.value;
    if (current == null || changes.isEmpty) {
      return;
    }
    var paged = current.paged;
    for (final change in changes) {
      paged = paged.patchWhere(
        (item) => item.movieNumber == change.movieNumber,
        (item) => item.copyWith(isSubscribed: change.isSubscribed),
      );
    }
    if (identical(paged, current.paged)) {
      return;
    }
    state = AsyncData(current.copyWith(paged: paged));
  }

  void _patchSubscription(String movieNumber, bool isSubscribed) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final paged = current.paged.patchWhere(
      (item) => item.movieNumber == movieNumber,
      (item) => item.copyWith(isSubscribed: isSubscribed),
    );
    if (identical(paged, current.paged)) {
      return;
    }
    state = AsyncData(current.copyWith(paged: paged));
  }

  void _setSubscriptionUpdating(String movieNumber, bool updating) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = Set<String>.of(current.subscriptionUpdatingMovieNumbers);
    final changed = updating ? next.add(movieNumber) : next.remove(movieNumber);
    if (!changed) {
      return;
    }
    state = AsyncData(current.copyWith(subscriptionUpdatingMovieNumbers: next));
  }

  RankingSummaryState _restoreSubscriptionStatuses(
    RankingSummaryState current,
    RankingSummaryState original,
    Set<String> movieNumbers,
  ) {
    final originals = <String, RankedMovieListItemDto>{
      for (final item in original.paged.items) item.movieNumber: item,
    };
    final restored = current.paged.items
        .map(
          (item) => movieNumbers.contains(item.movieNumber)
              ? (originals[item.movieNumber] ?? item)
              : item,
        )
        .toList(growable: false);
    return current.copyWith(
      paged: current.paged.copyWith(items: List.unmodifiable(restored)),
    );
  }

  void _reportSubscriptionChanges(List<MovieSubscriptionChange> changes) {
    if (changes.isEmpty || isDisposed) {
      return;
    }
    final broadcaster = ref.read(movieSubscriptionEventsProvider.notifier);
    if (changes.length == 1) {
      final change = changes.single;
      broadcaster.reportChange(
        movieNumber: change.movieNumber,
        isSubscribed: change.isSubscribed,
      );
      return;
    }
    broadcaster.reportBatch(changes);
  }

  String _defaultPeriod(RankingBoardDto board) {
    final defaultPeriod = board.defaultPeriod;
    if (defaultPeriod != null &&
        board.supportedPeriods.contains(defaultPeriod)) {
      return defaultPeriod;
    }
    if (board.supportedPeriods.isNotEmpty) {
      return board.supportedPeriods.first;
    }
    return 'daily';
  }
}
