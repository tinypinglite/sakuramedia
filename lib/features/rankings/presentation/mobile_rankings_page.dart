import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_list_page_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/rankings/ranked_movie_summary_grid.dart';
import 'package:sakuramedia/widgets/rankings/ranking_filter_toolbar.dart';

class MobileRankingsPage extends StatefulWidget {
  const MobileRankingsPage({super.key});

  @override
  State<MobileRankingsPage> createState() => _MobileRankingsPageState();
}

class _MobileRankingsPageState extends State<MobileRankingsPage> {
  late final RankingsListPageStateEntry _pageState;
  late final bool _ownsPageState;

  @override
  void initState() {
    super.initState();
    final cache = maybeReadAppPageStateCache(context);
    if (cache == null) {
      _ownsPageState = true;
      _pageState = RankingsListPageStateEntry(
        rankingsApi: context.read<RankingsApi>(),
        moviesApi: context.read<MoviesApi>(),
      );
    } else {
      _ownsPageState = false;
      _pageState = cache.obtain<RankingsListPageStateEntry>(
        key: mobileRankingsPageStateKey(),
        create:
            () => RankingsListPageStateEntry(
              rankingsApi: context.read<RankingsApi>(),
              moviesApi: context.read<MoviesApi>(),
            ),
      );
    }
    unawaited(_pageState.initialize());
  }

  @override
  void dispose() {
    if (_ownsPageState) {
      _pageState.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await _pageState.toggleMovieSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AppPullToRefresh(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _pageState.controller.scrollController,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pageState, _pageState.controller]),
            builder: (context, _) {
              final showFooter =
                  _pageState.controller.items.isNotEmpty &&
                  (_pageState.controller.isLoadingMore ||
                      _pageState.controller.loadMoreErrorMessage != null);
              return Column(
                key: const Key('mobile-rankings-page'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppFilterTotalHeader(
                    leading: RankingFilterToolbar(
                      sources: _pageState.sources,
                      selectedSource: _pageState.selectedSource,
                      boards: _pageState.boards,
                      selectedBoard: _pageState.selectedBoard,
                      selectedPeriod: _pageState.selectedPeriod,
                      isLoading: _pageState.isFilterLoading,
                      onSourceChanged:
                          (value) => unawaited(_pageState.selectSource(value)),
                      onBoardChanged:
                          (value) => unawaited(_pageState.selectBoard(value)),
                      onPeriodChanged:
                          (value) => unawaited(_pageState.selectPeriod(value)),
                    ),
                    totalText: '${_pageState.controller.total} 部',
                    totalKey: const Key('mobile-rankings-page-total'),
                  ),
                  SizedBox(height: context.appSpacing.md),
                  if (_pageState.filterErrorMessage != null) ...[
                    _FilterErrorBanner(
                      message: _pageState.filterErrorMessage!,
                      onRetry: _pageState.reloadFiltersAndData,
                    ),
                    SizedBox(height: context.appSpacing.md),
                  ],
                  SizedBox(height: context.appSpacing.sm),
                  if (_pageState.sources.isEmpty &&
                      !_pageState.isFilterLoading &&
                      _pageState.filterErrorMessage == null)
                    const AppEmptyState(message: '暂无可用排行榜')
                  else
                    RankedMovieSummaryGrid(
                      items: _pageState.controller.items,
                      isLoading:
                          _pageState.isFilterLoading
                              ? _pageState.controller.items.isEmpty
                              : _pageState.controller.isInitialLoading,
                      errorMessage: _pageState.controller.initialErrorMessage,
                      onMovieTap:
                          (movie) => context.pushMobileMovieDetail(
                            movieNumber: movie.movieNumber,
                          ),
                      onMovieSubscriptionTap:
                          (movie) =>
                              _toggleMovieSubscription(movie.movieNumber),
                      isMovieSubscriptionUpdating:
                          (movie) => _pageState.controller
                              .isSubscriptionUpdating(movie.movieNumber),
                      emptyMessage: '暂无榜单数据',
                    ),
                  if (showFooter) ...[
                    SizedBox(height: context.appSpacing.md),
                    AppPagedLoadMoreFooter(
                      isLoading: _pageState.controller.isLoadingMore,
                      errorMessage: _pageState.controller.loadMoreErrorMessage,
                      onRetry: _pageState.controller.loadMore,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _pageState.controller.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
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
