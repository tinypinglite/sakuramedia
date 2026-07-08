import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_to_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/controllers/clip_collections_overview_controller.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/pick_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/clips/presentation/clips_overview_controller.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_actions_sheet.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_confirm_drawer.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_player_page.dart';
import 'package:sakuramedia/features/clips/presentation/rename_clip_dialog.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/collections/collection_card.dart';
import 'package:sakuramedia/widgets/selection/multi_select_state_mixin.dart';

/// 概览页「切片」tab：上方「我的合集」横滑区 + 下方「全部切片」网格。
///
/// 数据层与桌面 `DesktopClipsPage` 完全一致（复用同一组 controller 与 mutation
/// 广播），仅在布局上改为移动端竖屏网格 + 底部抽屉形态的编辑交互；长按切片卡进入
/// 多选模式，支持批量加入合集 / 删除（与移动 PornBox 对齐）。
class MobileOverviewClipsTab extends StatefulWidget {
  const MobileOverviewClipsTab({super.key});

  @override
  State<MobileOverviewClipsTab> createState() => _MobileOverviewClipsTabState();
}

class _MobileOverviewClipsTabState extends State<MobileOverviewClipsTab>
    with MultiSelectStateMixin<MobileOverviewClipsTab, int> {
  late final ClipsOverviewController _clipsController;
  late final ClipCollectionsOverviewController _collectionsController;
  late final ClipMutationChangeNotifier _mutationNotifier;
  final ScrollController _scrollController = ScrollController();
  bool _railRefreshScheduled = false;

  Listenable get _pageListenable =>
      Listenable.merge(<Listenable>[_clipsController, _collectionsController]);

  @override
  void initState() {
    super.initState();
    final clipsApi = context.read<ClipsApi>();
    final collectionsApi = context.read<ClipCollectionsApi>();
    _mutationNotifier = context.read<ClipMutationChangeNotifier>();
    _clipsController = ClipsOverviewController(
      fetchClips:
          ({
            int page = 1,
            int pageSize = 24,
            String sort = 'created_at:desc',
          }) =>
              clipsApi.getMyClips(page: page, pageSize: pageSize, sort: sort),
    )..load();
    _collectionsController = ClipCollectionsOverviewController(
      fetchCollections: collectionsApi.getCollections,
    )..load();
    _scrollController.addListener(_onScroll);
    _mutationNotifier.addListener(_onMutation);
  }

  @override
  void dispose() {
    _mutationNotifier.removeListener(_onMutation);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _clipsController.dispose();
    _collectionsController.dispose();
    super.dispose();
  }

  /// 删除 / 合集成员变化都可能改变合集横滑区的封面与计数；用微任务合并一轮内多次
  /// 信号成一次刷新。切片本身被删除时再从「全部切片」网格精准移除。
  void _onMutation() {
    final change = _mutationNotifier.lastChange;
    if (change == null) {
      return;
    }
    if (change.kind == ClipMutationKind.deleted && change.clipId != null) {
      _clipsController.removeClip(change.clipId!);
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
      _collectionsController.refresh();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _clipsController.loadMore();
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _clipsController.refresh(),
      _collectionsController.refresh(),
    ]);
  }

  List<MediaClipDto> _selectedClips() => _clipsController.clips
      .where((c) => isSelected(c.clipId))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        return Column(
          children: [
            if (selectionMode) _buildSelectionBar(context),
            Expanded(
              child: AppAdaptiveRefreshScrollView(
                key: const Key('mobile-clips-tab-scroll'),
                controller: _scrollController,
                onRefresh: _refresh,
                slivers: <Widget>[
                  // 选择模式下隐藏合集横滑区，只剩切片网格，与移动 PornBox 一致。
                  if (!selectionMode)
                    SliverToBoxAdapter(child: _buildCollectionsSection(context)),
                  SliverToBoxAdapter(child: _buildClipsHeader(context)),
                  _buildClipsSliver(context),
                  SliverToBoxAdapter(child: _buildFooter(context)),
                ],
              ),
            ),
            if (selectionMode) _buildBatchBar(context),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------- 合集区

  Widget _buildCollectionsSection(BuildContext context) {
    final spacing = context.appSpacing;
    final collections = _collectionsController.collections;
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
                size: AppTextSize.s16,
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
        _buildCollectionsRow(context, collections),
        SizedBox(height: spacing.lg),
      ],
    );
  }

  Widget _buildCollectionsRow(
    BuildContext context,
    List<ClipCollectionDto> collections,
  ) {
    if (_collectionsController.errorMessage != null) {
      return _HintBox(message: _collectionsController.errorMessage!);
    }
    if (_collectionsController.isLoading && collections.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (collections.isEmpty) {
      return const _HintBox(message: '还没有合集，点「新建」把喜欢的切片攒成一个连播合集吧');
    }
    final spacing = context.appSpacing;
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
              onTap:
                  () =>
                      MobileClipCollectionDetailRouteData(
                        collectionId: collection.id,
                      ).push(context),
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- 切片区

  Widget _buildClipsHeader(BuildContext context) {
    final spacing = context.appSpacing;
    final hasClips = _clipsController.clips.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Row(
        children: [
          Text(
            '全部切片',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
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
          ),
          SizedBox(width: spacing.sm),
          _buildSortAction(
            context,
            actionKey: const Key('mobile-clips-sort-earliest'),
            label: '最早',
            sort: 'created_at:asc',
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
    );
  }

  Widget _buildSortAction(
    BuildContext context, {
    required Key actionKey,
    required String label,
    required String sort,
  }) {
    return AppTextButton(
      key: actionKey,
      label: label,
      size: AppTextButtonSize.xSmall,
      isSelected: _clipsController.sort == sort,
      onPressed: () => _clipsController.setSort(sort),
    );
  }

  Widget _buildClipsSliver(BuildContext context) {
    if (_clipsController.isLoading && _clipsController.clips.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(
            child: SizedBox(
              key: Key('mobile-clips-loading'),
              width: 32,
              height: 32,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }
    if (_clipsController.errorMessage != null && _clipsController.clips.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: _clipsController.errorMessage!),
        ),
      );
    }
    final clips = _clipsController.clips;
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

  Widget _buildFooter(BuildContext context) {
    if (_clipsController.loadMoreErrorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
        child: Center(
          child: AppButton(
            key: const Key('mobile-clips-load-more-retry'),
            label: '加载更多失败，点击重试',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: _clipsController.loadMore,
          ),
        ),
      );
    }
    if (_clipsController.isLoadingMore) {
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

  Widget _buildSelectionBar(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final clipIds = _clipsController.clips.map((c) => c.clipId);
    final allSelected = isAllSelected(clipIds);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
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
      onOpenMovie:
          movieNumber != null && movieNumber.isNotEmpty
              ? () => _openMovie(movieNumber)
              : null,
    );
  }

  void _playClip(MediaClipDto clip) {
    // 用根 Navigator 推全屏页，覆盖底部导航；切片很短，直接传 streamUrl 即可，
    // 无需经 go_router 把签名地址放进 URL。
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder:
            (_) => MobileClipPlayerPage(
              streamUrl: clip.streamUrl,
              title: clip.title,
            ),
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
      final updated = await context.read<ClipsApi>().updateClipTitle(
        clipId: clip.clipId,
        title: newTitle,
      );
      _clipsController.replaceClip(updated);
      if (mounted) {
        showToast('已重命名');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '重命名失败，请重试'));
    }
  }

  Future<void> _deleteClip(MediaClipDto clip) async {
    final title = clip.title.trim().isEmpty ? '该切片' : '“${clip.title.trim()}”';
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除切片',
      message: '确认删除$title？切片文件会被一并删除，该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-clip-delete-drawer'),
      confirmButtonKey: const Key('mobile-clip-delete-confirm-button'),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await context.read<ClipsApi>().deleteClip(clipId: clip.clipId);
      _mutationNotifier.reportDeleted(clip.clipId);
      if (mounted) {
        showToast('已删除切片');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
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
    _mutationNotifier.reportCollectionMembershipChanged(clipId: clip.clipId);
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation: ClipCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || created == null) {
      return;
    }
    _collectionsController.insertCollection(created);
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
    final api = context.read<ClipCollectionsApi>();
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (clip) => api.addClipToCollection(
        collectionId: target.id,
        clipId: clip.clipId,
      ),
    );
    if (!mounted) {
      return;
    }
    for (final clip in result.succeeded) {
      _mutationNotifier.reportCollectionMembershipChanged(
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
    final api = context.read<ClipsApi>();
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在删除切片',
      items: selected,
      action: (clip) => api.deleteClip(clipId: clip.clipId),
    );
    if (!mounted) {
      return;
    }
    for (final clip in result.succeeded) {
      _mutationNotifier.reportDeleted(clip.clipId);
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
