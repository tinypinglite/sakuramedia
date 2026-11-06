import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
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
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/rename_clip_dialog.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_actions_panel.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';

/// 概览页「切片」tab：上方「切片合集」横滑区 + 下方「全部切片」网格。
///
/// 数据层与桌面 `DesktopClipsPage` 完全一致（复用同一组 provider 与 mutation
/// 广播），仅在布局上改为移动端竖屏网格 + 底部抽屉形态的编辑交互；长按切片卡进入
/// 多选模式，支持批量加入合集 / 删除（与移动 PornBox 对齐）。
class MobileOverviewClipsTab extends ConsumerStatefulWidget {
  const MobileOverviewClipsTab({super.key});

  @override
  ConsumerState<MobileOverviewClipsTab> createState() =>
      _MobileOverviewClipsTabState();
}

class _MobileOverviewClipsTabState extends ConsumerState<MobileOverviewClipsTab>
    with MultiSelectStateMixin<MobileOverviewClipsTab, int> {
  final ScrollController _scrollController = ScrollController();
  final _listHeaderKey = GlobalKey();
  bool _railRefreshScheduled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 删除 / 合集成员变化都可能改变合集横滑区的封面与计数；用微任务合并一轮内多次
  /// 信号成一次刷新。切片本身被删除时再从「全部切片」网格精准移除。
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

  List<MediaClipDto> _selectedClips() {
    final clips =
        ref.read(clipsOverviewProvider).value?.paged.items ??
        const <MediaClipDto>[];
    return clips.where((c) => isSelected(c.clipId)).toList(growable: false);
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
    final clips = clipsView.items;
    // 概览 TabBarView 保活当前 Tab，但不会关闭 TickerMode；隐藏时只看
    // enabled 阻止自动补页，避免用离开时的旧滚动位置在后台继续翻页。
    final isActive = ref.watch(mobileOverviewTabIndexProvider) == 1;

    return Column(
      children: [
        Expanded(
          child: AppFilterResultLoadingOverlay(
            surfaceColor: context.appColors.surfaceCard,
            protectedHeaderKey: _listHeaderKey,
            scrollController: _scrollController,
            isLoading: clipsView.filterUpdate.isLoading,
            hasPreviousItems: clips.isNotEmpty,
            child: AppPagedLoadMoreScope(
              enabled: isActive,
              canLoadMore: () =>
                  ref
                      .read(clipsOverviewProvider)
                      .value
                      ?.paged
                      .canAutoLoadMore ??
                  false,
              onLoadMore: () =>
                  ref.read(clipsOverviewProvider.notifier).loadMore(),
              child: AppAdaptiveRefreshScrollView(
                key: const Key('mobile-clips-tab-scroll'),
                controller: _scrollController,
                onRefresh: _refresh,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _buildCollectionsSection(context, collectionsAsync),
                  ),
                  AppPinnedListHeader(
                    key: _listHeaderKey,
                    color: context.appColors.surfaceCard,
                    child: _buildClipsHeader(context, clips),
                  ),
                  _buildClipsSliver(context, clipsView),
                  // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
                  // 隐藏时保留 lg 底部边距（原语义）。
                  PagedLoadMoreFooterSliver(
                    hiddenSpacing: PagedFooterSpacing.lg,
                    watchFooter: (ref) => ref.watch(
                      clipsOverviewProvider.select(
                        (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
                      ),
                    ),
                    onLoadMore: (ref) => unawaited(
                      ref.read(clipsOverviewProvider.notifier).loadMore(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selectionMode) _buildBatchBar(context),
      ],
    );
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
        SizedBox(height: spacing.sm),
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
              key: const Key('mobile-clips-create-collection-button'),
              label: l10n.clipCollectionCreate,
              size: AppTextButtonSize.small,
              onPressed: _createCollection,
            ),
            if (collections.isNotEmpty) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: const Key('mobile-clips-view-all-collections-button'),
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
    final spacing = context.appSpacing;
    if (collectionsAsync.hasError && collections.isEmpty) {
      return CollectionHintBox(
        message: apiErrorMessage(
          collectionsAsync.error!,
          fallback: l10n.clipCollectionsLoadFailedFallback,
          l10n: l10n,
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
    return AppSkeletonizer(
      enabled: isLoading,
      child: SizedBox(
        height: 148,
        child: ListView.separated(
          key: const Key('mobile-clips-collections-row'),
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          separatorBuilder: (context, index) => SizedBox(width: spacing.sm),
          itemBuilder: (context, index) {
            final collection = display[index];
            return SizedBox(
              width: 168,
              // 卡片按内容自然高度渲染，避免被固定行高拉伸后在标题下方留白。
              child: Align(
                alignment: Alignment.topCenter,
                child: CollectionCard.clip(
                  key: Key('mobile-clip-collection-card-${collection.id}'),
                  collection: collection,
                  onTap: () => MobileClipCollectionDetailRouteData(
                    collectionId: collection.id,
                  ).push(context),
                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 与「时刻」页同构：选择态原地改写操作行，两态等高不跳版。
        if (selectionMode)
          _buildSelectionHeader(context, clips)
        else
          AppListHeader(
            filterUpdate: summary.filterUpdate,
            hasPreviousFilterItems: hasClips,
            onRetryFilter: () => unawaited(
              ref.read(clipsOverviewProvider.notifier).retryFilter(),
            ),
            actionSlots: [
              _buildSortAction(
                context,
                actionKey: const Key('mobile-clips-sort-latest'),
                label: l10n.clipSortLatest,
                sort: 'created_at:desc',
                currentSort: currentSort,
              ),
              _buildSortAction(
                context,
                actionKey: const Key('mobile-clips-sort-earliest'),
                label: l10n.clipSortEarliest,
                sort: 'created_at:asc',
                currentSort: currentSort,
              ),
              if (hasClips)
                AppTextButton(
                  key: const Key('mobile-clips-enter-selection-button'),
                  label: l10n.clipEnterSelection,
                  size: AppTextButtonSize.xSmall,
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  onPressed: enterSelection,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSortAction(
    BuildContext context, {
    required Key actionKey,
    required String label,
    required String sort,
    required String currentSort,
  }) {
    return AppTextButton(
      key: actionKey,
      label: label,
      size: AppTextButtonSize.xSmall,
      isSelected: currentSort == sort,
      selectedStyle: AppTextButtonSelectedStyle.plain,
      onPressed: () => _applySort(sort),
    );
  }

  void _applySort(String sort) {
    final current = ref.read(clipsOverviewProvider).value?.filter.sort;
    if (current == sort) return;
    if (_scrollController.hasClients) {
      AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
    }
    unawaited(ref.read(clipsOverviewProvider.notifier).applySort(sort));
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
        child: SizedBox(
          height: 200,
          child: AppEmptyState(
            message: apiErrorMessage(
              error,
              fallback: l10n.errorClipLoadFailed,
              l10n: l10n,
            ),
          ),
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
    final display = isLoading ? clipPlaceholders(count: 6) : clips;
    return AppSkeletonizer.sliver(
      enabled: isLoading,
      child: AppAdaptiveCardSliver<MediaClipDto>(
        gridKey: const Key('mobile-clips-grid'),
        items: display,
        childAspectRatio: 16 / 9,
        itemBuilder: (context, clip, index) {
          return ClipCoverCard(
            key: Key('mobile-clip-grid-card-${clip.clipId}'),
            clip: clip,
            onTap: () => _openClipSheet(clip),
            selectionMode: selectionMode,
            isSelected: isSelected(clip.clipId),
            onSelectedChanged: (_) => toggleSelect(clip.clipId),
            onLongPress: selectionMode
                ? null
                : () {
                    enterSelection();
                    toggleSelect(clip.clipId);
                  },
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- 选择栏

  /// 选择模式下的顶栏：退出 / 计数 / 全选。批量动作下沉到贴底的
  /// [AppSelectionBottomBar]；与 [AppListHeader] 等高，原地替换不跳版。
  Widget _buildSelectionHeader(BuildContext context, List<MediaClipDto> clips) {
    final l10n = AppLocalizations.of(context);
    final clipIds = clips.map((c) => c.clipId);
    final allSelected = isAllSelected(clipIds);
    return AppListHeader.selection(
      selectionLabel: l10n.clipSelectionCount(selectedCount),
      selectionExitButtonKey: const Key('mobile-clips-exit-selection-button'),
      onExitSelection: exitSelection,
      actionSlots: [
        AppButton(
          key: const Key('mobile-clips-select-all-button'),
          label: allSelected ? l10n.clipDeselectAll : l10n.clipSelectAll,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.xSmall,
          isSelected: allSelected,
          onPressed: () => toggleSelectAll(clipIds),
        ),
      ],
    );
  }

  Widget _buildBatchBar(BuildContext context) {
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
          onPressed: hasSelection && !submitting ? _batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('mobile-clips-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          onPressed: hasSelection && !submitting ? _batchDelete : null,
        ),
      ],
    );
  }

  // ----------------------------------------------------------- 单条动作

  void _openClipSheet(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    showClipActionsSheet(
      context,
      clip: clip,
      onPlay: () => _playClip(clip),
      onAddToCollection: () => _addToCollection(clip),
      onRename: () => _renameClip(clip),
      onDelete: () => _deleteClip(clip),
      onOpenMovie: movieNumber != null && movieNumber.isNotEmpty
          ? () => _openMovie(movieNumber)
          : null,
    );
  }

  Future<void> _playClip(MediaClipDto clip) {
    return launchClipPlayback(
      context,
      streamUrl: clip.streamUrl,
      title: clip.title,
    );
  }

  void _openMovie(String movieNumber) {
    MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
  }

  Future<void> _renameClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final newTitle = await showRenameClipDialog(
      context,
      initialTitle: clip.title,
      presentation: RenameClipDialogPresentation.bottomDrawer,
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
      confirmLabel: l10n.commonDelete,
      danger: true,
      dialogKey: const Key('mobile-clip-delete-drawer'),
      confirmKey: const Key('mobile-clip-delete-confirm-button'),
      onConfirm: () =>
          ref.read(clipsApiProvider).deleteClip(clipId: clip.clipId),
      failureFallback: l10n.clipDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
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
      presentation: AddToClipCollectionPresentation.bottomDrawer,
    );
    if (!mounted) {
      return;
    }
    ref
        .read(clipMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(clipId: clip.clipId);
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation: ClipCollectionEditPresentation.bottomDrawer,
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

  void _viewAllCollections() {
    MobileClipCollectionsRouteData().push(context);
  }

  // ----------------------------------------------------------- 批量动作

  Future<void> _batchAddToCollection() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickClipCollectionDialog(
      context,
      presentation: PickClipCollectionPresentation.bottomDrawer,
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
      dialogKey: const Key('mobile-clips-batch-delete-drawer'),
      confirmKey: const Key('mobile-clips-batch-delete-confirm-button'),
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
