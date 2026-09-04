import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_to_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/pick_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_actions_sheet.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_confirm_drawer.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_player_page.dart';
import 'package:sakuramedia/features/clips/presentation/actions/clip_playback_launcher.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_filter.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/rename_clip_dialog.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 概览页「切片」tab：上方「我的合集」横滑区 + 下方「全部切片」网格。
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
  bool _railRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) {
      return;
    }
    final paged = ref.read(clipsOverviewProvider).value?.paged;
    if (paged != null && paged.loadMoreErrorMessage == null) {
      unawaited(ref.read(clipsOverviewProvider.notifier).loadMore());
    }
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

    final clipsAsync = ref.watch(clipsOverviewProvider);
    final collectionsAsync = ref.watch(clipCollectionsOverviewProvider);
    final clipsState = clipsAsync.value;
    final clips = clipsState?.paged.items ?? const <MediaClipDto>[];

    return Column(
      children: [
        if (selectionMode) _buildSelectionBar(context, clips),
        Expanded(
          child: AppFilterResultLoadingOverlay(
            isLoading: clipsState?.paged.filterUpdate.isLoading ?? false,
            hasPreviousItems: clips.isNotEmpty,
            child: AppAdaptiveRefreshScrollView(
              key: const Key('mobile-clips-tab-scroll'),
              controller: _scrollController,
              onRefresh: _refresh,
              slivers: <Widget>[
                // 选择模式下隐藏合集横滑区，只剩切片网格，与移动 PornBox 一致。
                if (!selectionMode)
                  SliverToBoxAdapter(
                    child: _buildCollectionsSection(context, collectionsAsync),
                  ),
                SliverToBoxAdapter(child: _buildClipsHeader(context, clips)),
                _buildClipsSliver(context, clipsAsync, clips),
                SliverToBoxAdapter(
                  child: _buildFooter(context, clipsState?.paged),
                ),
              ],
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
    final spacing = context.appSpacing;
    final collections = collectionsAsync.value ?? const <ClipCollectionDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: spacing.sm),
        Row(
          children: [
            Text(
              '我的合集',
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
              label: '新建',
              size: AppTextButtonSize.small,
              onPressed: _createCollection,
            ),
            if (collections.isNotEmpty) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: const Key('mobile-clips-view-all-collections-button'),
                label: '查看全部',
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
    final spacing = context.appSpacing;
    if (collectionsAsync.hasError && collections.isEmpty) {
      return _HintBox(
        message: apiErrorMessage(
          collectionsAsync.error!,
          fallback: '合集暂时无法加载，请稍后重试',
        ),
      );
    }
    if (collectionsAsync.isLoading && collections.isEmpty) {
      return CollectionCardSkeletonRow(
        key: const Key('mobile-clips-collections-skeleton-row'),
        height: 148,
        itemWidth: 168,
        itemSpacing: spacing.sm,
      );
    }
    if (collections.isEmpty) {
      return const _HintBox(message: '还没有合集，点「新建」把喜欢的切片攒成一个连播合集吧');
    }
    return SizedBox(
      height: 148,
      child: ListView.separated(
        key: const Key('mobile-clips-collections-row'),
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (context, index) => SizedBox(width: spacing.sm),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: 168,
            child: CollectionCard.clip(
              key: Key('mobile-clip-collection-card-${collection.id}'),
              collection: collection,
              onTap: () => MobileClipCollectionDetailRouteData(
                collectionId: collection.id,
              ).push(context),
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- 切片区

  Widget _buildClipsHeader(BuildContext context, List<MediaClipDto> clips) {
    final spacing = context.appSpacing;
    final hasClips = clips.isNotEmpty;
    final summary = ref.watch(clipsOverviewProvider).value;
    final currentSort = summary?.filter.sort ?? ClipsFilter.defaultSort;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '全部切片',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              const Spacer(),
              _buildSortAction(
                context,
                actionKey: const Key('mobile-clips-sort-latest'),
                label: '最新',
                sort: 'created_at:desc',
                currentSort: currentSort,
              ),
              SizedBox(width: spacing.sm),
              _buildSortAction(
                context,
                actionKey: const Key('mobile-clips-sort-earliest'),
                label: '最早',
                sort: 'created_at:asc',
                currentSort: currentSort,
              ),
              if (!selectionMode && hasClips) ...[
                SizedBox(width: spacing.sm),
                AppTextButton(
                  key: const Key('mobile-clips-enter-selection-button'),
                  label: '选择',
                  size: AppTextButtonSize.xSmall,
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  onPressed: enterSelection,
                ),
              ],
            ],
          ),
          AppFilterUpdateBar(
            state:
                summary?.paged.filterUpdate ?? const FilterUpdateState.idle(),
            hasPreviousItems: clips.isNotEmpty,
            onRetry: () => unawaited(
              ref.read(clipsOverviewProvider.notifier).retryFilter(),
            ),
          ),
        ],
      ),
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
      onPressed: () => _applySort(sort),
    );
  }

  void _applySort(String sort) {
    final current = ref.read(clipsOverviewProvider).value?.filter.sort;
    if (current == sort) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(ref.read(clipsOverviewProvider.notifier).applySort(sort));
  }

  Widget _buildClipsSliver(
    BuildContext context,
    AsyncValue<Object?> clipsAsync,
    List<MediaClipDto> clips,
  ) {
    final filterUpdate = ref
        .read(clipsOverviewProvider)
        .value
        ?.paged
        .filterUpdate;
    if (clips.isEmpty && (filterUpdate?.hasFailed ?? false)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (clipsAsync.isLoading && clips.isEmpty) {
      final spacing = context.appSpacing;
      return SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = _resolveColumnCount(
            constraints.crossAxisExtent,
            spacing.md,
          );
          return SliverGrid(
            key: const Key('mobile-clips-grid-skeleton'),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing.md,
              crossAxisSpacing: spacing.md,
              childAspectRatio: 16 / 9,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => AppCoverCardSkeleton(
                key: Key('mobile-clips-grid-skeleton-$index'),
                aspectRatio: 16 / 9,
              ),
              childCount: 6,
            ),
          );
        },
      );
    }
    if (clipsAsync.hasError && clips.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(
            message: apiErrorMessage(
              clipsAsync.error!,
              fallback: '切片暂时无法加载，请稍后重试',
            ),
          ),
        ),
      );
    }
    if (clips.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: '还没有切片，去播放器圈选生成吧'),
        ),
      );
    }
    final spacing = context.appSpacing;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = _resolveColumnCount(
          constraints.crossAxisExtent,
          spacing.md,
        );
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 9,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final clip = clips[index];
            return GestureDetector(
              onLongPress: selectionMode
                  ? null
                  : () {
                      enterSelection();
                      toggleSelect(clip.clipId);
                    },
              child: ClipCoverCard(
                key: Key('mobile-clip-grid-card-${clip.clipId}'),
                clip: clip,
                onTap: () => _openClipSheet(clip),
                selectionMode: selectionMode,
                isSelected: isSelected(clip.clipId),
                onSelectedChanged: (_) => toggleSelect(clip.clipId),
              ),
            );
          }, childCount: clips.length),
        );
      },
    );
  }

  int _resolveColumnCount(double width, double spacing) {
    final columns = ((width + spacing) / (280 + spacing)).floor();
    return math.max(2, math.min(4, columns));
  }

  Widget _buildFooter(
    BuildContext context,
    PagedListState<MediaClipDto>? paged,
  ) {
    if (paged?.loadMoreErrorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
        child: Center(
          child: AppButton(
            key: const Key('mobile-clips-load-more-retry'),
            label: '加载更多失败，点击重试',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () =>
                unawaited(ref.read(clipsOverviewProvider.notifier).loadMore()),
          ),
        ),
      );
    }
    if (paged?.isLoadingMore ?? false) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return SizedBox(height: context.appSpacing.lg);
  }

  // ----------------------------------------------------------- 选择栏

  Widget _buildSelectionBar(BuildContext context, List<MediaClipDto> clips) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final clipIds = clips.map((c) => c.clipId);
    final allSelected = isAllSelected(clipIds);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          AppTextButton(
            key: const Key('mobile-clips-exit-selection-button'),
            label: '取消',
            size: AppTextButtonSize.small,
            onPressed: exitSelection,
          ),
          SizedBox(width: spacing.sm),
          Text(
            '已选 $selectedCount 个',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
          const Spacer(),
          AppTextButton(
            key: const Key('mobile-clips-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            size: AppTextButtonSize.small,
            onPressed: () => toggleSelectAll(clipIds),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchBar(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final hasSelection = selectedCount > 0;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('mobile-clips-batch-add-collection-button'),
                label: '加入合集',
                variant: AppButtonVariant.secondary,
                onPressed: hasSelection ? _batchAddToCollection : null,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('mobile-clips-batch-delete-button'),
                label: '删除',
                variant: AppButtonVariant.danger,
                onPressed: hasSelection ? _batchDelete : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- 单条动作

  void _openClipSheet(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    showMobileClipActionsSheet(
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

  Future<void> _playClip(MediaClipDto clip) async {
    if (await tryLaunchExternalClipPlayback(
      context,
      streamUrl: clip.streamUrl,
      title: clip.title,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    // 用根 Navigator 推全屏页，覆盖底部导航；切片很短，直接传 streamUrl 即可，
    // 无需经 go_router 把签名地址放进 URL。
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MobileClipPlayerPage(streamUrl: clip.streamUrl, title: clip.title),
      ),
    );
  }

  void _openMovie(String movieNumber) {
    MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
  }

  Future<void> _renameClip(MediaClipDto clip) async {
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
        showToast('已重命名');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '重命名失败，请重试'));
    }
  }

  Future<void> _deleteClip(MediaClipDto clip) async {
    final title = clip.title.trim().isEmpty ? '该切片' : '“${clip.title.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除切片',
      message: '确认删除$title？切片文件会被一并删除，该操作不可恢复。',
      confirmLabel: '删除',
      danger: true,
      dialogKey: const Key('mobile-clip-delete-drawer'),
      confirmKey: const Key('mobile-clip-delete-confirm-button'),
      onConfirm: () =>
          ref.read(clipsApiProvider).deleteClip(clipId: clip.clipId),
      failureFallback: '删除失败，请重试',
    );
    if (!mounted || !confirmed) {
      return;
    }
    ref.read(clipMutationEventsProvider.notifier).reportDeleted(clip.clipId);
    showToast('已删除切片');
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
    showToast('已创建合集');
  }

  void _viewAllCollections() {
    MobileClipCollectionsRouteData().push(context);
  }

  // ----------------------------------------------------------- 批量动作

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个切片');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

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
    final api = ref.read(clipCollectionsApiProvider);
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (clip) =>
          api.addClipToCollection(collectionId: target.id, clipId: clip.clipId),
    );
    if (!mounted) {
      return;
    }
    final broadcaster = ref.read(clipMutationEventsProvider.notifier);
    for (final clip in result.succeeded) {
      broadcaster.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: target.id,
      );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _batchDelete() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除切片',
      message: '确认删除选中的 ${selected.length} 个切片？切片文件会被一并删除，该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-clips-batch-delete-drawer'),
      confirmButtonKey: const Key('mobile-clips-batch-delete-confirm-button'),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final api = ref.read(clipsApiProvider);
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在删除切片',
      items: selected,
      action: (clip) => api.deleteClip(clipId: clip.clipId),
    );
    if (!mounted) {
      return;
    }
    final broadcaster = ref.read(clipMutationEventsProvider.notifier);
    for (final clip in result.succeeded) {
      broadcaster.reportDeleted(clip.clipId);
    }
    _showBatchToast('删除', result);
    exitSelection();
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Text(
        message,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}
