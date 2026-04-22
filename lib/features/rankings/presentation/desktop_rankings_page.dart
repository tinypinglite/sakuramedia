import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_list_page_state.dart';
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
  late final CachedPageStateHandle<RankingsListPageStateEntry> _pageStateHandle;

  RankingsListPageStateEntry get _pageState => _pageStateHandle.value;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<RankingsListPageStateEntry>(
      context,
      key: desktopRankingsPageStateKey(),
      create:
          () => RankingsListPageStateEntry(
            rankingsApi: context.read<RankingsApi>(),
            moviesApi: context.read<MoviesApi>(),
            subscriptionChangeNotifier:
                context.read<MovieSubscriptionChangeNotifier>(),
          ),
    );
    unawaited(_pageState.initialize());
  }

  @override
  void dispose() {
    _pageStateHandle.dispose();
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
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _pageState.controller.scrollController,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pageState, _pageState.controller]),
          builder: (context, _) {
            final showFooter =
                _pageState.controller.items.isNotEmpty &&
                (_pageState.controller.isLoadingMore ||
                    _pageState.controller.loadMoreErrorMessage != null);
            return Column(
              key: const Key('desktop-rankings-page'),
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
                  totalKey: const Key('desktop-rankings-page-total'),
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
                        (movie) => context.pushDesktopMovieDetail(
                          movieNumber: movie.movieNumber,
                          fallbackPath: desktopRankingsPath,
                        ),
                    onMovieSubscriptionTap:
                        (movie) => _toggleMovieSubscription(movie.movieNumber),
                    isMovieSubscriptionUpdating:
                        (movie) => _pageState.controller.isSubscriptionUpdating(
                          movie.movieNumber,
                        ),
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
              color: context.appTextPalette.secondary,
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
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
