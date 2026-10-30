import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
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
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_actions_panel.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';

/// 切片首页：上方「切片合集」横滑区 + 下方「全部切片」网格（悬停预览、加入合集）。
///
/// 切片区表头右侧的「选择」入口进入多选模式后，网格切换为多选交互；选择栏支持
/// 「加入合集 / 删除」两个批量动作，逻辑对齐 PornBox 桌面页。
class DesktopClipsPage extends ConsumerStatefulWidget {
  const DesktopClipsPage({super.key});

  @override
  ConsumerState<DesktopClipsPage> createState() => _DesktopClipsPageState();
}

class _DesktopClipsPageState extends ConsumerState<DesktopClipsPage>
    with MultiSelectStateMixin<DesktopClipsPage, int> {
  final ScrollController _scrollController = ScrollController();
  final _listHeaderKey = GlobalKey();
  bool _railRefreshScheduled = false;

  @override
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

  Future<void> _handleRefresh() async {
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
    final clips = clipsView.items;

    return AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            if (clipsView.initialError case final error?) {
              return AppEmptyState(
                message: apiErrorMessage(
                  error,
                  fallback: l10n.errorClipLoadFailed,
                  l10n: l10n,
                ),
              );
            }
            return AppFilterResultLoadingOverlay(
              protectedHeaderKey: _listHeaderKey,
              scrollController: _scrollController,
              isLoading: clipsView.filterUpdate.isLoading,
              hasPreviousItems: clips.isNotEmpty,
              child: AppPagedLoadMoreScope(
                canLoadMore: () =>
                    ref
                        .read(clipsOverviewProvider)
                        .value
                        ?.paged
                        .canAutoLoadMore ??
                    false,
                onLoadMore: () =>
                    ref.read(clipsOverviewProvider.notifier).loadMore(),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _buildCollectionsSection(
                        context,
                        collectionsAsync,
                      ),
                    ),
                    AppPinnedListHeader(
                      key: _listHeaderKey,
                      color: context.appColors.surfaceElevated,
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
            );
          },
        ),
      ),
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
              key: const Key('clips-create-collection-button'),
              label: l10n.clipCollectionCreate,
              size: AppTextButtonSize.small,
              onPressed: _createCollection,
            ),
            if (collections.isNotEmpty) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: const Key('clips-view-all-collections-button'),
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
    final spacing = context.appSpacing;
    return AppSkeletonizer(
      enabled: isLoading,
      child: SizedBox(
        height: 172,
        child: ListView.separated(
          key: const Key('clips-collections-row'),
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          separatorBuilder: (context, index) => SizedBox(width: spacing.md),
          itemBuilder: (context, index) {
            final collection = display[index];
            return SizedBox(
              width: 210,
              // 卡片按内容自然高度渲染，避免被固定行高拉伸后在标题下方留白。
              child: Align(
                alignment: Alignment.topCenter,
                child: CollectionCard.clip(
                  key: Key('clip-collection-card-${collection.id}'),
                  collection: collection,
                  onTap: () => context.pushDesktopClipCollectionDetail(
                    collectionId: collection.id,
                  ),
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
    // 顶栏只订阅排序与筛选更新态：翻页 loading/失败不重建顶栏。
    final headerView = ref.watch(
      clipsOverviewProvider.select(
        (asyncState) => (
          sort: asyncState.value?.filter.sort ?? ClipsFilter.defaultSort,
          filterUpdate:
              asyncState.value?.paged.filterUpdate ??
              const FilterUpdateState.idle(),
        ),
      ),
    );
    final currentSort = headerView.sort;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 与「时刻」页同构：选择态原地改写操作行，两态等高不跳版。
        if (selectionMode)
          _buildSelectionHeader(context, clips)
        else
          AppListHeader(
            filterUpdate: headerView.filterUpdate,
            hasPreviousFilterItems: hasClips,
            onRetryFilter: () => unawaited(
              ref.read(clipsOverviewProvider.notifier).retryFilter(),
            ),
            actionSlots: [
              _buildSortAction(
                context,
                actionKey: const Key('clips-sort-latest'),
                label: l10n.clipSortLatest,
                sort: 'created_at:desc',
                currentSort: currentSort,
              ),
              _buildSortAction(
                context,
                actionKey: const Key('clips-sort-earliest'),
                label: l10n.clipSortEarliest,
                sort: 'created_at:asc',
                currentSort: currentSort,
              ),
              if (hasClips)
                AppSelectionEntryButton(
                  key: const Key('clips-enter-selection-button'),
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

  /// 选择模式下的批量操作栏：已选数 / 全选 / 加入合集 / 删除 / 取消。
  /// 原地替换常规操作行（[AppSelectionHeaderToolbar] 与 [AppListHeader] 等高）。
  Widget _buildSelectionHeader(BuildContext context, List<MediaClipDto> clips) {
    final l10n = AppLocalizations.of(context);
    final clipIds = clips.map((c) => c.clipId);
    final allSelected = isAllSelected(clipIds);
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.clipCollectionAdd,
      BatchOperationType.clipDelete,
    ]);
    return AppSelectionHeaderToolbar(
      countLabel: l10n.clipSelectionCount(selectedCount),
      selectAllLabel: allSelected ? l10n.clipDeselectAll : l10n.clipSelectAll,
      selectAllKey: const Key('clips-select-all-button'),
      onToggleAll: () => toggleSelectAll(clipIds),
      actions: [
        AppButton(
          key: const Key('clips-batch-add-collection-button'),
          label: l10n.clipAddToCollection,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting ? _batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('clips-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting ? _batchDelete : null,
        ),
      ],
      exitKey: const Key('clips-exit-selection-button'),
      onExit: exitSelection,
    );
  }

  Widget _buildClipsSliver(
    BuildContext context,
    PagedViewSnapshot<MediaClipDto> view,
  ) {
    final clips = view.items;
    final isInitialLoading = view.isInitialLoading;
    if (!isInitialLoading && clips.isEmpty && view.filterUpdate.hasFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (!isInitialLoading && clips.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: AppLocalizations.of(context).clipEmpty),
        ),
      );
    }
    // loading 用占位切片渲染同一份真实网格，由 [AppSkeletonizer] 灰化。
    final display = isInitialLoading ? clipPlaceholders(count: 8) : clips;
    return AppSkeletonizer.sliver(
      enabled: isInitialLoading,
      child: AppAdaptiveCardSliver<MediaClipDto>(
        gridKey: const Key('clips-grid'),
        items: display,
        childAspectRatio: 16 / 9,
        itemBuilder: (context, clip, index) {
          final movieNumber = clip.movieNumber;
          return ClipGridCard(
            key: Key('clip-grid-card-${clip.clipId}'),
            clip: clip,
            tapKey: Key('clip-grid-card-tap-${clip.clipId}'),
            onTap: () => _openClipActions(clip),
            onPlay: () => _playClip(clip),
            onRename: () => _renameClip(clip),
            onDelete: () => _deleteClip(clip),
            onAddToCollection: () => _addToCollection(clip),
            onOpenMovie: movieNumber != null && movieNumber.isNotEmpty
                ? () => _openMovie(movieNumber)
                : null,
            selectionMode: selectionMode,
            isSelected: isSelected(clip.clipId),
            onSelectedChanged: (_) => toggleSelect(clip.clipId),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- 单条动作

  /// 点击切片卡弹动作弹窗（对齐切片合集成员卡），由用户再选择播放 / 影片 /
  /// 加入合集 / 重命名 / 删除，避免误触即播放。
  void _openClipActions(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    showClipActionsDialog(
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

  void _playClip(MediaClipDto clip) {
    unawaited(
      launchClipPlayback(context, streamUrl: clip.streamUrl, title: clip.title),
    );
  }

  void _openMovie(String movieNumber) {
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopClipsPath,
    );
  }

  Future<void> _renameClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final newTitle = await showRenameClipDialog(
      context,
      initialTitle: clip.title,
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
        showToast(l10n.clipRenamed);
      }
    } catch (error) {
      showToast(
        apiErrorMessage(error, fallback: l10n.clipRenameFailed, l10n: l10n),
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
      confirmKey: const Key('clip-delete-confirm-button'),
      onConfirm: () =>
          ref.read(clipsApiProvider).deleteClip(clipId: clip.clipId),
      failureFallback: l10n.clipDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    // 广播删除信号：本页监听后从网格精准移除，并刷新合集横滑区（封面 / 计数可能变化）。
    ref.read(clipMutationEventsProvider.notifier).reportDeleted(clip.clipId);
    showToast(AppLocalizations.of(context).clipDeleted);
  }

  Future<void> _addToCollection(MediaClipDto clip) async {
    await showAddToClipCollectionDialog(context, clipId: clip.clipId);
    if (!mounted) {
      return;
    }
    // 合集归属可能变化（含新建）：广播信号，由本页监听统一刷新合集横滑区。
    ref
        .read(clipMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(clipId: clip.clipId);
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(context);
    if (!mounted || created == null) {
      return;
    }
    ref
        .read(clipCollectionsOverviewProvider.notifier)
        .insertCollection(created);
    showToast(AppLocalizations.of(context).clipCollectionCreated);
  }

  Future<void> _viewAllCollections() async {
    await context.pushDesktopClipCollections();
    if (!mounted) {
      return;
    }
    // 全部合集页内可能重命名/删除合集，返回后刷新首页合集横滑区。
    await ref.read(clipCollectionsOverviewProvider.notifier).refresh();
  }

  // ----------------------------------------------------------- 批量动作

  List<MediaClipDto> _selectedClips() {
    final clips =
        ref.read(clipsOverviewProvider).value?.paged.items ??
        const <MediaClipDto>[];
    return clips.where((c) => isSelected(c.clipId)).toList(growable: false);
  }

  Future<void> _batchAddToCollection() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickClipCollectionDialog(context);
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
      confirmKey: const Key('clips-batch-delete-confirm-button'),
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
