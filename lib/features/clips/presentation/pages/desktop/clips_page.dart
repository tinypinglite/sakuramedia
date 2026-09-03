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
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_filter.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/rename_clip_dialog.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_player_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 切片首页：上方「我的合集」横滑区 + 下方「全部切片」网格（悬停预览、加入合集）。
///
/// 「全部切片」表头右侧的「选择」入口进入多选模式后，网格切换为多选交互；选择栏支持
/// 「加入合集 / 删除」两个批量动作，逻辑对齐 PornBox 桌面页。
class DesktopClipsPage extends ConsumerStatefulWidget {
  const DesktopClipsPage({super.key});

  @override
  ConsumerState<DesktopClipsPage> createState() => _DesktopClipsPageState();
}

class _DesktopClipsPageState extends ConsumerState<DesktopClipsPage>
    with MultiSelectStateMixin<DesktopClipsPage, int> {
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

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) {
      return;
    }
    // 对齐旧基类：loadMore 失败存续期间滚动不自动重试。
    final paged = ref.read(clipsOverviewProvider).value?.paged;
    if (paged != null && paged.loadMoreErrorMessage == null) {
      unawaited(ref.read(clipsOverviewProvider.notifier).loadMore());
    }
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

    final clipsAsync = ref.watch(clipsOverviewProvider);
    final collectionsAsync = ref.watch(clipCollectionsOverviewProvider);
    final clipsState = clipsAsync.value;
    final clips = clipsState?.paged.items ?? const <MediaClipDto>[];

    return AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: Builder(
          builder: (context) {
            if (clipsAsync.hasError && clips.isEmpty) {
              return AppEmptyState(
                message: apiErrorMessage(
                  clipsAsync.error!,
                  fallback: '切片暂时无法加载，请稍后重试',
                ),
              );
            }
            return AppFilterResultLoadingOverlay(
              isLoading: clipsState?.paged.filterUpdate.isLoading ?? false,
              hasPreviousItems: clips.isNotEmpty,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _buildCollectionsSection(context, collectionsAsync),
                  ),
                  SliverToBoxAdapter(child: _buildClipsHeader(context, clips)),
                  _buildClipsSliver(
                    context,
                    clips,
                    isInitialLoading: clipsAsync.isLoading && clips.isEmpty,
                  ),
                  SliverToBoxAdapter(
                    child: _buildFooter(context, clipsState?.paged),
                  ),
                ],
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
    final spacing = context.appSpacing;
    final collections = collectionsAsync.value ?? const <ClipCollectionDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              key: const Key('clips-create-collection-button'),
              label: '新建',
              size: AppTextButtonSize.small,
              onPressed: _createCollection,
            ),
            if (collections.isNotEmpty) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: const Key('clips-view-all-collections-button'),
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
        key: const Key('clips-collections-skeleton-row'),
        height: 172,
        itemWidth: 210,
        itemSpacing: context.appSpacing.md,
      );
    }
    if (collections.isEmpty) {
      return const _HintBox(message: '还没有合集，点「新建」把喜欢的切片攒成一个连播合集吧');
    }
    final spacing = context.appSpacing;
    return SizedBox(
      height: 172,
      child: ListView.separated(
        key: const Key('clips-collections-row'),
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (context, index) => SizedBox(width: spacing.md),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: 210,
            child: CollectionCard.clip(
              key: Key('clip-collection-card-${collection.id}'),
              collection: collection,
              onTap: () => context.pushDesktopClipCollectionDetail(
                collectionId: collection.id,
              ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              // 与「时刻」页保持一致：最新/最早并排，选中高亮。
              _buildSortAction(
                context,
                actionKey: const Key('clips-sort-latest'),
                label: '最新',
                sort: 'created_at:desc',
                currentSort: currentSort,
              ),
              SizedBox(width: spacing.sm),
              _buildSortAction(
                context,
                actionKey: const Key('clips-sort-earliest'),
                label: '最早',
                sort: 'created_at:asc',
                currentSort: currentSort,
              ),
              if (!selectionMode && hasClips) ...[
                SizedBox(width: spacing.sm),
                AppTextButton(
                  key: const Key('clips-enter-selection-button'),
                  label: '选择',
                  size: AppTextButtonSize.small,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  onPressed: enterSelection,
                ),
              ],
            ],
          ),
          if (selectionMode) ...[
            SizedBox(height: spacing.sm),
            _buildSelectionBar(context, clips),
          ],
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

  /// 选择模式下的批量操作栏：已选数 / 全选 / 加入合集 / 删除 / 取消。
  Widget _buildSelectionBar(BuildContext context, List<MediaClipDto> clips) {
    final spacing = context.appSpacing;
    final clipIds = clips.map((c) => c.clipId);
    final allSelected = isAllSelected(clipIds);
    final hasSelection = selectedCount > 0;
    return Row(
      children: [
        Text(
          '已选 $selectedCount 个',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        const Spacer(),
        AppTextButton(
          key: const Key('clips-select-all-button'),
          label: allSelected ? '取消全选' : '全选',
          size: AppTextButtonSize.small,
          onPressed: () => toggleSelectAll(clipIds),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('clips-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchAddToCollection : null,
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('clips-batch-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchDelete : null,
        ),
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: const Key('clips-exit-selection-button'),
          label: '取消',
          size: AppTextButtonSize.small,
          onPressed: exitSelection,
        ),
      ],
    );
  }

  Widget _buildClipsSliver(
    BuildContext context,
    List<MediaClipDto> clips, {
    required bool isInitialLoading,
  }) {
    final filterUpdate = ref
        .read(clipsOverviewProvider)
        .value
        ?.paged
        .filterUpdate;
    if (isInitialLoading) {
      final spacing = context.appSpacing;
      return SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = _resolveColumnCount(
            constraints.crossAxisExtent,
            spacing.md,
          );
          return SliverGrid(
            key: const Key('clips-grid-skeleton'),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing.md,
              crossAxisSpacing: spacing.md,
              childAspectRatio: 16 / 9,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => AppCoverCardSkeleton(
                posterKey: Key('clips-grid-skeleton-$index'),
              ),
              childCount: 8,
            ),
          );
        },
      );
    }
    if (clips.isEmpty && (filterUpdate?.hasFailed ?? false)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
            final movieNumber = clip.movieNumber;
            return ClipGridCard(
              key: Key('clip-grid-card-${clip.clipId}'),
              clip: clip,
              tapKey: Key('clip-grid-card-tap-${clip.clipId}'),
              onTap: () => _playClip(clip),
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
            key: const Key('clips-load-more-retry'),
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

  // ----------------------------------------------------------- 单条动作

  void _playClip(MediaClipDto clip) {
    showClipPlayerDialog(context, streamUrl: clip.streamUrl, title: clip.title);
  }

  void _openMovie(String movieNumber) {
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopClipsPath,
    );
  }

  Future<void> _renameClip(MediaClipDto clip) async {
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
      danger: true,
      confirmLabel: '删除',
      confirmKey: const Key('clip-delete-confirm-button'),
      onConfirm: () =>
          ref.read(clipsApiProvider).deleteClip(clipId: clip.clipId),
      failureFallback: '删除失败，请重试',
    );
    if (!mounted || !confirmed) {
      return;
    }
    // 广播删除信号：本页监听后从网格精准移除，并刷新合集横滑区（封面 / 计数可能变化）。
    ref.read(clipMutationEventsProvider.notifier).reportDeleted(clip.clipId);
    showToast('已删除切片');
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
    showToast('已创建合集');
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
    final target = await showPickClipCollectionDialog(context);
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
    // 合集成员/封面变化：逐条广播，由页面监听合并刷新合集横滑区。
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除切片',
      message: '确认删除选中的 ${selected.length} 个切片？切片文件会被一并删除，该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      confirmKey: const Key('clips-batch-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
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
    // 逐条广播删除信号：本页监听从网格精准移除，并合并刷新合集横滑区。
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
