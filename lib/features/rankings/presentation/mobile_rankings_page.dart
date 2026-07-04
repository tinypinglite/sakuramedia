import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/mobile_ranking_filter_drawer.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_list_page_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/navigation/app_mobile_tab_header.dart';
import 'package:sakuramedia/widgets/rankings/ranked_movie_summary_grid.dart';
import 'package:sakuramedia/widgets/rankings/ranking_filter_sections.dart';

class MobileRankingsPage extends StatefulWidget {
  const MobileRankingsPage({super.key});

  @override
  State<MobileRankingsPage> createState() => _MobileRankingsPageState();
}

class _MobileRankingsPageState extends State<MobileRankingsPage> {
  late final CachedPageStateHandle<RankingsListPageStateEntry> _pageStateHandle;

  RankingsListPageStateEntry get _pageState => _pageStateHandle.value;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<RankingsListPageStateEntry>(
      context,
      key: mobileRankingsPageStateKey(),
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
      color: context.appColors.surfaceCard,
      child: AppAdaptiveRefreshScrollView(
        onRefresh: _handleRefresh,
        controller: _pageState.controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
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
                    _buildHeader(context),
                    SizedBox(height: context.appSpacing.md),
                    if (_pageState.filterErrorMessage != null) ...[
                      _FilterErrorBanner(
                        message: _pageState.filterErrorMessage!,
                        onRetry: _pageState.reloadFiltersAndData,
                      ),
                      SizedBox(height: context.appSpacing.md),
                    ],
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
                        onMovieMenuRequest: (movie, globalPosition) =>
                            requestMovieCollectionMenu(context, movie.movieNumber, globalPosition),
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
                        errorMessage:
                            _pageState.controller.loadMoreErrorMessage,
                        onRetry: _pageState.controller.loadMore,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
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

  Widget _buildHeader(BuildContext context) {
    final source = _pageState.selectedSource;
    final board = _pageState.selectedBoard;
    final sourceBoardLabel = '${source?.name ?? '来源'} · ${board?.name ?? '榜单'}';
    final syncedAtLabel = formatSyncedAtLabel(_pageState.controller.syncedAt);

    // 仅保留「来源 · 榜单」单 chip；周期 / 排序 通过右上筛选 icon 弹抽屉调整。
    // 抓取时间放到 filter icon 左侧，与 chip 同一行显示，不新开一行。
    return AppMobileTabHeader(
      filterButtonKey: const Key('mobile-rankings-filter-button'),
      filterTooltip: '筛选',
      onFilterTap: () => _openFilterDrawer(initialAnchor: null),
      chips: [
        AppMobileTabChip(
          key: const Key('mobile-rankings-chip-source-board'),
          label: sourceBoardLabel,
          isSelected: false,
          trailingIcon: Icons.expand_more,
          onTap: () =>
              _openFilterDrawer(initialAnchor: RankingFilterAnchor.source),
        ),
      ],
      trailing: syncedAtLabel == null
          ? null
          : Text(
              key: const Key('mobile-rankings-synced-at'),
              syncedAtLabel,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
    );
  }

  Future<void> _openFilterDrawer({
    RankingFilterAnchor? initialAnchor,
  }) async {
    await showMobileRankingFilterDrawer(
      context,
      listenable: _pageState,
      argsBuilder: () => RankingFilterDrawerArgs(
        sources: _pageState.sources,
        selectedSource: _pageState.selectedSource,
        boards: _pageState.boards,
        selectedBoard: _pageState.selectedBoard,
        selectedPeriod: _pageState.selectedPeriod,
        onSourceChanged: (value) => unawaited(_pageState.selectSource(value)),
        onBoardChanged: (value) => unawaited(_pageState.selectBoard(value)),
        onPeriodChanged: (value) => unawaited(_pageState.selectPeriod(value)),
        selectedSortField: _pageState.selectedSortField,
        selectedSortDirection: _pageState.selectedSortDirection,
        onSortChanged: (field, dir) =>
            unawaited(_pageState.selectSort(field, dir)),
      ),
      initialAnchor: initialAnchor,
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
