import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_confirm_drawer.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/widgets/movie_player/collection_playback_mode.dart';
import 'package:sakuramedia/features/videos/presentation/mobile_video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/mobile_video_player_page.dart';
import 'package:sakuramedia/features/videos/presentation/pick_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/video_collection_detail_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_mutation_change_notifier.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/selection/multi_select_state_mixin.dart';

/// 合集详情的成员排布方式：纵向列表或网格（侧重浏览）。
enum _VideoLayout { list, grid }

/// 移动端视频合集详情页：有序成员列表 / 网格 + 改名 / 移除 / 连播。
///
/// 列表复用桌面端同款行物料 [CollectionMemberRow]（关闭悬停与拖序）；网格用竖版海报卡
/// [CollectionMemberCard]（标题压图）。点击成员走动作抽屉（播放 / 移出合集）。
/// 添加成员仍走视频列表的「加入合集」，故此页不设「添加」入口（与桌面对齐）。
///
/// 长按成员进入多选模式：上方「选择栏」（取消 / 已选 N 个 / 全选），下方「批量栏」
/// （加入合集 / 移除 / 删除），与移动 PornBox 主页对齐。
class MobileVideoCollectionDetailPage extends StatefulWidget {
  const MobileVideoCollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  State<MobileVideoCollectionDetailPage> createState() =>
      _MobileVideoCollectionDetailPageState();
}

