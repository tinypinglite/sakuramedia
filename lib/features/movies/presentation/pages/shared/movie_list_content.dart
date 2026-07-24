import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_list_filterable_page_state.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

typedef MovieListBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget sliver,
      Future<void> Function()? onRefresh,
    );

typedef MovieListHeaderBuilder =
    Widget Function(BuildContext context, MovieListHeaderArgs args);

class MovieListHeaderArgs {
  const MovieListHeaderArgs({
    required this.filterState,
    required this.onApply,
    required this.total,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onApply;
  final int total;
}

class MovieListContent extends StatefulWidget {
  const MovieListContent({
    super.key,
    required this.pageState,
    required this.surfaceColor,
    required this.contentKey,
    required this.totalKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.emptyMessage,
    this.enableRefresh = false,
    this.onRefreshFailure,
    this.headerBuilder,
    this.useMobileSelectionLayout = false,
  });

  final MovieListFilterablePageState pageState;
  final Color surfaceColor;
  final Key contentKey;
  final Key totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final MovieListBodyBuilder bodyBuilder;

  /// 为空时的提示文案；不传时按当前筛选状态自动决定：
  /// 未筛选(默认态)提示去搜索,已应用筛选则提示当前筛选下无匹配。
  final String? emptyMessage;
  final bool enableRefresh;
  final void Function(BuildContext context)? onRefreshFailure;

  /// 可选 header builder：传入则替代默认的桌面顶栏（同一个 `AppListHeader`，
  /// 筛选走就地浮层）。移动 tab 主页用它注入自己的顶栏 + 底抽屉范式。
  final MovieListHeaderBuilder? headerBuilder;

  /// 移动端多选布局：进入多选入口挂到**卡片长按浮层**（顶栏不再常驻「选择」），
  /// 多选态顶栏只留退出/计数/全选，批量动作走贴底的 [AppSelectionBottomBar]。
  /// 桌面端保持 `false`——右键弹定位菜单、批量动作在顶栏内联。
  final bool useMobileSelectionLayout;

  @override
  State<MovieListContent> createState() => _MovieListContentState();
}

class _MovieListContentState extends State<MovieListContent>
    with
        MultiSelectStateMixin<MovieListContent, String>,
        MovieBatchSelectionMixin<MovieListContent> {
  late final MovieCollectionTypeChangeNotifier _collectionChangeNotifier;

  @override
  String get batchKeyPrefix => 'movie-list';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      widget.pageState.controller.batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers => widget.pageState.controller.items
      .map((movie) => movie.movieNumber)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _collectionChangeNotifier =
        context.read<MovieCollectionTypeChangeNotifier>();
    _collectionChangeNotifier.addListener(_onCollectionTypeChanged);
  }

  @override
  void dispose() {
    _collectionChangeNotifier.removeListener(_onCollectionTypeChanged);
    super.dispose();
  }

  void _onCollectionTypeChanged() {
    final change = _collectionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    final filterState = widget.pageState.filterState;
    if (change.targetType == MovieCollectionType.collection &&
        filterState.collectionType == MovieCollectionTypeFilter.single) {
      widget.pageState.controller.removeItem(change.movieNumber);
      // 若被移除的项当前正被选中，同步从选中集合中移除。
      if (selectionMode && selectedIds.contains(change.movieNumber)) {
        setState(() => selectedIds.remove(change.movieNumber));
      }
    }
  }

  void _applyFilter(MovieFilterState nextState) {
    final filterState = widget.pageState.filterState;
    if (nextState.matches(filterState)) {
      return;
    }
    setState(() {
      widget.pageState.filterState = nextState;
    });
    // 切筛选跨结果集，选中态失去意义 —— 对齐活动中心样板行为。
    if (selectionMode) {
      exitSelection();
    }
    final controller = widget.pageState.controller;
    if (controller.scrollController.hasClients) {
      controller.scrollController.jumpTo(0);
    }
    unawaited(controller.reload());
  }

  void _resetFilters() {
    _applyFilter(MovieFilterState.initial);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await widget.pageState.controller.toggleSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Future<void> _handleRefresh() async {
    try {
      await widget.pageState.controller.refresh();
    } catch (_) {
      if (mounted) {
        final onRefreshFailure = widget.onRefreshFailure;
        if (onRefreshFailure != null) {
          onRefreshFailure(context);
        } else {
          showToast('刷新失败');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.pageState.controller;
    final body = ColoredBox(
      color: widget.surfaceColor,
      child: widget.bodyBuilder(
        context,
        controller.scrollController,
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final showFooter =
                controller.items.isNotEmpty &&
                (controller.isLoadingMore ||
                    controller.loadMoreErrorMessage != null);
            final headerBuilder = widget.headerBuilder;
            final Widget header;
            if (selectionMode) {
              header =
                  widget.useMobileSelectionLayout
                      ? buildMobileBatchSelectionHeader()
                      : buildBatchSelectionToolbar();
            } else if (headerBuilder != null) {
              header = headerBuilder(
                context,
                MovieListHeaderArgs(
                  filterState: widget.pageState.filterState,
                  onApply: _applyFilter,
                  total: controller.total,
                ),
              );
            } else {
              // 桌面与移动共用同一条顶栏：筛选入口 + 只读信息 + 操作。
              // 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
              header = AppListHeader(
                filterButtonKey: const Key('movies-filter-trigger'),
                filterLabel: widget.pageState.filterState.triggerLabel,
                filterPanelKey: const Key('movies-filter-panel'),
                filterPanelBuilder:
                    (_) => MovieFilterSectionGroup(
                      filterState: widget.pageState.filterState,
                      onChanged: _applyFilter,
                    ),
                filterPanelFooter: AppFilterPanelFooter(
                  isDefault: widget.pageState.filterState.isDefault,
                  onReset: _resetFilters,
                ),
                informationSlots: [
                  AppListHeaderInfo(
                    key: widget.totalKey,
                    label: '${controller.total} 部',
                  ),
                ],
                actionSlots: [buildEnterSelectionButton()],
              );
            }
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    key: widget.contentKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [header, SizedBox(height: widget.sectionSpacing)],
                  ),
                ),
                MovieSummarySliver(
                  items: controller.items,
                  isLoading: controller.isInitialLoading,
                  errorMessage: controller.initialErrorMessage,
                  onMovieTap:
                      (movie) => widget.onMovieTap(context, movie.movieNumber),
                  onMovieMenuRequest: (movie, globalPosition) {
                    unawaited(
                      showMovieCollectionFeatureActionMenu(
                        context: context,
                        movieNumber: movie.movieNumber,
                        globalPosition: globalPosition,
                        isSubscribed: movie.isSubscribed,
                        // 移动端多选入口挂在长按菜单里，桌面仍在顶栏。
                        onEnterSelection:
                            widget.useMobileSelectionLayout
                                ? () {
                                  enterSelection();
                                  toggleSelect(movie.movieNumber);
                                }
                                : null,
                      ),
                    );
                  },
                  onMovieSubscriptionTap:
                      (movie) => _toggleMovieSubscription(movie.movieNumber),
                  isMovieSubscriptionUpdating:
                      (movie) =>
                          controller.isSubscriptionUpdating(movie.movieNumber),
                  emptyMessage:
                      widget.emptyMessage ??
                      (widget.pageState.filterState.isDefault
                          ? '暂无影片，去搜索看看吧'
                          : '当前筛选条件下暂无匹配影片'),
                  selectionMode: selectionMode,
                  isMovieSelected: (movie) => isSelected(movie.movieNumber),
                  onMovieSelectedChanged:
                      (movie, _) => toggleSelect(movie.movieNumber),
                ),
                if (showFooter)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: context.appSpacing.md),
                      child: AppPagedLoadMoreFooter(
                        isLoading: controller.isLoadingMore,
                        errorMessage: controller.loadMoreErrorMessage,
                        onRetry: controller.loadMore,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        widget.enableRefresh ? _handleRefresh : null,
      ),
    );

    if (!widget.useMobileSelectionLayout) {
      return body;
    }
    // 底部批量条贴在列表下方常驻，不随列表滚动。
    return Column(
      children: [
        Expanded(child: body),
        if (selectionMode)
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => buildMobileBatchSelectionBottomBar(),
          ),
      ],
    );
  }
}
