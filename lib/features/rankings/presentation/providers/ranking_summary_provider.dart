import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_mutation_mixin.dart';
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
        OptimisticPatchMixin<RankingSummaryState>,
        MovieSubscriptionMutationMixin<
          RankingSummaryState,
          RankedMovieListItemDto
        > {
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
        applySubscriptionChanges(changes);
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
          filterUpdate: const FilterUpdateState.waiting(),
        ),
      ),
    );
    return _filterRequests.schedule(
      (requestId) => _loadSource(requestId, source),
    );
  }

  Future<void> _loadSource(int requestId, RankingSourceDto source) async {
    if (isDisposed || !_filterRequests.isCurrent(requestId)) return;
    final currentAtStart = state.value;
    if (currentAtStart == null) return;
    state = AsyncData(
      currentAtStart.copyWith(
        paged: currentAtStart.paged.copyWith(
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
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
          filterUpdate: const FilterUpdateState.waiting(),
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
    if (isDisposed || !_filterRequests.isCurrent(requestId)) return;
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
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
