import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collection_placeholders.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_to_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/pick_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/actions/clip_playback_launcher.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_filter.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/rename_clip_dialog.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_actions_panel.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';

/// 切片首页共享内容：合集横滑区 + 全部切片网格 + 单条/批量动作。
///
/// 桌面与移动只在壳层不同：桌面使用玻璃顶栏、悬停卡和内联批量栏；
/// 移动使用移动顶栏、封面卡、长按多选和底部批量条。数据、排序、刷新、
/// mutation 监听和动作逻辑全部收在这里。
class ClipsOverviewContent extends ConsumerStatefulWidget {
  const ClipsOverviewContent({super.key, required this.mobile});

  final bool mobile;

  @override
  ConsumerState<ClipsOverviewContent> createState() =>
      _ClipsOverviewContentState();
}

class _ClipsOverviewContentState extends ConsumerState<ClipsOverviewContent>
    with MultiSelectStateMixin<ClipsOverviewContent, int> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listHeaderKey = GlobalKey();
  bool _railRefreshScheduled = false;

  bool get _mobile => widget.mobile;

  String get _pageKeyPrefix => _mobile ? 'mobile-clips' : 'clips';

  String get _clipKeyPrefix => _mobile ? 'mobile-clip' : 'clip';

  String get _collectionCardKeyPrefix =>
      _mobile ? 'mobile-clip-collection-card' : 'clip-collection-card';

  @override
  List<int> get selectionOrderedIds =>
      ref
          .read(clipsOverviewProvider)
          .value
          ?.paged
          .items
          .map((clip) => clip.clipId)
          .toList(growable: false) ??
      const <int>[];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 切片删除 / 合集成员变化都可能改变合集横滑区的封面与计数；用微任务把一轮内
  /// 的多次信号（如详情页批量改动）合并成一次刷新，避免 N 次请求。切片本身被删除
  /// 时再从「全部切片」网格精准移除。
  void _onMutation(ClipMutationChange change) {
    if (change.kind == ClipMutationKind.deleted && change.clipId != null) {
      ref.read(clipsOverviewProvider.notifier).removeClip(change.clipId!);
    }
    if (_railRefreshScheduled) {
      return;
    }
    _railRefreshScheduled = true;
    scheduleMicrotask(() {
      _railRefreshScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(ref.read(clipCollectionsOverviewProvider.notifier).refresh());
    });
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      ref.read(clipsOverviewProvider.notifier).refresh(),
      ref.read(clipCollectionsOverviewProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ClipMutationChange>>(clipMutationEventsProvider, (
      previous,
      next,
    ) {
      final change = next.value;
      if (change != null) {
        _onMutation(change);
      }
    });

    final clipsView = ref.watch(
      clipsOverviewProvider.select(
        (async) => pagedViewSnapshot(async, (state) => state.paged),
      ),
    );
    final collectionsAsync = ref.watch(clipCollectionsOverviewProvider);

    if (_mobile) {
      final isActive = ref.watch(mobileOverviewTabIndexProvider) == 1;
      return Column(
        children: [
          Expanded(
            child: _buildFilterableBody(
              context: context,
              clipsView: clipsView,
              collectionsAsync: collectionsAsync,
              autoLoadEnabled: isActive,
            ),
          ),
          if (selectionMode) _buildMobileBatchBar(context),
        ],
      );
    }

    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          if (clipsView.initialError case final error?) {
            return AppErrorState(
              title: l10n.errorClipLoadFailed,
              message: apiErrorMessage(
                error,
                fallback: l10n.errorClipLoadFailed,
                l10n: l10n,
              ),
              retryKey: const Key('clips-initial-error-retry'),
              onRetry: () => ref.read(clipsOverviewProvider.notifier).refresh(),
            );
          }
          return _buildFilterableBody(
            context: context,
            clipsView: clipsView,
            collectionsAsync: collectionsAsync,
            autoLoadEnabled: true,
          );
        },
      ),
    );
  }

  Widget _buildFilterableBody({
    required BuildContext context,
    required PagedViewSnapshot<MediaClipDto> clipsView,
    required AsyncValue<List<ClipCollectionDto>> collectionsAsync,
    required bool autoLoadEnabled,
  }) {
    final clips = clipsView.items;
    return AppFilterResultLoadingOverlay(
      surfaceColor: _mobile ? context.appColors.surfaceCard : null,
      protectedHeaderKey: _listHeaderKey,
      scrollController: _scrollController,
      isLoading: clipsView.filterUpdate.isLoading,
      hasPreviousItems: clips.isNotEmpty,
      child: AppPagedLoadMoreScope(
        enabled: autoLoadEnabled,
        canLoadMore: () =>
            ref.read(clipsOverviewProvider).value?.paged.canAutoLoadMore ??
            false,
        onLoadMore: () => ref.read(clipsOverviewProvider.notifier).loadMore(),
        child: _buildScrollable(
          context: context,
          clipsView: clipsView,
          collectionsAsync: collectionsAsync,
        ),
      ),
    );
  }

  Widget _buildScrollable({
    required BuildContext context,
    required PagedViewSnapshot<MediaClipDto> clipsView,
    required AsyncValue<List<ClipCollectionDto>> collectionsAsync,
  }) {
    final slivers = <Widget>[
      AppPinnedSliverSection(
        headerKey: _listHeaderKey,
        before: <Widget>[
          SliverToBoxAdapter(
            child: _buildCollectionsSection(context, collectionsAsync),
          ),
        ],
        header: _buildClipsHeader(context, clipsView.items),
        headerBottomSpacing: _mobile
            ? context.appSpacing.md
            : context.appSpacing.lg,
        after: <Widget>[
          _buildClipsSliver(context, clipsView),
          // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
          PagedLoadMoreFooterSliver(
            hiddenSpacing: PagedFooterSpacing.lg,
            watchFooter: (ref) => ref.watch(
              clipsOverviewProvider.select(
                (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
              ),
            ),
            onLoadMore: (ref) =>
                unawaited(ref.read(clipsOverviewProvider.notifier).loadMore()),
          ),
        ],
      ),
    ];

    if (_mobile) {
      return AppAdaptiveRefreshScrollView(
        key: const Key('mobile-clips-tab-scroll'),
        controller: _scrollController,
        onRefresh: _refresh,
        slivers: slivers,
      );
    }
    return CustomScrollView(controller: _scrollController, slivers: slivers);
  }

  // ----------------------------------------------------------- 合集区

  Widget _buildCollectionsSection(
    BuildContext context,
    AsyncValue<List<ClipCollectionDto>> collectionsAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final collections = collectionsAsync.value ?? const <ClipCollectionDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_mobile) SizedBox(height: spacing.sm),
        Row(
          children: [
            Text(
              l10n.clipCollectionsTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            const Spacer(),
            AppTextButton(
              key: Key('$_pageKeyPrefix-create-collection-button'),
              label: l10n.clipCollectionCreate,
              size: AppTextButtonSize.small,
              onPressed: _createCollection,
            ),
            if (collections.isNotEmpty) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: Key('$_pageKeyPrefix-view-all-collections-button'),
                label: l10n.clipCollectionViewAll,
                size: AppTextButtonSize.small,
                onPressed: _viewAllCollections,
              ),
            ],
          ],
        ),
        SizedBox(height: spacing.sm),
        _buildCollectionsRow(context, collectionsAsync, collections),
        SizedBox(height: spacing.lg),
      ],
    );
  }

  Widget _buildCollectionsRow(
    BuildContext context,
    AsyncValue<List<ClipCollectionDto>> collectionsAsync,
    List<ClipCollectionDto> collections,
  ) {
    final l10n = AppLocalizations.of(context);
    if (collectionsAsync.hasError && collections.isEmpty) {
      return CollectionHintBox.error(
        message: apiErrorMessage(
          collectionsAsync.error!,
          fallback: l10n.clipCollectionsLoadFailedFallback,
          l10n: l10n,
        ),
        retryKey: const Key('clips-collections-retry'),
        onRetry: () => unawaited(
          ref.read(clipCollectionsOverviewProvider.notifier).refresh(),
        ),
      );
    }
    final isLoading = collectionsAsync.isLoading && collections.isEmpty;
    final display = isLoading
        ? clipCollectionPlaceholders(count: 4)
        : collections;
    if (display.isEmpty) {
      return CollectionHintBox(message: l10n.clipCollectionsEmptyHint);
    }
    final spacing = context.appSpacing;
    final itemWidth = _mobile ? 168.0 : 210.0;
    return AppSkeletonizer(
      enabled: isLoading,
      child: SizedBox(
        height: itemWidth * 9 / 16,
        child: ListView.separated(
          key: Key('$_pageKeyPrefix-collections-row'),
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          separatorBuilder: (context, index) =>
              SizedBox(width: _mobile ? spacing.sm : spacing.md),
          itemBuilder: (context, index) {
            final collection = display[index];
            return SizedBox(
              width: itemWidth,
              child: CollectionCard.clip(
                key: Key('$_collectionCardKeyPrefix-${collection.id}'),
                collection: collection,
                onTap: () => _openCollection(context, collection.id),
              ),
            );
          },
        ),
      ),
    );
  }

  // ----------------------------------------------------------- 切片区

  Widget _buildClipsHeader(BuildContext context, List<MediaClipDto> clips) {
    final l10n = AppLocalizations.of(context);
    final hasClips = clips.isNotEmpty;
    if (selectionMode) {
      return _mobile
          ? _buildMobileSelectionHeader(context, clips)
          : _buildDesktopSelectionHeader(context, clips);
    }
    if (_mobile) {
      final summary = ref.watch(
        clipsOverviewProvider.select(
          (asyncState) => (
            sort: asyncState.value?.filter.sort ?? ClipsFilter.defaultSort,
            filterUpdate:
                asyncState.value?.paged.filterUpdate ??
                const FilterUpdateState.idle(),
          ),
        ),
      );
      final currentSort = summary.sort;
      return AppMobileListHeader(
        leading: AppMobileHeaderText(
          title: l10n.clipCollectionAllClipsTitle,
          countLabel: l10n.clipListTotalCount(clips.length),
        ),
        actions: <Widget>[
          AppGlassIconButton(
            key: const Key('mobile-clips-sort-trigger'),
            tooltip: currentSort == ClipsFilter.defaultSort
                ? l10n.clipSortLatest
                : l10n.clipSortEarliest,
            icon: Icons.swap_vert_rounded,
            onPressed: () => _applySort(
              currentSort == ClipsFilter.defaultSort
                  ? 'created_at:asc'
                  : ClipsFilter.defaultSort,
            ),
          ),
          if (hasClips)
            AppGlassIconButton(
              key: const Key('mobile-clips-enter-selection-button'),
              tooltip: l10n.clipEnterSelection,
              icon: Icons.check_circle_outline,
              onPressed: enterSelection,
            ),
        ],
        filterUpdate: summary.filterUpdate,
        hasPreviousFilterItems: hasClips,
        onRetryFilter: () =>
            unawaited(ref.read(clipsOverviewProvider.notifier).retryFilter()),
      );
    }

    // 顶栏只订阅排序与筛选更新态：翻页 loading/失败不重建顶栏。
    final headerView = ref.watch(
      clipsOverviewProvider.select(
        (asyncState) => (
          sort: asyncState.value?.filter.sort ?? ClipsFilter.defaultSort,
          total: asyncState.value?.paged.total ?? 0,
          filterUpdate:
              asyncState.value?.paged.filterUpdate ??
              const FilterUpdateState.idle(),
        ),
      ),
    );
    final currentSort = headerView.sort;
    return AppGlassListHeader(
      leading: AppGlassPopover(
        panelKey: const Key('clips-sort-panel'),
        triggerBuilder: (context, toggle) => AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: const Key('clips-sort-trigger'),
              icon: Icons.swap_vert_rounded,
              label: _clipSortLabel(l10n, currentSort),
              trailingIcon: Icons.expand_more_rounded,
              tooltip: l10n.baseSortTooltip,
              onTap: toggle,
            ),
            AppGlassHeaderText(
              key: const Key('clips-page-total'),
              label: l10n.clipListTotalCount(headerView.total),
            ),
          ],
        ),
        contentBuilder: (context, close) => AppFilterChoiceSection<String>(
          title: l10n.baseSortTitle,
          controlKey: const Key('clips-sort-order'),
          items: <AppSegmentedItem<String>>[
            AppSegmentedItem(
              value: ClipsFilter.defaultSort,
              label: l10n.clipSortLatest,
            ),
            AppSegmentedItem(
              value: 'created_at:asc',
              label: l10n.clipSortEarliest,
            ),
          ],
          selected: currentSort,
          onChanged: _applySort,
        ),
      ),
      trailing: hasClips
          ? AppGlassHeaderGroup(
              children: <Widget>[
                AppGlassHeaderButton(
                  key: const Key('clips-enter-selection-button'),
                  icon: Icons.check_circle_outline,
                  label: l10n.baseSelect,
                  onTap: enterSelection,
                ),
              ],
            )
          : null,
      filterUpdate: headerView.filterUpdate,
      hasPreviousFilterItems: hasClips,
      onRetryFilter: () =>
          unawaited(ref.read(clipsOverviewProvider.notifier).retryFilter()),
    );
  }

  String _clipSortLabel(AppLocalizations l10n, String sort) =>
      sort == ClipsFilter.defaultSort
      ? l10n.clipSortLatest
      : l10n.clipSortEarliest;

  void _applySort(String sort) {
    final current = ref.read(clipsOverviewProvider).value?.filter.sort;
    if (current == sort) return;
    if (_scrollController.hasClients) {
      AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
    }
    unawaited(ref.read(clipsOverviewProvider.notifier).applySort(sort));
  }

  Widget _buildDesktopSelectionHeader(
    BuildContext context,
    List<MediaClipDto> clips,
  ) {
    final l10n = AppLocalizations.of(context);
    final clipIds = clips.map((clip) => clip.clipId);
    final allSelected = isAllSelected(clipIds);
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.clipCollectionAdd,
      BatchOperationType.clipDelete,
    ]);
    return AppGlassSelectionHeader(
      selectionLabel: l10n.clipSelectionCount(selectedCount),
      selectAllLabel: allSelected ? l10n.clipDeselectAll : l10n.clipSelectAll,
      selectAllKey: const Key('clips-select-all-button'),
      onToggleAll: () => toggleSelectAll(clipIds),
      exitKey: const Key('clips-exit-selection-button'),
      onExitSelection: exitSelection,
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: const Key('clips-batch-add-collection-button'),
          label: l10n.clipAddToCollection,
          icon: Icons.playlist_add_rounded,
          isLoading: submitting,
          onTap: hasSelection && !submitting ? _batchAddToCollection : null,
        ),
        AppGlassSelectionAction(
          key: const Key('clips-batch-delete-button'),
          label: l10n.commonDelete,
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          isLoading: submitting,
          onTap: hasSelection && !submitting ? _batchDelete : null,
        ),
      ],
    );
  }

  Widget _buildMobileSelectionHeader(
    BuildContext context,
    List<MediaClipDto> clips,
  ) {
    final l10n = AppLocalizations.of(context);
    final clipIds = clips.map((clip) => clip.clipId);
    final allSelected = isAllSelected(clipIds);
    return AppMobileSelectionHeader(
      selectionLabel: l10n.clipSelectionCount(selectedCount),
      exitKey: const Key('mobile-clips-exit-selection-button'),
      onExitSelection: exitSelection,
      selectAllKey: const Key('mobile-clips-select-all-button'),
      selectAllTooltip: allSelected ? l10n.clipDeselectAll : l10n.clipSelectAll,
      onToggleAll: () => toggleSelectAll(clipIds),
    );
  }

  Widget _buildMobileBatchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.clipCollectionAdd,
      BatchOperationType.clipDelete,
    ]);
    return AppSelectionBottomBar(
      key: const Key('mobile-clips-batch-bottom-bar'),
      actions: [
        AppButton(
          key: const Key('mobile-clips-batch-add-collection-button'),
          label: l10n.clipAddToCollection,
          variant: AppButtonVariant.secondary,
          isLoading: submitting,
          onPressed: hasSelection && !submitting ? _batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('mobile-clips-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          isLoading: submitting,
          onPressed: hasSelection && !submitting ? _batchDelete : null,
        ),
      ],
    );
  }

  Widget _buildClipsSliver(
    BuildContext context,
    PagedViewSnapshot<MediaClipDto> view,
  ) {
    final l10n = AppLocalizations.of(context);
    final clips = view.items;
    final isLoading = view.isInitialLoading;
    if (!isLoading && clips.isEmpty && view.filterUpdate.hasFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (!isLoading && clips.isEmpty && view.initialError != null) {
      final error = view.initialError!;
      return SliverToBoxAdapter(
        child: AppErrorState(
          title: l10n.errorClipLoadFailed,
          message: apiErrorMessage(
            error,
            fallback: l10n.errorClipLoadFailed,
            l10n: l10n,
          ),
          variant: AppStatePanelVariant.section,
          retryKey: const Key('clips-grid-error-retry'),
          onRetry: () => ref.read(clipsOverviewProvider.notifier).refresh(),
        ),
      );
    }
    if (!isLoading && clips.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: l10n.clipEmpty),
        ),
      );
    }
    // loading 用占位切片渲染同一份真实网格，由 [AppSkeletonizer] 灰化。
    final display = isLoading
        ? clipPlaceholders(count: _mobile ? 6 : 8)
        : clips;
    return AppSkeletonizer.sliver(
      enabled: isLoading,
      child: AppAdaptiveCardSliver<MediaClipDto>(
        gridKey: Key('$_pageKeyPrefix-grid'),
        items: display,
        childAspectRatio: 16 / 9,
        itemBuilder: (context, clip, index) {
          if (_mobile) {
            return ClipCoverCard(
              key: Key('mobile-clip-grid-card-${clip.clipId}'),
              clip: clip,
              onTap: selectionAwareTap(
                clip.clipId,
                () => _openClipActions(clip),
              ),
              selectionMode: selectionMode,
              isSelected: isSelected(clip.clipId),
              onSelectedChanged: selectionChangedHandler(clip.clipId),
              onLongPress: selectionMode
                  ? null
                  : selectionLongPressHandler(clip.clipId),
            );
          }
          final movieNumber = clip.movieNumber;
          return ClipGridCard(
            key: Key('clip-grid-card-${clip.clipId}'),
            clip: clip,
            tapKey: Key('clip-grid-card-tap-${clip.clipId}'),
            onTap: selectionAwareTap(clip.clipId, () => _openClipActions(clip)),
            onPlay: () => _playClip(clip),
            onRename: () => _renameClip(clip),
            onDelete: () => _deleteClip(clip),
            onAddToCollection: () => _addToCollection(clip),
            onOpenMovie: movieNumber != null && movieNumber.isNotEmpty
                ? () => _openMovie(movieNumber)
                : null,
            selectionMode: selectionMode,
            isSelected: isSelected(clip.clipId),
            onSelectedChanged: selectionChangedHandler(clip.clipId),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- 单条动作

  void _openClipActions(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    final onOpenMovie = movieNumber != null && movieNumber.isNotEmpty
        ? () => _openMovie(movieNumber)
        : null;
    if (_mobile) {
      showClipActionsSheet(
        context,
        clip: clip,
        onPlay: () => _playClip(clip),
        onAddToCollection: () => _addToCollection(clip),
        onRename: () => _renameClip(clip),
        onDelete: () => _deleteClip(clip),
        onOpenMovie: onOpenMovie,
      );
      return;
    }
    showClipActionsDialog(
      context,
      clip: clip,
      onPlay: () => _playClip(clip),
      onAddToCollection: () => _addToCollection(clip),
      onRename: () => _renameClip(clip),
      onDelete: () => _deleteClip(clip),
      onOpenMovie: onOpenMovie,
    );
  }

  void _playClip(MediaClipDto clip) {
    unawaited(
      launchClipPlayback(context, streamUrl: clip.streamUrl, title: clip.title),
    );
  }

  void _openMovie(String movieNumber) {
    if (_mobile) {
      MobileRoutes.movieDetail(movieNumber: movieNumber).push(context);
      return;
    }
    DesktopRoutes.movieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopClipsPath,
    ).push(context);
  }

  Future<void> _renameClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final newTitle = await showRenameClipDialog(
      context,
      initialTitle: clip.title,
      presentation: _mobile
          ? RenameClipDialogPresentation.bottomDrawer
          : RenameClipDialogPresentation.dialog,
    );
    if (!mounted || newTitle == null) {
      return;
    }
    try {
      final updated = await ref
          .read(clipsApiProvider)
          .updateClipTitle(clipId: clip.clipId, title: newTitle);
      ref.read(clipsOverviewProvider.notifier).replaceClip(updated);
      if (mounted) {
        showToast(l10n.clipRenamed, tone: AppToastTone.success);
      }
    } catch (error) {
      showToast(
        apiErrorMessage(error, fallback: l10n.clipRenameFailed, l10n: l10n),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _deleteClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final trimmedTitle = clip.title.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.clipDeleteTitle,
      message: trimmedTitle.isEmpty
          ? l10n.clipDeleteUnnamedMessage
          : l10n.clipDeleteMessage(trimmedTitle),
      danger: true,
      confirmLabel: l10n.commonDelete,
      dialogKey: _mobile ? const Key('mobile-clip-delete-drawer') : null,
      confirmKey: Key('$_clipKeyPrefix-delete-confirm-button'),
      onConfirm: () =>
          ref.read(clipsApiProvider).deleteClip(clipId: clip.clipId),
      failureFallback: l10n.clipDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    // 广播删除信号：本页监听后从网格精准移除，并刷新合集横滑区（封面 / 计数可能变化）。
    ref.read(clipMutationEventsProvider.notifier).reportDeleted(clip.clipId);
    showToast(
      AppLocalizations.of(context).clipDeleted,
      tone: AppToastTone.success,
    );
  }

  Future<void> _addToCollection(MediaClipDto clip) async {
    await showAddToClipCollectionDialog(
      context,
      clipId: clip.clipId,
      presentation: _mobile
          ? AddToClipCollectionPresentation.bottomDrawer
          : AddToClipCollectionPresentation.dialog,
    );
    if (!mounted) {
      return;
    }
    // 合集归属可能变化（含新建）：广播信号，由本页监听统一刷新合集横滑区。
    ref
        .read(clipMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(clipId: clip.clipId);
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation: _mobile
          ? ClipCollectionEditPresentation.bottomDrawer
          : ClipCollectionEditPresentation.dialog,
    );
    if (!mounted || created == null) {
      return;
    }
    ref
        .read(clipCollectionsOverviewProvider.notifier)
        .insertCollection(created);
    showToast(
      AppLocalizations.of(context).clipCollectionCreated,
      tone: AppToastTone.success,
    );
  }

  Future<void> _viewAllCollections() async {
    if (_mobile) {
      MobileRoutes.clipCollections().push(context);
      return;
    }
    await DesktopRoutes.clipCollections().push<void>(context);
    if (!mounted) {
      return;
    }
    // 全部合集页内可能重命名/删除合集，返回后刷新首页合集横滑区。
    await ref.read(clipCollectionsOverviewProvider.notifier).refresh();
  }

  void _openCollection(BuildContext context, int collectionId) {
    if (_mobile) {
      MobileRoutes.clipCollectionDetail(
        collectionId: collectionId,
      ).push(context);
      return;
    }
    DesktopRoutes.clipCollectionDetail(
      collectionId: collectionId,
    ).push(context);
  }

  // ----------------------------------------------------------- 批量动作

  List<MediaClipDto> _selectedClips() {
    final clips =
        ref.read(clipsOverviewProvider).value?.paged.items ??
        const <MediaClipDto>[];
    return clips
        .where((clip) => isSelected(clip.clipId))
        .toList(growable: false);
  }

  Future<void> _batchAddToCollection() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickClipCollectionDialog(
      context,
      presentation: _mobile
          ? PickClipCollectionPresentation.bottomDrawer
          : PickClipCollectionPresentation.dialog,
    );
    if (!mounted || target == null) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.clipCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((clip) => clip.clipId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchDelete() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppLocalizations.of(context).clipDeleteTitle,
      message: AppLocalizations.of(
        context,
      ).clipBatchDeleteMessage(selected.length),
      danger: true,
      confirmLabel: AppLocalizations.of(context).commonDelete,
      dialogKey: _mobile ? const Key('mobile-clips-batch-delete-drawer') : null,
      confirmKey: Key('$_pageKeyPrefix-batch-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.clipDelete,
      ids: selected.map((clip) => clip.clipId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }
}
