import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/paged_ranked_movie_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/rankings/ranked_movie_summary_grid.dart';
import 'package:sakuramedia/widgets/rankings/ranking_filter_toolbar.dart';

class DesktopRankingsPage extends StatefulWidget {
  const DesktopRankingsPage({super.key});

  @override
  State<DesktopRankingsPage> createState() => _DesktopRankingsPageState();
}

class _DesktopRankingsPageState extends State<DesktopRankingsPage> {
  late final RankingsApi _rankingsApi;
  late final MoviesApi _moviesApi;
  late final PagedRankedMovieController _controller;

  bool _isFilterLoading = true;
  String? _filterErrorMessage;

  List<RankingSourceDto> _sources = const <RankingSourceDto>[];
  List<RankingBoardDto> _boards = const <RankingBoardDto>[];
  RankingSourceDto? _selectedSource;
  RankingBoardDto? _selectedBoard;
  String? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _rankingsApi = context.read<RankingsApi>();
    _moviesApi = context.read<MoviesApi>();
    _controller = PagedRankedMovieController(
      fetchPage: _fetchRankingPage,
      subscribeMovie: _moviesApi.subscribeMovie,
      unsubscribeMovie: _moviesApi.unsubscribeMovie,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
    );
    _controller.attachScrollListener();
    unawaited(_initializeFiltersAndData());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<PaginatedResponseDto<RankedMovieListItemDto>> _fetchRankingPage(
    int page,
    int pageSize,
  ) {
    final selectedSource = _selectedSource;
    final selectedBoard = _selectedBoard;
    final selectedPeriod = _selectedPeriod;

    if (selectedSource == null ||
        selectedBoard == null ||
        selectedPeriod == null) {
      return Future.value(
        PaginatedResponseDto<RankedMovieListItemDto>(
          items: const <RankedMovieListItemDto>[],
          page: page,
          pageSize: pageSize,
          total: 0,
        ),
      );
    }

    return _rankingsApi.getRankingItems(
      sourceKey: selectedSource.sourceKey,
      boardKey: selectedBoard.boardKey,
      period: selectedPeriod,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<void> _initializeFiltersAndData() async {
    setState(() {
      _isFilterLoading = true;
      _filterErrorMessage = null;
    });

    try {
      final sources = await _rankingsApi.getRankingSources();
      if (!mounted) {
        return;
      }
      if (sources.isEmpty) {
        setState(() {
          _sources = const <RankingSourceDto>[];
          _boards = const <RankingBoardDto>[];
          _selectedSource = null;
          _selectedBoard = null;
          _selectedPeriod = null;
          _isFilterLoading = false;
        });
        await _controller.reload();
        return;
      }

      final selectedSource = sources.first;
      final boards = await _rankingsApi.getRankingBoards(
        sourceKey: selectedSource.sourceKey,
      );
      if (!mounted) {
        return;
      }

      final selectedBoard = boards.isNotEmpty ? boards.first : null;
      final selectedPeriod =
          selectedBoard == null ? null : _resolveDefaultPeriod(selectedBoard);

      setState(() {
        _sources = sources;
        _boards = boards;
        _selectedSource = selectedSource;
        _selectedBoard = selectedBoard;
        _selectedPeriod = selectedPeriod;
        _isFilterLoading = false;
      });

      await _controller.reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFilterLoading = false;
        _filterErrorMessage = apiErrorMessage(
          error,
          fallback: '排行榜筛选加载失败，请稍后重试',
        );
      });
    }
  }