class _MobileVideoCollectionDetailPageState
    extends State<MobileVideoCollectionDetailPage>
    with MultiSelectStateMixin<MobileVideoCollectionDetailPage, int> {
  late final VideoCollectionDetailController _controller;
  late final VideoMutationChangeNotifier _mutationNotifier;
  _VideoLayout _layout = _VideoLayout.grid;

  void _toggleLayout() {
    setState(() {
      _layout =
          _layout == _VideoLayout.list ? _VideoLayout.grid : _VideoLayout.list;
    });
  }

  @override
  void initState() {
    super.initState();
    _mutationNotifier = context.read<VideoMutationChangeNotifier>();
    _controller = VideoCollectionDetailController(
      collectionId: widget.collectionId,
      collectionsApi: context.read<VideoCollectionsApi>(),
      videosApi: context.read<VideosApi>(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.collection == null) {
            return const AppMobileSkeletonList(
              key: Key('mobile-video-collection-detail-loading'),
            );
          }
          if (_controller.errorMessage != null &&
              _controller.collection == null) {
            return AppEmptyState(message: _controller.errorMessage!);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                _buildSelectionBar(context)
              else
                _buildHeader(context),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildBody(context)),
              if (selectionMode) _buildBatchBar(context),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------- 头部

  Widget _buildHeader(BuildContext context) {
    final spacing = context.appSpacing;
    final collection = _controller.collection;
    final items = _controller.items;
    final count = collection?.itemCount ?? items.length;
    return Padding(
      // 横向缩进由 AppMobileSubpageShell 的 8px body padding 统一提供。
      padding: EdgeInsets.only(top: spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection?.name ?? '合集',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  '$count 个视频',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            AppTextButton(
              key: const Key('mobile-video-collection-enter-selection-button'),
              label: '选择',
              size: AppTextButtonSize.small,
              icon: const Icon(Icons.check_circle_outline, size: 14),
              onPressed: enterSelection,
            ),
            SizedBox(width: spacing.xs),
            AppIconButton(
              key: const Key('mobile-video-collection-layout-toggle'),
              tooltip: _layout == _VideoLayout.list ? '网格视图' : '列表视图',
              onPressed: _toggleLayout,
              icon: Icon(
                _layout == _VideoLayout.list
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                size: context.appComponentTokens.iconSizeSm,
              ),
            ),
            SizedBox(width: spacing.xs),
            AppTextButton(
              key: const Key('mobile-video-collection-play-all-button'),
              label: '播放',
              size: AppTextButtonSize.small,
              onPressed: () => _playFrom(0),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------- body

  Widget _buildBody(BuildContext context) {
    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '合集还没有视频，去视频列表用「加入合集」添加吧');
    }
    return _layout == _VideoLayout.grid
        ? _buildGrid(context)
        : _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final spacing = context.appSpacing;
    final items = _controller.items;
    return ListView.separated(
      key: const Key('mobile-video-collection-detail-list'),
      // 横向缩进由 shell 提供，此处只补底部留白。
      padding: EdgeInsets.only(bottom: spacing.lg),
      itemCount: items.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onLongPress: selectionMode
              ? null
              : () {
                  enterSelection();
                  toggleSelect(item.itemId);
                },
          child: CollectionMemberRow(
            key: ValueKey<int>(item.itemId),
            index: index,
            coverUrl: item.video.coverImage?.bestAvailableUrl,
            coverWidth: 64,
            coverAspectRatio: context.appComponentTokens.movieCardAspectRatio,
            coverFit: BoxFit.contain,
            title: item.video.preferredTitle,
            subtitle: _subtitleFor(item.video),
            placeholderIcon: Icons.video_library_outlined,
            titleMaxLines: 2,
            // 移动端无悬停、不支持拖序，关闭手柄与 hover 显隐逻辑。
            isHovered: false,
            reorderable: false,
            selectionMode: selectionMode,
            isSelected: isSelected(item.itemId),
            onTap: selectionMode
                ? () => toggleSelect(item.itemId)
                : () => _openSheet(index, item.video),
            menuKey: Key('mobile-video-collection-menu-${item.itemId}'),
            dragHandleKey: Key('mobile-video-reorder-handle-${item.itemId}'),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final spacing = context.appSpacing;
    final items = _controller.items;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = spacing.md;
        final rawColumns = ((width + gap) / (180 + gap)).floor();
        final columns = rawColumns < 2 ? 2 : (rawColumns > 6 ? 6 : rawColumns);
        return MasonryGridView.count(
          key: const Key('mobile-video-collection-detail-grid'),
          // 横向缩进由 shell 提供，此处只补底部留白。
          padding: EdgeInsets.only(bottom: spacing.lg),
          crossAxisCount: columns,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final aspect = _resolveCoverAspect(
              item.video.coverWidth,
              item.video.coverHeight,
            );
            return AspectRatio(
              aspectRatio: aspect,
              child: GestureDetector(
                onLongPress: selectionMode
                    ? null
                    : () {
                        enterSelection();
                        toggleSelect(item.itemId);
                      },
                child: CollectionMemberCard(
                  key: ValueKey<int>(item.itemId),
                  coverUrl: item.video.coverImage?.bestAvailableUrl,
                  coverAspectRatio: 16 / 9,
                  title: item.video.preferredTitle,
                  subtitle: _subtitleFor(item.video),
                  placeholderIcon: Icons.video_library_outlined,
                  titleMaxLines: 2,
                  overlayCaption: true,
                  expandToParent: true,
                  selectionMode: selectionMode,
                  isSelected: isSelected(item.itemId),
                  onTap: selectionMode
                      ? () => toggleSelect(item.itemId)
                      : () => _openSheet(i, item.video),
                  menuKey: Key(
                      'mobile-video-collection-grid-menu-${item.itemId}'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _resolveCoverAspect(int? width, int? height) {
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 16 / 9;
  }

  String? _subtitleFor(VideoItemListItemDto video) {
    if (video.durationSeconds <= 0) {
      return null;
    }
    return formatMediaTimecode(video.durationSeconds);
  }

  // --------------------------------------------------------- 单条动作

  void _openSheet(int index, VideoItemListItemDto video) {
    final itemId = _controller.items[index].itemId;
    showMobileVideoActionsSheet(
      context,
      video: video,
      onPlay: () => _playVideoSingle(video),
      onRemoveFromCollection: () => _removeItem(itemId, video.id),
      onDelete: () => _deleteVideo(itemId, video),
    );
  }

  Future<void> _playFrom(int index) async {
    // 进入连播前先询问形态（列表连播 / 合并播放）；外部关闭返回 null → 放弃跳转。
    // 移动壳传 useBottomDrawer 走底部抽屉范式，对齐其它图片菜单两端。
    final mode = await showCollectionPlaybackModePicker(
      context: context,
      useBottomDrawer: true,
    );
    if (mode == null || !mounted) {
      return;
    }
    final handoff = context.read<CollectionPlaybackHandoff>();
    final sort = _controller.sortExpression;
    // 把当前已排序、带播放地址的成员交给连播页直接用，免其二次全量拉取。
    handoff.offerVideoItems(
      collectionId: widget.collectionId,
      sort: sort,
      items: _controller.items,
    );
    // key 与连播页 takeMode 处保持一致：合集 + 排序，避免同合集换排序后串。
    handoff.offerMode(
      key: 'video:${widget.collectionId}:${sort ?? ''}',
      mode: mode,
    );
    MobileVideoCollectionPlayRouteData(
      collectionId: widget.collectionId,
      startIndex: index,
      // 移动端详情页按手动顺序展示（sortExpression 为 null），连播顺序与之一致。
      sort: sort,
    ).push(context);
  }

  /// 动作抽屉「播放」：只播这一条视频（对齐移动 PornBox 主页 `_playVideo`），不进合集连播。
  /// 头部「播放」按钮仍走 [_playFrom] 走整张合集连播。
  void _playVideoSingle(VideoItemListItemDto video) {
    // 用根 Navigator 推全屏页，覆盖底部导航。
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileVideoPlayerPage(
          videoId: video.id,
          title: video.preferredTitle,
        ),
      ),
    );
  }

  Future<void> _removeItem(int itemId, int videoId) async {
    final error = await _controller.removeItem(itemId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _mutationNotifier.reportCollectionMembershipChanged(
        videoId: videoId,
        collectionId: widget.collectionId,
      );
    }
    showToast(error ?? '已从合集移除');
  }

  /// 彻底删除视频本体（含文件，不可恢复）：先弹底部确认抽屉，再走控制器乐观删除并广播
  /// [VideoMutationChangeNotifier.reportDeleted]，与「全部视频」页的删除一致。
  Future<void> _deleteVideo(int itemId, VideoItemListItemDto video) async {
    final title = video.preferredTitle.trim();
    final label = title.isEmpty ? '该视频' : '“$title”';
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除视频',
      message: '确认删除$label？该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-video-collection-delete-drawer'),
      confirmButtonKey: const Key('mobile-video-collection-delete-confirm-button'),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final error = await _controller.deleteVideo(itemId, video.id);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _mutationNotifier.reportDeleted(video.id);
    }
    showToast(error ?? '已删除视频');
  }

  // --------------------------------------------------------- 选择 / 批量

  List<VideoCollectionItemDto> _selectedItems() => _controller.items
      .where((it) => isSelected(it.itemId))
      .toList(growable: false);

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个视频');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

  Future<void> _batchAddToOtherCollection() async {
    final selected = _selectedItems();
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickVideoCollectionDialog(
      context,
      presentation: PickVideoCollectionPresentation.bottomDrawer,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    final api = context.read<VideoCollectionsApi>();
    final result = await runBatchOperation<VideoCollectionItemDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (item) => api.addCollectionItem(
        collectionId: target.id,
        videoItemId: item.video.id,
      ),
    );
    if (!mounted) {
      return;
    }
    for (final item in result.succeeded) {
      _mutationNotifier.reportCollectionMembershipChanged(
        videoId: item.video.id,
        collectionId: target.id,
      );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _batchRemove() async {
    final selected = _selectedItems();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '从合集移除',
      message: '确认从合集移除选中的 ${selected.length} 个视频？视频本身不会被删除。',
      confirmLabel: '移除',
      drawerKey: const Key('mobile-video-collection-batch-remove-drawer'),
      confirmButtonKey: const Key(
        'mobile-video-collection-batch-remove-confirm-button',
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final result = await runBatchOperation<VideoCollectionItemDto>(
      context,
      title: '正在从合集移除',
      items: selected,
      action: (item) async {
        final error = await _controller.removeItem(item.itemId);
        if (error != null) {
          throw Exception(error);
        }
      },
    );
    if (!mounted) {
      return;
    }
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    for (final item in result.succeeded) {
      _mutationNotifier.reportCollectionMembershipChanged(
        videoId: item.video.id,
        collectionId: widget.collectionId,
      );
    }
    _showBatchToast('移除', result);
    exitSelection();
  }

  Future<void> _batchDelete() async {
    final selected = _selectedItems();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除视频',
      message: '确认删除选中的 ${selected.length} 个视频？该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-video-collection-batch-delete-drawer'),
      confirmButtonKey: const Key(
        'mobile-video-collection-batch-delete-confirm-button',
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final api = context.read<VideosApi>();
    final result = await runBatchOperation<VideoCollectionItemDto>(
      context,
      title: '正在删除视频',
      items: selected,
      action: (item) => api.deleteVideo(item.video.id),
    );
    if (!mounted) {
      return;
    }
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    for (final item in result.succeeded) {
      _mutationNotifier.reportDeleted(item.video.id);
    }
    _showBatchToast('删除', result);
    exitSelection();
  }

  Widget _buildSelectionBar(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final itemIds = _controller.items.map((it) => it.itemId);
    final allSelected = isAllSelected(itemIds);
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
            key: const Key(
              'mobile-video-collection-exit-selection-button',
            ),
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
            key: const Key('mobile-video-collection-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            size: AppTextButtonSize.small,
            onPressed: () => toggleSelectAll(itemIds),
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
                key: const Key(
                  'mobile-video-collection-batch-add-collection-button',
                ),
                label: '加入合集',
                variant: AppButtonVariant.secondary,
                onPressed: hasSelection ? _batchAddToOtherCollection : null,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: AppButton(
                key: const Key(
                  'mobile-video-collection-batch-remove-button',
                ),
                label: '移除',
                variant: AppButtonVariant.secondary,
                onPressed: hasSelection ? _batchRemove : null,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: AppButton(
                key: const Key(
                  'mobile-video-collection-batch-delete-button',
                ),
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
}
