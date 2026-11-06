import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_movie_year_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_detail_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_mutation_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_removal_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_tag_filter_provider.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_merge_dialog.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_profile_editor.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_tag_filter_menu_button.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_sort_menu_button.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/domain/tags/media_tag_filter_section.dart';

import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

typedef ActorDetailBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget child,
      Future<void> Function()? onRefresh,
    );

typedef ActorDetailHeaderBuilder =
    Widget Function(
      BuildContext context,
      ActorDetailDto actor,
      bool isSubscribed,
      bool isSubscriptionUpdating,
      VoidCallback? onSubscriptionTap,
      VoidCallback onEditTap,
      VoidCallback onMergeTap,
    );

typedef ActorDetailErrorBuilder =
    Widget Function(BuildContext context, String message, VoidCallback onRetry);

class ActorDetailContent extends ConsumerStatefulWidget {
  const ActorDetailContent({
    super.key,
    required this.actorId,
    required this.surfaceColor,
    required this.contentKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.headerBuilder,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.bodyBuilder,
    this.enableRefresh = false,
    this.onRefreshFailure,
    this.useMobileFilterDrawer = false,
    this.useMobileSelectionLayout = false,
  });

  final int actorId;
  final Color surfaceColor;
  final Key contentKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final ActorDetailHeaderBuilder headerBuilder;
  final WidgetBuilder loadingBuilder;
  final ActorDetailErrorBuilder errorBuilder;
  final ActorDetailBodyBuilder bodyBuilder;
  final bool enableRefresh;
  final void Function(BuildContext context)? onRefreshFailure;

  /// 顶栏筛选入口点开什么：`true` 弹底部抽屉（移动端），`false` 就地展开浮层
  /// （桌面端）。两端按钮外观、面板内容、条件即时更新行为完全一致，只有容器不同。
  final bool useMobileFilterDrawer;

  /// 移动端多选布局：入口挂到**卡片长按浮层**（顶栏不再常驻「选择」），多选态
  /// 顶栏只留退出/计数/全选，批量动作走贴底的 `AppSelectionBottomBar`。
  /// 桌面端保持 `false`——批量动作在顶栏内联。语义对齐 `MovieSummaryListContent`。
  final bool useMobileSelectionLayout;

  @override
  ConsumerState<ActorDetailContent> createState() => _ActorDetailContentState();
}

