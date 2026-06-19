import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/fetch_all_pages.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/paged_ranked_movie_controller.dart';
import 'package:sakuramedia/features/rankings/presentation/ranking_sort_mode.dart';

/// 全量拉取榜单时的单页大小：常见榜单（数十~上百条）一次请求即可拿全，
/// 仅 top250 等超过此值时才并发翻页补齐。
const int _rankingLoadPageSize = 100;

class RankingsListPageStateEntry extends ChangeNotifier
    implements AppPageStateEntry {
  RankingsListPageStateEntry({
    required RankingsApi rankingsApi,
    required MoviesApi moviesApi,
    required MovieSubscriptionChangeNotifier subscriptionChangeNotifier,
  }) : _rankingsApi = rankingsApi,
       _moviesApi = moviesApi,
       _subscriptionChangeNotifier = subscriptionChangeNotifier {
    controller = PagedRankedMovieController(
      fetchPage: _fetchRankingPage,
      subscribeMovie: _moviesApi.subscribeMovie,
      unsubscribeMovie: _moviesApi.unsubscribeMovie,
      onSubscriptionChanged: _reportSubscriptionChange,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
    );
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);
    controller.attachScrollListener();
  }

  final RankingsApi _rankingsApi;
  final MoviesApi _moviesApi;
  final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;
  late final PagedRankedMovieController controller;

  bool _isDisposed = false;
  bool _hasInitialized = false;

  bool isFilterLoading = true;
  String? filterErrorMessage;
  List<RankingSourceDto> sources = const <RankingSourceDto>[];
  List<RankingBoardDto> boards = const <RankingBoardDto>[];
  RankingSourceDto? selectedSource;
  RankingBoardDto? selectedBoard;
  String? selectedPeriod;
  RankingSortMode sortMode = RankingSortMode.byRank;

  /// 按当前 [sortMode] 排序后的榜单条目（全量数据本地排序，不触发请求）。
  ///
  /// 热度相同时回退到名次升序，保证排序稳定。
  List<RankedMovieListItemDto> get sortedItems {
    final items = controller.items;
    switch (sortMode) {
      case RankingSortMode.byRank:
        return items;
      case RankingSortMode.heatDesc:
        return [...items]..sort((a, b) {
          final byHeat = b.heat.compareTo(a.heat);
          return byHeat != 0 ? byHeat : a.rank.compareTo(b.rank);
        });
      case RankingSortMode.heatAsc:
        return [...items]..sort((a, b) {
          final byHeat = a.heat.compareTo(b.heat);
          return byHeat != 0 ? byHeat : a.rank.compareTo(b.rank);
        });
    }
  }

  void setSortMode(RankingSortMode mode) {
    if (mode == sortMode) {
      return;
    }
    sortMode = mode;
    _resetListScroll();
    _safeNotifyListeners();
  }

  void _onMovieSubscriptionChanged() {
    final change = _subscriptionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    controller.applySubscriptionChange(
      movieNumber: change.movieNumber,
      isSubscribed: change.isSubscribed,
    );
  }

  void _reportSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    _subscriptionChangeNotifier.reportChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
  }

  Future<void> initialize() async {
    if (_hasInitialized) {
      return;
    }
    _hasInitialized = true;
    await reloadFiltersAndData();
  }

  Future<void> reloadFiltersAndData() async {
    isFilterLoading = true;
    filterErrorMessage = null;
    _safeNotifyListeners();

    try {
      final nextSources = await _rankingsApi.getRankingSources();
      if (_isDisposed) {
        return;
      }

      if (nextSources.isEmpty) {
        sources = const <RankingSourceDto>[];
        boards = const <RankingBoardDto>[];
        selectedSource = null;
        selectedBoard = null;
        selectedPeriod = null;
        isFilterLoading = false;
        _safeNotifyListeners();
        await controller.reload();
        return;
      }

      final nextSelectedSource = nextSources.first;
      final nextBoards = await _rankingsApi.getRankingBoards(
        sourceKey: nextSelectedSource.sourceKey,
      );
      if (_isDisposed) {
        return;
      }

      final nextSelectedBoard = nextBoards.isNotEmpty ? nextBoards.first : null;
      final nextSelectedPeriod =
          nextSelectedBoard == null
              ? null
              : _resolveDefaultPeriod(nextSelectedBoard);

      sources = nextSources;
      boards = nextBoards;
      selectedSource = nextSelectedSource;
      selectedBoard = nextSelectedBoard;
      selectedPeriod = nextSelectedPeriod;
      isFilterLoading = false;
      _safeNotifyListeners();
      await controller.reload();
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      isFilterLoading = false;
      filterErrorMessage = apiErrorMessage(error, fallback: '排行榜筛选加载失败，请稍后重试');
      _safeNotifyListeners();
    }
  }

  Future<void> selectSource(RankingSourceDto source) async {
    if (source == selectedSource || isFilterLoading) {
      return;
    }
    isFilterLoading = true;
    filterErrorMessage = null;
    _safeNotifyListeners();

    try {
      final nextBoards = await _rankingsApi.getRankingBoards(
        sourceKey: source.sourceKey,
      );
      if (_isDisposed) {
        return;
      }
      final nextSelectedBoard = nextBoards.isNotEmpty ? nextBoards.first : null;
      final nextSelectedPeriod =
          nextSelectedBoard == null
              ? null
              : _resolveDefaultPeriod(nextSelectedBoard);

      selectedSource = source;
      boards = nextBoards;
      selectedBoard = nextSelectedBoard;
      selectedPeriod = nextSelectedPeriod;
      isFilterLoading = false;
      _safeNotifyListeners();
      _resetListScroll();
      await controller.reload();
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      isFilterLoading = false;
      filterErrorMessage = apiErrorMessage(error, fallback: '排行榜筛选加载失败，请稍后重试');
      _safeNotifyListeners();
    }
  }

  Future<void> selectBoard(RankingBoardDto board) async {
    if (board == selectedBoard || isFilterLoading) {
      return;
    }
    selectedBoard = board;
    selectedPeriod = _resolveDefaultPeriod(board);
    filterErrorMessage = null;
    _safeNotifyListeners();
    _resetListScroll();
    await controller.reload();
  }

  Future<void> selectPeriod(String period) async {
    if (period == selectedPeriod || isFilterLoading) {
      return;
    }
    selectedPeriod = period;
    filterErrorMessage = null;
    _safeNotifyListeners();
    _resetListScroll();
    await controller.reload();
  }

  Future<MovieSubscriptionToggleResult> toggleMovieSubscription({
    required String movieNumber,
  }) {
    return controller.toggleSubscription(movieNumber: movieNumber);
  }

  /// 一次性拉取整张榜单（不向用户暴露翻页）：先取第 1 页，单页即覆盖全部时
  /// 直接返回（保留 `syncedAt`）；超过单页（如 top250）才并发翻页补齐。
  /// 全量返回后由 [sortedItems] 在本地排序。
  Future<PaginatedResponseDto<RankedMovieListItemDto>> _fetchRankingPage(
    int page,
    int pageSize,
  ) async {
    final source = selectedSource;
    final board = selectedBoard;
    final period = selectedPeriod;

    if (source == null || board == null || period == null) {
      return PaginatedResponseDto<RankedMovieListItemDto>(
        items: const <RankedMovieListItemDto>[],
        page: page,
        pageSize: pageSize,
        total: 0,
      );
    }

    final firstPage = await _rankingsApi.getRankingItems(
      sourceKey: source.sourceKey,
      boardKey: board.boardKey,
      period: period,
      page: 1,
      pageSize: _rankingLoadPageSize,
    );
    if (firstPage.items.length >= firstPage.total) {
      return firstPage;
    }

    final allItems =
        await fetchAllPagesConcurrently<
          RankedMovieListItemDto,
          RankedMovieListItemDto
        >(
          fetchPage:
              (p) => _rankingsApi.getRankingItems(
                sourceKey: source.sourceKey,
                boardKey: board.boardKey,
                period: period,
                page: p,
                pageSize: _rankingLoadPageSize,
              ),
          extractItems: (resp) => resp.items,
          pageSize: _rankingLoadPageSize,
          keyOf: (item) => item.movieNumber,
        );
    return PaginatedResponseDto<RankedMovieListItemDto>(
      items: allItems,
      page: 1,
      pageSize: allItems.length,
      total: allItems.length,
      syncedAt: firstPage.syncedAt,
    );
  }

  String _resolveDefaultPeriod(RankingBoardDto board) {
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

  void _resetListScroll() {
    if (controller.scrollController.hasClients) {
      controller.scrollController.jumpTo(0);
    }
  }

  void _safeNotifyListeners() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    controller.dispose();
    super.dispose();
  }
}
