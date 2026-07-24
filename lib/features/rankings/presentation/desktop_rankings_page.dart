import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_list_page_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranked_movie_summary_grid.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';

class DesktopRankingsPage extends StatefulWidget {
  const DesktopRankingsPage({super.key});

  @override
  State<DesktopRankingsPage> createState() => _DesktopRankingsPageState();
}

class _DesktopRankingsPageState extends State<DesktopRankingsPage>
    with
        MultiSelectStateMixin<DesktopRankingsPage, String>,
        MovieBatchSelectionMixin<DesktopRankingsPage> {
  late final CachedPageStateHandle<RankingsListPageStateEntry> _pageStateHandle;

  RankingsListPageStateEntry get _pageState => _pageStateHandle.value;

  @override
  String get batchKeyPrefix => 'desktop-rankings';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      _pageState.controller.batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers => _pageState.controller.items
      .map((movie) => movie.movieNumber)
      .toList(growable: false);

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

  /// 与移动榜单页共用同一条顶栏：筛选入口（当前榜单）+ 总数 / 更新时间信息槽。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  Widget _buildHeader(BuildContext context) {
    // 与移动端同一套单值语义：只报「榜单」这一主维度。
    final boardLabel =
        _pageState.selectedBoard?.name ??
        _pageState.selectedSource?.name ??
        '全部榜单';
    final syncedAtLabel = formatSyncedAtLabel(
      _pageState.controller.syncedAt,
      withPrefix: false,
    );

    return AppListHeader(
      filterButtonKey: const Key('desktop-rankings-filter-trigger'),
      filterIcon: Icons.leaderboard_outlined,
      filterLabel: boardLabel,
      filterEnabled: !_pageState.isFilterLoading,
      filterPanelKey: const Key('rankings-filter-panel'),
      filterPanelExtraWidth: 520,
      filterPanelBuilder:
          (_) => RankingFilterSectionGroup(
            sources: _pageState.sources,
            selectedSource: _pageState.selectedSource,
            boards: _pageState.boards,
            selectedBoard: _pageState.selectedBoard,
            selectedPeriod: _pageState.selectedPeriod,
            onSourceChanged:
                (value) => unawaited(_pageState.selectSource(value)),
            onBoardChanged: (value) => unawaited(_pageState.selectBoard(value)),
            onPeriodChanged:
                (value) => unawaited(_pageState.selectPeriod(value)),
            selectedSortField: _pageState.selectedSortField,
            selectedSortDirection: _pageState.selectedSortDirection,
            onSortChanged:
                (field, dir) => unawaited(_pageState.selectSort(field, dir)),
          ),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('desktop-rankings-page-total'),
          label: '${_pageState.controller.total} 部',
        ),
        if (syncedAtLabel != null)
          AppListHeaderInfo(
            key: const Key('desktop-rankings-synced-at'),
            label: syncedAtLabel,
            icon: Icons.schedule_rounded,
          ),
      ],
      actionSlots: [buildEnterSelectionButton()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageRefreshScope(
      onRefresh: _pageState.controller.refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: CustomScrollView(
          controller: _pageState.controller.scrollController,
          slivers: [
            AnimatedBuilder(
              animation: Listenable.merge([_pageState, _pageState.controller]),
              builder: (context, _) {
                final showFooter =
                    _pageState.controller.items.isNotEmpty &&
                    (_pageState.controller.isLoadingMore ||
                        _pageState.controller.loadMoreErrorMessage != null);
                final hasNoSources =
                    _pageState.sources.isEmpty &&
                    !_pageState.isFilterLoading &&
                    _pageState.filterErrorMessage == null;
                return SliverMainAxisGroup(
                  key: const Key('desktop-rankings-page'),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectionMode)
                            buildBatchSelectionToolbar()
                          else
                            _buildHeader(context),
                          SizedBox(height: context.appSpacing.md),
                          if (_pageState.filterErrorMessage != null) ...[
                            _FilterErrorBanner(
                              message: _pageState.filterErrorMessage!,
                              onRetry: _pageState.reloadFiltersAndData,
                            ),
                            SizedBox(height: context.appSpacing.md),
                          ],
                          SizedBox(height: context.appSpacing.sm),
                        ],
                      ),
                    ),
                    if (hasNoSources)
                      const SliverToBoxAdapter(
                        child: AppEmptyState(message: '暂无可用排行榜'),
                      )
                    else
                      RankedMovieSummarySliver(
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
                        onMovieMenuRequest:
                            (movie, globalPosition) =>
                                requestMovieCollectionMenu(
                                  context,
                                  movie.movieNumber,
                                  globalPosition,
                                  isSubscribed: movie.isSubscribed,
                                ),
                        onMovieSubscriptionTap:
                            (movie) =>
                                _toggleMovieSubscription(movie.movieNumber),
                        isMovieSubscriptionUpdating:
                            (movie) => _pageState.controller
                                .isSubscriptionUpdating(movie.movieNumber),
                        emptyMessage: '暂无榜单数据',
                        selectionMode: selectionMode,
                        isMovieSelected:
                            (movie) => isSelected(movie.movieNumber),
                        onMovieSelectedChanged:
                            (movie, _) => toggleSelect(movie.movieNumber),
                      ),
                    if (showFooter)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: context.appSpacing.md),
                          child: AppPagedLoadMoreFooter(
                            isLoading: _pageState.controller.isLoadingMore,
                            errorMessage:
                                _pageState.controller.loadMoreErrorMessage,
                            onRetry: _pageState.controller.loadMore,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
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