class _ActorDetailContentState extends ConsumerState<ActorDetailContent>
    with
        MultiSelectStateMixin<ActorDetailContent, String>,
        MovieBatchSelectionMixin<ActorDetailContent> {
  late final ScrollController _scrollController;
  final _listHeaderKey = GlobalKey();

  List<MovieFilterYearOption> _movieYearOptions =
      const <MovieFilterYearOption>[];
  bool _hasLoadedMovieYears = false;
  bool _isMovieYearsLoading = false;
  String? _movieYearsErrorMessage;
  bool? _isActorSubscribedOverride;
  bool _isActorSubscriptionUpdating = false;

  MovieSummaryScope get _scope =>
      MovieSummaryScope.actor(actorId: widget.actorId);

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(
        context,
        onBlacklisted: (movieNumber) => ref
            .read(movieSummaryProvider(_scope).notifier)
            .removeMovies(<String>[movieNumber]),
      );

  MovieFilterState get _filterState =>
      ref.read(movieSummaryProvider(_scope)).value?.filter.movie ??
      MovieFilterState.initial;

  @override
  String get batchKeyPrefix => 'actor-detail';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      ref.read(movieSummaryProvider(_scope).notifier).batchToggleSubscription;

  @override
  MovieBlacklistBatchExecutor get batchBlacklistExecutor =>
      ref.read(movieSummaryProvider(_scope).notifier).blacklistMovies;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(movieSummaryProvider(_scope))
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
    if (nextState.matches(_filterState)) {
      return;
    }
    // 切筛选跨结果集，选中态失去意义，对齐 MovieSummaryListContent 行为。
    if (selectionMode) {
      exitSelection();
    }
    AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
    unawaited(
      ref
          .read(movieSummaryProvider(_scope).notifier)
          .applyMovieFilter(nextState),
    );
  }

  void _resetFilters() {
    _applyFilter(_filterState.resetFilters());
  }

  /// 标签选择变化后重拉作品列表：有选择走 tag 条件，清空则回到无标签请求。
  void _applyTagSelection(TagSelectionState selection) {
    if (selectionMode) {
      exitSelection();
    }
    AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
    final notifier = ref.read(movieSummaryProvider(_scope).notifier);
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

  void _loadMovieYearsIfNeeded() {
    if (_hasLoadedMovieYears || _isMovieYearsLoading) {
      return;
    }
    unawaited(_loadMovieYears());
  }

  Future<void> _loadMovieYears({bool force = false}) async {
    if (_isMovieYearsLoading || (_hasLoadedMovieYears && !force)) {
      return;
    }
    setState(() {
      _isMovieYearsLoading = true;
      _movieYearsErrorMessage = null;
    });

    try {
      final years = await ref
          .read(actorsApiProvider)
          .getActorMovieYears(actorId: widget.actorId);
      if (!mounted) {
        return;
      }
      setState(() {
        _movieYearOptions = years
            .map(_toFilterYearOption)
            .toList(growable: false);
        _hasLoadedMovieYears = true;
        _isMovieYearsLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMovieYearsLoading = false;
        _movieYearsErrorMessage = AppLocalizations.of(
          context,
        ).actorMovieYearsLoadFailed;
      });
    }
  }

  MovieFilterYearOption _toFilterYearOption(ActorMovieYearDto item) {
    return MovieFilterYearOption(year: item.year, movieCount: item.movieCount);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  Future<void> _toggleActorSubscription({required bool isSubscribed}) async {
    if (_isActorSubscriptionUpdating) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isActorSubscriptionUpdating = true;
    });

    ActorSubscriptionToggleResult result;

    try {
      if (isSubscribed) {
        await ref
            .read(actorsApiProvider)
            .unsubscribeActor(actorId: widget.actorId);
        result = const ActorSubscriptionToggleResult.unsubscribed();
        _isActorSubscribedOverride = false;
      } else {
        await ref
            .read(actorsApiProvider)
            .subscribeActor(actorId: widget.actorId);
        result = const ActorSubscriptionToggleResult.subscribed();
        _isActorSubscribedOverride = true;
      }
    } catch (error) {
      result = ActorSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: isSubscribed
              ? l10n.actorUnsubscribeFailed
              : l10n.actorSubscribeFailed,
          l10n: l10n,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    if (result.status == ActorSubscriptionToggleStatus.subscribed ||
        result.status == ActorSubscriptionToggleStatus.unsubscribed) {
      ref
          .read(actorSubscriptionEventsProvider.notifier)
          .reportChange(
            actorId: widget.actorId,
            isSubscribed:
                result.status == ActorSubscriptionToggleStatus.subscribed,
          );
    }

    setState(() {
      _isActorSubscriptionUpdating = false;
    });
    showActorSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  Future<void> _openActorEditor(ActorDetailDto actor) async {
    final updated = await showActorProfileEditor(
      context,
      actor: actor,
      api: ref.read(actorsApiProvider),
    );
    if (!mounted || updated == null) {
      return;
    }
    ref
        .read(actorDetailProvider(widget.actorId).notifier)
        .replaceActor(updated);
    ref
        .read(actorMutationEventsProvider.notifier)
        .reportUpdated(updated.summary);
  }

  Future<void> _openActorMerger(ActorDetailDto actor) async {
    final result = await showActorMergeDialog(
      context,
      actor: actor,
      api: ref.read(actorsApiProvider),
    );
    if (!mounted || result == null) {
      return;
    }
    ref
        .read(actorDetailProvider(widget.actorId).notifier)
        .replaceActor(result.actor);
    ref
        .read(actorMutationEventsProvider.notifier)
        .reportUpdated(result.actor.summary);
    ref
        .read(actorRemovalEventsProvider.notifier)
        .reportRemoved(result.sourceActorIds);
    // 影片归属发生变化：重拉作品列表与懒加载的年份筛选。
    ref.invalidate(movieSummaryProvider(_scope));
    ref.invalidate(actorTagFilterProvider(widget.actorId));
    setState(() {
      _hasLoadedMovieYears = false;
      _movieYearOptions = const <MovieFilterYearOption>[];
    });
    showToast(
      AppLocalizations.of(
        context,
      ).actorMergeCompleted(result.sourceActorIds.length),
      tone: AppToastTone.success,
    );
  }

  /// 影片区顶栏：桌面玻璃分组，移动端紧凑图标行。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  ///
  /// 数量属于当前作品筛选结果，随作品列表一起展示。
  Widget _buildFilterHeader(
    BuildContext context,
    MovieFilterState filterState,
    PagedViewSnapshot<MovieListItemDto> movies,
  ) {
    final l10n = AppLocalizations.of(context);
    final totalLabel = l10n.actorMovieCountLabel(movies.total);
    final showTotal = !movies.isInitialLoading && movies.initialError == null;
    if (widget.useMobileFilterDrawer) {
      return AppMobileListHeader(
        leading: showTotal ? AppMobileHeaderText(countLabel: totalLabel) : null,
        actions: <Widget>[
          AppGlassFilterIconButton(
            key: const Key('actor-detail-filter-trigger'),
            summary: filterState.triggerLabel(l10n),
            isActive: filterState.hasActiveFilters,
            onPressed: () => unawaited(_openFilterDrawer()),
          ),
          ActorTagFilterMenuButton(
            actorId: widget.actorId,
            triggerKey: const Key('actor-detail-tag-filter-trigger'),
            panelKey: const Key('actor-detail-tag-filter-panel'),
            drawerKey: const Key('mobile-actor-detail-tag-filter-drawer'),
            useDrawer: true,
          ),
          MovieSortMenuButton(
            triggerKey: const Key('actor-detail-sort-trigger'),
            drawerKey: const Key('mobile-actor-detail-sort-drawer'),
            filterState: filterState,
            onChanged: _applyFilter,
            useDrawer: true,
            iconOnly: true,
          ),
        ],
        filterUpdate: movies.filterUpdate,
        hasPreviousFilterItems: movies.items.isNotEmpty,
        onRetryFilter: () => unawaited(
          ref.read(movieSummaryProvider(_scope).notifier).retryFilter(),
        ),
      );
    }
    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('actor-detail-filter-panel'),
        scrollable: true,
        isDefault: !filterState.hasActiveFilters,
        onReset: _resetFilters,
        triggerKey: const Key('actor-detail-filter-trigger'),
        label: filterState.triggerLabel(l10n),
        onBeforeOpen: _loadMovieYearsIfNeeded,
        info: [if (showTotal) AppGlassHeaderText(label: totalLabel)],
        panelBuilder: (context) => MovieFilterSectionGroup(
          filterState: filterState,
          onChanged: _applyFilter,
          showActorAgeSection: false,
          mediaTagSection: MediaTagFilterSection(
            filter: filterState,
            onChanged: _applyFilter,
          ),
          yearOptions: _movieYearOptions,
          isYearOptionsLoading: _isMovieYearsLoading,
          yearOptionsErrorMessage: _movieYearsErrorMessage,
          onYearOptionsRetry: () => unawaited(_loadMovieYears(force: true)),
        ),
      ),
      filterUpdate: movies.filterUpdate,
      hasPreviousFilterItems: movies.items.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(movieSummaryProvider(_scope).notifier).retryFilter(),
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          ActorTagFilterMenuButton(
            actorId: widget.actorId,
            triggerKey: const Key('actor-detail-tag-filter-trigger'),
            panelKey: const Key('actor-detail-tag-filter-panel'),
            drawerKey: const Key('mobile-actor-detail-tag-filter-drawer'),
            glassGrouped: true,
          ),
          MovieSortMenuButton(
            triggerKey: const Key('actor-detail-sort-trigger'),
            drawerKey: const Key('mobile-actor-detail-sort-drawer'),
            filterState: filterState,
            onChanged: _applyFilter,
            glassGrouped: true,
          ),
          if (batchSelectableNumbers.isNotEmpty)
            AppGlassHeaderButton(
              key: Key('$batchKeyPrefix-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              onTap: enterSelection,
            ),
        ],
      ),
    );
  }

  Future<void> _openFilterDrawer() async {
    // 年份是懒加载的，而抽屉内容是**打开那一刻的快照**（不像桌面浮层会随
    // didUpdateWidget 重建）。所以这里先把年份取回来再弹，否则抽屉里的年份分节
    // 会永远停在转圈状态。只有首次点击会等这一次请求。
    if (!_hasLoadedMovieYears) {
      await _loadMovieYears();
    }
    if (!mounted) {
      return;
    }
    await showMobileMovieFilterDrawer(
      context,
      current: _filterState,
      onChanged: _applyFilter,
      showActorAgeSection: false,
      mediaTagSectionBuilder: (context, local, onApply) =>
          MediaTagFilterSection(filter: local, onChanged: onApply),
      yearOptions: _movieYearOptions,
      yearOptionsErrorMessage: _movieYearsErrorMessage,
      onYearOptionsRetry: () => unawaited(_loadMovieYears(force: true)),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await Future.wait<void>([
        ref.read(actorDetailProvider(widget.actorId).notifier).refresh(),
        ref.read(movieSummaryProvider(_scope).notifier).refresh(),
        if (_hasLoadedMovieYears) _loadMovieYears(force: true),
      ]);
      // 手势刷新成功计一次浏览（与 movie 详情页一致；provider 的 refresh
      // 自身不上报，避免后台同步顶进「最近浏览」）。
      ref.read(actorDetailProvider(widget.actorId).notifier).reportView();
      if (mounted) {
        setState(() {
          _isActorSubscribedOverride = null;
        });
      }
    } catch (_) {
      if (mounted) {
        final onRefreshFailure = widget.onRefreshFailure;
        if (onRefreshFailure != null) {
          onRefreshFailure(context);
        } else {
          showToast(
            AppLocalizations.of(context).actorRefreshFailed,
            tone: AppToastTone.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(actorDetailProvider(widget.actorId));
    final actorState = actorAsync.value;
    final movies = ref.watch(
      movieSummaryProvider(
        _scope,
      ).select((state) => pagedViewSnapshot(state, (summary) => summary.paged)),
    );
    final movieFilter = ref.watch(
      movieSummaryProvider(_scope).select(
        (state) => state.value?.filter.movie ?? MovieFilterState.initial,
      ),
    );
    final subscriptionUpdating = ref.watch(
      movieSummaryProvider(_scope).select(
        (state) => StableSetSelection<String>(
          state.value?.subscriptionUpdatingMovieNumbers ?? const <String>{},
        ),
      ),
    );
    ref.listen(actorTagFilterProvider(widget.actorId), (previous, next) {
      if (previous == null) {
        return;
      }
      if (listEquals(previous.selectedTagIds, next.selectedTagIds) &&
          previous.matchMode == next.matchMode) {
        return;
      }
      _applyTagSelection(next);
    });
    ref.listen(movieCollectionTypeEventsProvider, (_, next) {
      final change = next.value;
      if (change == null ||
          change.targetType != MovieCollectionType.collection ||
          _filterState.collectionType != MovieCollectionTypeFilter.single ||
          !selectionMode ||
          !selectedIds.contains(change.movieNumber)) {
        return;
      }
      setState(() => selectedIds.remove(change.movieNumber));
    });

    final body = AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: Builder(
        builder: (context) {
          if (actorAsync.isLoading && actorState?.actor == null) {
            return widget.loadingBuilder(context);
          }

          if (actorState?.errorMessage != null || actorState?.actor == null) {
            return widget.errorBuilder(
              context,
              actorState?.errorMessage ??
                  AppLocalizations.of(context).actorDetailLoadFailed,
              () => unawaited(
                ref.read(actorDetailProvider(widget.actorId).notifier).reload(),
              ),
            );
          }

          final actor = actorState!.actor!;
          final isActorSubscribed =
              _isActorSubscribedOverride ?? actor.summary.isSubscribed;

          return AppFilterResultLoadingOverlay(
            surfaceColor: widget.surfaceColor,
            protectedHeaderKey: _listHeaderKey,
            scrollController: _scrollController,
            isLoading: movies.filterUpdate.isLoading,
            hasPreviousItems: movies.items.isNotEmpty,
            child: AppPagedLoadMoreScope(
              canLoadMore: () =>
                  ref
                      .read(movieSummaryProvider(_scope))
                      .value
                      ?.paged
                      .canAutoLoadMore ??
                  false,
              onLoadMore: () =>
                  ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
              child: widget.bodyBuilder(
                context,
                _scrollController,
                AppPinnedSliverSection(
                  headerKey: _listHeaderKey,
                  before: <Widget>[
                    SliverToBoxAdapter(
                      child: KeyedSubtree(
                        key: widget.contentKey,
                        child: widget.headerBuilder(
                          context,
                          actor,
                          isActorSubscribed,
                          _isActorSubscriptionUpdating,
                          _isActorSubscriptionUpdating
                              ? null
                              : () => _toggleActorSubscription(
                                  isSubscribed: isActorSubscribed,
                                ),
                          () => unawaited(_openActorEditor(actor)),
                          () => unawaited(_openActorMerger(actor)),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: widget.sectionSpacing),
                    ),
                  ],
                  header: selectionMode
                      ? (widget.useMobileSelectionLayout
                            ? buildMobileBatchSelectionHeader()
                            : buildGlassBatchSelectionToolbar())
                      : _buildFilterHeader(context, movieFilter, movies),
                  headerBottomSpacing: widget.sectionSpacing,
                  after: <Widget>[
                    if (!movies.filterUpdate.hasFailed ||
                        movies.items.isNotEmpty)
                      AppSkeletonizer.sliver(
                        enabled: movies.isInitialLoading,
                        child: MovieSummarySliver(
                          items: movies.isInitialLoading
                              ? movieListItemPlaceholders(count: 24)
                              : movies.items,
                          errorMessage: movies.initialError != null
                              ? _scope.errorText(AppLocalizations.of(context))
                              : null,
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
                                    .read(movieSummaryProvider(_scope).notifier)
                                    .removeMovies(<String>[movie.movieNumber]),
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
                          onMovieSubscriptionTap: (movie) =>
                              _toggleMovieSubscription(movie.movieNumber),
                          onMovieToggleCollectionType:
                              _hoverFeatureActions.toggleCollectionType,
                          onMovieBlacklist: _hoverFeatureActions.blacklist,
                          isMovieSubscriptionUpdating: (movie) =>
                              subscriptionUpdating.contains(movie.movieNumber),
                          emptyMessage: AppLocalizations.of(
                            context,
                          ).actorMoviesEmpty,
                          selectionMode: selectionMode,
                          isMovieSelected: (movie) =>
                              isSelected(movie.movieNumber),
                          onMovieSelectedChanged: (movie, _) =>
                              toggleSelect(movie.movieNumber),
                        ),
                      ),
                    PagedLoadMoreFooterSliver(
                      watchFooter: (ref) => ref.watch(
                        movieSummaryProvider(_scope).select(
                          (state) =>
                              pagedLoadMoreFooterSnapshot(state.value?.paged),
                        ),
                      ),
                      onLoadMore: (ref) => unawaited(
                        ref
                            .read(movieSummaryProvider(_scope).notifier)
                            .loadMore(),
                      ),
                      topSpacing: PagedFooterSpacing.md,
                      padWhenIdle: true,
                    ),
                  ],
                ),
                widget.enableRefresh ? _handleRefresh : null,
              ),
            ),
          );
        },
      ),
    );

    if (!widget.useMobileSelectionLayout) {
      return body;
    }
    // 底部批量条贴在列表下方常驻，不随列表滚动（对齐 MovieSummaryListContent）。
    return Column(
      children: [
        Expanded(child: body),
        if (selectionMode) buildMobileBatchSelectionBottomBar(),
      ],
    );
  }
}
