import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_sort_menu_button.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/domain/tags/tag_filter_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/media_tag_filter_section.dart';

typedef MovieSummaryListBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget sliver,
      Future<void> Function()? onRefresh,
    );

typedef MovieSummaryListHeaderBuilder =
    Widget Function(BuildContext context, MovieSummaryListHeaderArgs args);

/// 顶栏筛选摘要：目录标签计数 + 媒体文件标签计数。
///
/// 两项都没选时退回筛选维度摘要（状态/分辨率等）。桌面筛选面板与移动顶栏
/// 共用这一份拼接，避免两端文案格式漂移。
String movieFilterSummaryLabel({
  required AppLocalizations l10n,
  required MovieFilterState filter,
  required TagSelectionState? tagSelection,
}) {
  final hasTagSelection = tagSelection?.hasSelection ?? false;
  if (!hasTagSelection) return filter.triggerLabel(l10n);
  final tagLabel = l10n.moviePageTagFilterCount(tagSelection!.selectedCount);
  final mediaTagCount = filter.mediaTagIds.length;
  return mediaTagCount == 0
      ? tagLabel
      : '$tagLabel · ${l10n.moviePageMediaTagCount(mediaTagCount)}';
}

class MovieSummaryListHeaderArgs {
  const MovieSummaryListHeaderArgs({
    required this.filterState,
    required this.onApply,
    required this.total,
    this.tagSelection,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onApply;
  final int total;

  /// 当前标签筛选选择；未启用标签筛选的页面为 null。
  final TagSelectionState? tagSelection;
}

/// Riverpod 版影片列表共用渲染壳。
///
/// 影片库缓存页先使用这条 `movies` scope；标签页完成自身选择状态迁移后也会
/// 收敛到同一组件。滚动控制器仍归 View 所有，数据、筛选、订阅和广播补丁全部由
/// [movieSummaryProvider] 承担。
class MovieSummaryListContent extends ConsumerStatefulWidget {
  const MovieSummaryListContent({
    super.key,
    required this.scope,
    required this.surfaceColor,
    required this.contentKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.totalKey,
    this.emptyMessage,
    this.enableRefresh = false,
    this.registerPageRefresh = false,
    this.onRefreshFailure,
    this.headerBuilder,
    this.headerLeading,
    this.showHeader = true,
    this.useMobileSelectionLayout = false,
    this.tagSelectionScope,
    this.enableMediaTagFilter = false,
    this.trailingLabelForMovie,
  });

  final MovieSummaryScope scope;
  final Color surfaceColor;
  final Key contentKey;
  final Key? totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final MovieSummaryListBodyBuilder bodyBuilder;
  final String? emptyMessage;
  final bool enableRefresh;
  final bool registerPageRefresh;
  final void Function(BuildContext context)? onRefreshFailure;
  final MovieSummaryListHeaderBuilder? headerBuilder;
  final Widget? headerLeading;

  /// 无筛选维度的列表（如女优上新）可以整行不渲染顶栏，把高度留给内容。
  final bool showHeader;
  final bool useMobileSelectionLayout;

  /// 可选的标签筛选：传入后筛选面板末尾出现「标签」分节，选择变化实时应用
  /// 到列表筛选，顶栏摘要与重置也纳入标签条件。生命周期由调用页面管理
  /// （缓存页需把它的 cacheLink 一并注册进页面缓存）。
  final TagSelectionScope? tagSelectionScope;
  final bool enableMediaTagFilter;

  /// 卡片收起态番号行右侧文案（如「总分 4.0」）；为 null 时不显示。
  final String? Function(MovieListItemDto movie)? trailingLabelForMovie;

  @override
  ConsumerState<MovieSummaryListContent> createState() =>
      _MovieSummaryListContentState();
}

class _MovieSummaryListContentState
    extends ConsumerState<MovieSummaryListContent>
    with
        MultiSelectStateMixin<MovieSummaryListContent, String>,
        MovieBatchSelectionMixin<MovieSummaryListContent> {
  late final ScrollController _scrollController;

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(
        context,
        onBlacklisted: (movieNumber) => ref
            .read(movieSummaryProvider(widget.scope).notifier)
            .removeMovies(<String>[movieNumber]),
      );

  @override
  String get batchKeyPrefix => 'movie-list';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor => ref
      .read(movieSummaryProvider(widget.scope).notifier)
      .batchToggleSubscription;

  @override
  MovieBlacklistBatchExecutor get batchBlacklistExecutor =>
      ref.read(movieSummaryProvider(widget.scope).notifier).blacklistMovies;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(movieSummaryProvider(widget.scope))
          .value
          ?.paged
          .items
          .map((movie) => movie.movieNumber)
          .toList(growable: false) ??
      const <String>[];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilter(MovieFilterState nextState) {
    final current =
        ref.read(movieSummaryProvider(widget.scope)).value?.filter.movie ??
        widget.scope.initialMovieFilter ??
        MovieFilterState.initial;
    if (nextState.matches(current)) {
      return;
    }
    if (selectionMode) {
      exitSelection();
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(
      ref
          .read(movieSummaryProvider(widget.scope).notifier)
          .applyMovieFilter(nextState),
    );
  }

  /// 标签选择变化后重拉列表：有选择走标签条件，清空则回到无标签请求。
  void _applyTagSelection(TagSelectionState selection) {
    if (selectionMode) {
      exitSelection();
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    final notifier = ref.read(movieSummaryProvider(widget.scope).notifier);
    if (selection.hasSelection) {
      unawaited(
        notifier.applyTagFilter(
          tagIds: selection.selectedTagIds,
          tagMatch: selection.matchMode,
        ),
      );
    } else {
      unawaited(notifier.clearTagFilter());
    }
  }

  void _resetFilters() {
    final current =
        ref.read(movieSummaryProvider(widget.scope)).value?.filter.movie ??
        widget.scope.initialMovieFilter ??
        MovieFilterState.initial;
    _applyFilter(current.resetFilters());
    final tagSelectionScope = widget.tagSelectionScope;
    if (tagSelectionScope != null) {
      ref.read(tagSelectionProvider(tagSelectionScope).notifier).clear();
    }
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(widget.scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  Future<void> _handleRefresh() async {
    final error = await ref
        .read(movieSummaryProvider(widget.scope).notifier)
        .refresh();
    if (error == null || !mounted) {
      return;
    }
    final onRefreshFailure = widget.onRefreshFailure;
    if (onRefreshFailure != null) {
      onRefreshFailure(context);
    } else {
      showToast(AppLocalizations.of(context).moviePageRefreshFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 只订阅渲染所需的字段：loadMore 的 loading/失败走独立页脚
    // （[PagedLoadMoreFooterSliver]），翻页状态翻转不重建列表本体。
    final view = ref.watch(
      movieSummaryProvider(widget.scope).select(
        (asyncState) => (
          filter:
              asyncState.value?.filter.movie ??
              widget.scope.initialMovieFilter ??
              MovieFilterState.initial,
          total: asyncState.value?.paged.total ?? 0,
          items: asyncState.value?.paged.items ?? const [],
          currentPage: asyncState.value?.paged.currentPage ?? 0,
          filterUpdate:
              asyncState.value?.paged.filterUpdate ??
              const FilterUpdateState.idle(),
          isInitialLoading: asyncState.isLoading && asyncState.value == null,
          hasErrorNoValue: asyncState.hasError && asyncState.value == null,
          updating:
              asyncState.value?.subscriptionUpdatingMovieNumbers ??
              const <String>{},
        ),
      ),
    );
    final filter = view.filter;
    final items = view.items;
    // 首屏骨架：还没有任何服务端结果时都算首拉，不要先用空态冒充「这个标签下
    // 没有影片」。除 AsyncValue 仍在 loading，还包括标签页那种「先建 provider
    // （未请求，currentPage == 0）再由 post-frame 补上标签条件」的入口——补条件
    // 前后骨架不中断。真正拉过的空结果 currentPage >= 1，仍走空态。
    final isInitialLoading =
        items.isEmpty &&
        !view.hasErrorNoValue &&
        (view.isInitialLoading || view.currentPage == 0);
    final initialErrorMessage = view.hasErrorNoValue
        ? widget.scope.errorText(AppLocalizations.of(context))
        : null;

    final tagSelectionScope = widget.tagSelectionScope;
    final tagSelection = tagSelectionScope == null
        ? null
        : ref.watch(tagSelectionProvider(tagSelectionScope));
    if (tagSelectionScope != null) {
      ref.listen(tagSelectionProvider(tagSelectionScope), (previous, next) {
        if (previous == null) {
          return;
        }
        if (listEquals(previous.selectedTagIds, next.selectedTagIds) &&
            previous.matchMode == next.matchMode) {
          return;
        }
        _applyTagSelection(next);
      });
    }

    ref.listen(movieCollectionTypeEventsProvider, (_, next) {
      final change = next.value;
      if (change == null ||
          change.targetType != MovieCollectionType.collection ||
          filter.collectionType != MovieCollectionTypeFilter.single ||
          !selectionMode ||
          !selectedIds.contains(change.movieNumber)) {
        return;
      }
      setState(() => selectedIds.remove(change.movieNumber));
    });

    final headerBuilder = widget.headerBuilder;
    final Widget? header;
    if (selectionMode) {
      header = widget.useMobileSelectionLayout
          ? buildMobileBatchSelectionHeader()
          : buildBatchSelectionToolbar();
    } else if (!widget.showHeader) {
      header = null;
    } else if (headerBuilder != null) {
      header = headerBuilder(
        context,
        MovieSummaryListHeaderArgs(
          filterState: filter,
          onApply: _applyFilter,
          total: view.total,
          tagSelection: tagSelection,
        ),
      );
    } else {
      final filterLabel = movieFilterSummaryLabel(
        l10n: l10n,
        filter: filter,
        tagSelection: tagSelection,
      );
      header = AppListHeader(
        filterButtonKey: const Key('movies-filter-trigger'),
        filterLabel: filterLabel,
        filterPanelKey: const Key('movies-filter-panel'),
        filterPanelBuilder: (_) => MovieFilterSectionGroup(
          filterState: filter,
          onChanged: _applyFilter,
          tagSection: tagSelectionScope == null
              ? null
              : TagFilterSection(scope: tagSelectionScope),
          mediaTagSection: widget.enableMediaTagFilter
              ? MediaTagFilterSection(
                  selectedTagIds: filter.mediaTagIds,
                  matchMode: filter.mediaTagMatch,
                  onChanged: (tagIds, matchMode) => _applyFilter(
                    filter.copyWith(
                      mediaTagIds: tagIds,
                      mediaTagMatch: matchMode,
                    ),
                  ),
                )
              : null,
        ),
        filterPanelFooter: AppFilterPanelFooter(
          isDefault:
              !filter.hasActiveFilters &&
              !(tagSelection?.hasSelection ?? false),
          onReset: _resetFilters,
        ),
        informationSlots: [
          AppListHeaderInfo(
            key: widget.totalKey,
            label: l10n.moviePageMovieCount(view.total),
          ),
        ],
        actionSlots: [
          MovieSortMenuButton(
            triggerKey: const Key('movies-sort-trigger'),
            panelKey: const Key('movies-sort-panel'),
            filterState: filter,
            onChanged: _applyFilter,
          ),
          buildEnterSelectionButton(),
        ],
      );
    }

    final body = ColoredBox(
      color: widget.surfaceColor,
      child: AppFixedHeaderLayout(
        header: Column(
          key: widget.contentKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!selectionMode && widget.headerLeading != null)
              widget.headerLeading!,
            ?header,
            AppFilterUpdateBar(
              state: view.filterUpdate,
              hasPreviousItems: items.isNotEmpty,
              onRetry: () => unawaited(
                ref
                    .read(movieSummaryProvider(widget.scope).notifier)
                    .retryFilter(),
              ),
            ),
            SizedBox(height: widget.sectionSpacing),
          ],
        ),
        child: AppFilterResultLoadingOverlay(
          surfaceColor: widget.surfaceColor,
          // 结果区已经在渲染骨架时，不再叠居中的筛选进度层，避免遮住骨架。
          isLoading: view.filterUpdate.isLoading && !isInitialLoading,
          hasPreviousItems: items.isNotEmpty,
          child: AppPagedLoadMoreScope(
            canLoadMore: () =>
                ref
                    .read(movieSummaryProvider(widget.scope))
                    .value
                    ?.paged
                    .canAutoLoadMore ??
                false,
            onLoadMore: () => ref
                .read(movieSummaryProvider(widget.scope).notifier)
                .loadMore(),
            child: widget.bodyBuilder(
              context,
              _scrollController,
              SliverMainAxisGroup(
                slivers: [
                  if (!view.filterUpdate.hasFailed || items.isNotEmpty)
                    AppSkeletonizer.sliver(
                      enabled: isInitialLoading,
                      child: MovieSummarySliver(
                        items: isInitialLoading
                            ? movieListItemPlaceholders(count: 24)
                            : items,
                        errorMessage: initialErrorMessage,
                        trailingLabelForMovie: widget.trailingLabelForMovie,
                        onMovieTap: (movie) =>
                            widget.onMovieTap(context, movie.movieNumber),
                        onMovieMenuRequest: (movie, globalPosition) {
                          unawaited(
                            showMovieCollectionFeatureActionMenu(
                              context: context,
                              movieNumber: movie.movieNumber,
                              globalPosition: globalPosition,
                              isSubscribed: movie.isSubscribed,
                              onBlacklisted: () => ref
                                  .read(
                                    movieSummaryProvider(widget.scope).notifier,
                                  )
                                  .removeMovies(<String>[movie.movieNumber]),
                              onEnterSelection: widget.useMobileSelectionLayout
                                  ? () {
                                      enterSelection();
                                      toggleSelect(movie.movieNumber);
                                    }
                                  : null,
                            ),
                          );
                        },
                        onMovieSubscriptionTap: (movie) =>
                            _toggleMovieSubscription(movie.movieNumber),
                        onMovieToggleCollectionType:
                            _hoverFeatureActions.toggleCollectionType,
                        onMovieBlacklist: _hoverFeatureActions.blacklist,
                        isMovieSubscriptionUpdating: (movie) =>
                            view.updating.contains(movie.movieNumber),
                        emptyMessage:
                            widget.emptyMessage ??
                            (!filter.hasActiveFilters
                                ? l10n.moviePageEmptyNoMovies
                                : l10n.moviePageEmptyNoMatches),
                        selectionMode: selectionMode,
                        isMovieSelected: (movie) =>
                            isSelected(movie.movieNumber),
                        onMovieSelectedChanged: (movie, _) =>
                            toggleSelect(movie.movieNumber),
                      ),
                    ),
                  // loadMore 页脚独立订阅：翻页状态翻转只重建它，不重建上面网格。
                  PagedLoadMoreFooterSliver(
                    watchFooter: (ref) => ref.watch(
                      movieSummaryProvider(widget.scope).select(
                        (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
                      ),
                    ),
                    onLoadMore: (ref) => unawaited(
                      ref
                          .read(movieSummaryProvider(widget.scope).notifier)
                          .loadMore(),
                    ),
                  ),
                ],
              ),
              widget.enableRefresh ? _handleRefresh : null,
            ),
          ),
        ),
      ),
    );

    final content = widget.useMobileSelectionLayout
        ? Column(
            children: [
              Expanded(child: body),
              if (selectionMode) buildMobileBatchSelectionBottomBar(),
            ],
          )
        : body;
    return widget.registerPageRefresh
        ? AppPageRefreshScope(onRefresh: _handleRefresh, child: content)
        : content;
  }
}