  Future<void> _selectSource(RankingSourceDto source) async {
    if (source == _selectedSource || _isFilterLoading) {
      return;
    }
    setState(() {
      _isFilterLoading = true;
      _filterErrorMessage = null;
    });
    try {
      final boards = await _rankingsApi.getRankingBoards(
        sourceKey: source.sourceKey,
      );
      if (!mounted) {
        return;
      }
      final nextSelectedBoard = boards.isNotEmpty ? boards.first : null;
      final nextSelectedPeriod =
          nextSelectedBoard == null
              ? null
              : _resolveDefaultPeriod(nextSelectedBoard);

      setState(() {
        _selectedSource = source;
        _boards = boards;
        _selectedBoard = nextSelectedBoard;
        _selectedPeriod = nextSelectedPeriod;
        _isFilterLoading = false;
      });
      _resetListScroll();
      await _controller.reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFilterLoading = false;
        _filterErrorMessage = apiErrorMessage(
          error,
          fallback: '排行榜筛选加载失败，请稍后重试',
        );
      });
    }
  }

  Future<void> _selectBoard(RankingBoardDto board) async {
    if (board == _selectedBoard || _isFilterLoading) {
      return;
    }
    final period = _resolveDefaultPeriod(board);
    setState(() {
      _selectedBoard = board;
      _selectedPeriod = period;
      _filterErrorMessage = null;
    });
    _resetListScroll();
    await _controller.reload();
  }

  Future<void> _selectPeriod(String period) async {
    if (period == _selectedPeriod || _isFilterLoading) {
      return;
    }
    setState(() {
      _selectedPeriod = period;
      _filterErrorMessage = null;
    });
    _resetListScroll();
    await _controller.reload();
  }

  void _resetListScroll() {
    if (_controller.scrollController.hasClients) {
      _controller.scrollController.jumpTo(0);
    }
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

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await _controller.toggleSubscription(movieNumber: movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _controller.scrollController,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final showFooter =
                _controller.items.isNotEmpty &&
                (_controller.isLoadingMore ||
                    _controller.loadMoreErrorMessage != null);
            return Column(
              key: const Key('desktop-rankings-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFilterTotalHeader(
                  leading: RankingFilterToolbar(
                    sources: _sources,
                    selectedSource: _selectedSource,
                    boards: _boards,
                    selectedBoard: _selectedBoard,
                    selectedPeriod: _selectedPeriod,
                    isLoading: _isFilterLoading,
                    onSourceChanged: (value) => unawaited(_selectSource(value)),
                    onBoardChanged: (value) => unawaited(_selectBoard(value)),
                    onPeriodChanged:
                        (value) => unawaited(_selectPeriod(value)),
                  ),
                  totalText: '${_controller.total} 部',
                  totalKey: const Key('desktop-rankings-page-total'),
                ),
                SizedBox(height: context.appSpacing.md),
                if (_filterErrorMessage != null) ...[
                  _FilterErrorBanner(
                    message: _filterErrorMessage!,
                    onRetry: _initializeFiltersAndData,
                  ),
                  SizedBox(height: context.appSpacing.md),
                ],
                SizedBox(height: context.appSpacing.sm),
                if (_sources.isEmpty &&
                    !_isFilterLoading &&
                    _filterErrorMessage == null)
                  const AppEmptyState(message: '暂无可用排行榜')
                else
                  RankedMovieSummaryGrid(
                    items: _controller.items,
                    isLoading:
                        _isFilterLoading
                            ? _controller.items.isEmpty
                            : _controller.isInitialLoading,
                    errorMessage: _controller.initialErrorMessage,
                    onMovieTap:
                        (movie) => context.pushDesktopMovieDetail(
                          movieNumber: movie.movieNumber,
                          fallbackPath: desktopRankingsPath,
                        ),
                    onMovieSubscriptionTap:
                        (movie) => _toggleMovieSubscription(movie.movieNumber),
                    isMovieSubscriptionUpdating:
                        (movie) =>
                            _controller.isSubscriptionUpdating(movie.movieNumber),
                    emptyMessage: '暂无榜单数据',
                  ),
                if (showFooter) ...[
                  SizedBox(height: context.appSpacing.md),
                  AppPagedLoadMoreFooter(
                    isLoading: _controller.isLoadingMore,
                    errorMessage: _controller.loadMoreErrorMessage,
                    onRetry: _controller.loadMore,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterErrorBanner extends StatelessWidget {
  const _FilterErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.appSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: context.appComponentTokens.iconSizeXl,
              color: context.appColors.textSecondary,
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            AppButton(
              label: '重试',
              size: AppButtonSize.xSmall,
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(onRetry()),
            ),
          ],
        ),
      ),
    );
  }
}
