import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/video_collection_detail_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_mutation_change_notifier.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/videos/video_collection_sort_bar.dart';

/// 合集详情的成员排布方式：纵向列表（可拖序）或网格（侧重浏览）。
enum _VideoLayout { list, grid }

/// 视频合集详情页：有序成员列表，支持拖拽重排、移除、单集/全集连播。
///
/// 排布与切片合集详情页共用 [CollectionMemberRow] / [CollectionMemberCard]，
/// 封面沿用 PornBox 视频卡的竖版海报比例。
class DesktopVideoCollectionDetailPage extends StatefulWidget {
  const DesktopVideoCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  State<DesktopVideoCollectionDetailPage> createState() =>
      _DesktopVideoCollectionDetailPageState();
}

class _DesktopVideoCollectionDetailPageState
    extends State<DesktopVideoCollectionDetailPage>
    with MultiSelectStateMixin<DesktopVideoCollectionDetailPage, int> {
  late final VideoCollectionDetailController _controller;
  late final VideoMutationChangeNotifier _mutationNotifier;
  int? _hoveredItemId;
  _VideoLayout _layout = _VideoLayout.list;

  @override
  void initState() {
    super.initState();
    _mutationNotifier = context.read<VideoMutationChangeNotifier>();
    _controller = VideoCollectionDetailController(
      collectionId: widget.collectionId,
      collectionsApi: context.read<VideoCollectionsApi>(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setHovered(int? itemId) {
    if (_hoveredItemId == itemId) {
      return;
    }
    setState(() => _hoveredItemId = itemId);
  }

  void _toggleLayout() {
    setState(() {
      _layout =
          _layout == _VideoLayout.list ? _VideoLayout.grid : _VideoLayout.list;
    });
  }

  /// 进入合集连播页：从第 [index] 集开始，原生 Playlist 自动连播（与切片合集一致）。
  void _playFrom(int index) {
    context.pushDesktopVideoCollectionPlay(
      collectionId: widget.collectionId,
      startIndex: index,
      // 把详情页当前排序带进连播页，使连播顺序与详情页一致（手动顺序为 null）。
      sort: _controller.sortExpression,
    );
  }

  Future<void> _removeItem(int itemId) async {
    int? videoId;
    for (final item in _controller.items) {
      if (item.itemId == itemId) {
        videoId = item.video.id;
        break;
      }
    }
    final error = await _controller.removeItem(itemId);
    if (!mounted) {
      return;
    }
    if (error == null && videoId != null) {
      // 合集封面/计数可能变化，广播给列表页的合集横滑区。
      _mutationNotifier.reportCollectionMembershipChanged(
        videoId: videoId,
        collectionId: widget.collectionId,
      );
    }
    showToast(error ?? '已从合集移除');
  }

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

  Future<bool> _confirmBatch(String title, String message) async {
    return showAppConfirmDialog(
      context,
      title: title,
      message: message,
      danger: true,
      confirmKey: const Key('video-collection-batch-confirm-button'),
    );
  }

  Future<void> _batchRemove() async {
    final selected = _selectedItems();
    if (selected.isEmpty) {
      return;
    }
    final ok = await _confirmBatch(
      '从合集移除',
      '确认从合集移除选中的 ${selected.length} 个视频？视频本身不会被删除。',
    );
    if (!mounted || !ok) {
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
    // 重新拉取合集与成员，校准本页头部计数（collection.itemCount）与列表。
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    // 广播给列表页的合集横滑区（封面/计数变化）。
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
    final ok = await _confirmBatch(
      '删除视频',
      '确认删除选中的 ${selected.length} 个视频？该操作不可恢复。',
    );
    if (!mounted || !ok) {
      return;
    }
    final videosApi = context.read<VideosApi>();
    final result = await runBatchOperation<VideoCollectionItemDto>(
      context,
      title: '正在删除视频',
      items: selected,
      action: (item) => videosApi.deleteVideo(item.video.id),
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与成员，校准本页头部计数与列表。
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    // 广播删除信号：列表页网格精准移除 + 合集横滑区刷新。
    for (final item in result.succeeded) {
      _mutationNotifier.reportDeleted(item.video.id);
    }
    _showBatchToast('删除', result);
    exitSelection();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = _controller.errorMessage;
          if (error != null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppEmptyState(message: error),
                SizedBox(height: context.appSpacing.md),
                AppButton(
                  label: '重试',
                  variant: AppButtonVariant.secondary,
                  onPressed: _controller.load,
                ),
              ],
            );
          }
          return Padding(
            padding: EdgeInsets.all(context.appSpacing.lg),
            child: Column(
              key: const Key('video-collection-detail-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                // 排序工具条：选择模式下隐藏（与其它头部控件一致），空合集无需排序。
                if (!selectionMode && _controller.items.isNotEmpty) ...[
                  SizedBox(height: context.appSpacing.md),
                  VideoCollectionSortBar(
                    sortField: _controller.sortField,
                    sortDirection: _controller.sortDirection,
                    onChanged: ({required field, direction}) =>
                        _controller.applySort(field: field, direction: direction),
                  ),
                ],
                SizedBox(height: context.appSpacing.lg),
                Expanded(child: _buildBody(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final collection = _controller.collection;
    final items = _controller.items;
    final count = collection?.itemCount ?? items.length;
    final description = collection?.description.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection?.name ?? '合集详情',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s20,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xs),
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
            // 选择模式下隐藏「选择/视图切换/播放全部」，仅保留标题与下方批量栏。
            if (!selectionMode) ...[
              if (items.isNotEmpty) ...[
                AppTextButton(
                  key: const Key('video-collection-enter-selection-button'),
                  label: '选择',
                  size: AppTextButtonSize.small,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  onPressed: enterSelection,
                ),
                SizedBox(width: context.appSpacing.sm),
                AppIconButton(
                  key: const Key('video-collection-layout-toggle'),
                  tooltip: _layout == _VideoLayout.list ? '网格视图' : '列表视图',
                  onPressed: _toggleLayout,
                  icon: Icon(
                    _layout == _VideoLayout.list
                        ? Icons.grid_view_rounded
                        : Icons.view_agenda_outlined,
                    size: context.appComponentTokens.iconSizeSm,
                  ),
                ),
                SizedBox(width: context.appSpacing.sm),
              ],
              AppButton(
                key: const Key('video-collection-play-all-button'),
                label: '播放全部',
                variant: AppButtonVariant.primary,
                onPressed: items.isEmpty ? null : () => _playFrom(0),
              ),
            ],
          ],
        ),
        if (description.isNotEmpty) ...[
          SizedBox(height: context.appSpacing.sm),
          Text(
            description,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
        if (selectionMode) ...[
          SizedBox(height: context.appSpacing.md),
          _buildSelectionBar(context),
        ],
      ],
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final items = _controller.items;
    final itemIds = items.map((it) => it.itemId);
    final allSelected = isAllSelected(itemIds);
    final hasSelection = selectedCount > 0;
    final spacing = context.appSpacing;

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
          key: const Key('video-collection-select-all-button'),
          label: allSelected ? '取消全选' : '全选',
          size: AppTextButtonSize.small,
          onPressed: () => toggleSelectAll(itemIds),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('video-collection-batch-remove-button'),
          label: '从合集移除',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchRemove : null,
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('video-collection-batch-delete-button'),
          label: '删除视频',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchDelete : null,
        ),
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: const Key('video-collection-exit-selection-button'),
          label: '取消',
          size: AppTextButtonSize.small,
          onPressed: exitSelection,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '合集还没有视频，去视频列表用「加入合集」添加吧');
    }
    return _layout == _VideoLayout.grid
        ? _buildGrid(context)
        : _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final items = _controller.items;
    // 仅手动顺序且非选择模式下允许拖拽重排：其它排序下拖拽会与排序冲突。
    final canReorder = !selectionMode && _controller.isManualOrder;

    CollectionMemberRow buildRow(int index) {
      final item = items[index];
      return CollectionMemberRow(
        index: index,
        coverUrl: item.video.coverImage?.bestAvailableUrl,
        coverWidth: 56,
        coverAspectRatio: context.appComponentTokens.movieCardAspectRatio,
        title: item.video.preferredTitle,
        subtitle: _formatReleaseDate(item.video.releaseDate),
        isHovered: _hoveredItemId == item.itemId,
        onTap: selectionMode
            ? () => toggleSelect(item.itemId)
            : () => _playFrom(index),
        menuKey: Key('video-collection-menu-${item.itemId}'),
        dragHandleKey: Key('video-reorder-handle-${item.itemId}'),
        onRemove: () => _removeItem(item.itemId),
        placeholderIcon: Icons.video_library_outlined,
        titleMaxLines: 2,
        reorderable: canReorder,
        selectionMode: selectionMode,
        isSelected: isSelected(item.itemId),
      );
    }

    // 选择模式或非手动排序下禁用拖拽重排，退化为普通列表。
    if (!canReorder) {
      return ListView.separated(
        key: const Key('video-collection-detail-list'),
        itemCount: items.length,
        separatorBuilder: (context, _) =>
            SizedBox(height: context.appSpacing.sm),
        itemBuilder: (context, index) => buildRow(index),
      );
    }

    return ReorderableListView.builder(
      key: const Key('video-collection-detail-list'),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: _controller.reorder,
      // 默认 proxyDecorator 会给拖动项叠加带阴影的 Material，这里换成无阴影透明包装。
      proxyDecorator: (child, index, animation) => Material(
        type: MaterialType.transparency,
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          key: ValueKey<int>(item.itemId),
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: MouseRegion(
            onEnter: (_) => _setHovered(item.itemId),
            onExit: (_) {
              if (_hoveredItemId == item.itemId) {
                _setHovered(null);
              }
            },
            child: buildRow(index),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final items = _controller.items;
    final spacing = context.appSpacing;
    return GridView.builder(
      key: const Key('video-collection-detail-grid'),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
        // 竖版海报：标题/日期压在封面底部，整卡即封面比例，无下方留白。
        childAspectRatio: context.appComponentTokens.movieCardAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return CollectionMemberCard(
          key: ValueKey<int>(item.itemId),
          coverUrl: item.video.coverImage?.bestAvailableUrl,
          coverAspectRatio: context.appComponentTokens.movieCardAspectRatio,
          title: item.video.preferredTitle,
          subtitle: _formatReleaseDate(item.video.releaseDate),
          onTap: selectionMode
              ? () => toggleSelect(item.itemId)
              : () => _playFrom(index),
          menuKey: Key('video-collection-grid-menu-${item.itemId}'),
          onRemove: () => _removeItem(item.itemId),
          placeholderIcon: Icons.video_library_outlined,
          titleMaxLines: 2,
          overlayCaption: true,
          selectionMode: selectionMode,
          isSelected: isSelected(item.itemId),
        );
      },
    );
  }
}

/// 发布日期文案；为空返回 `null`（不展示该行）。
String? _formatReleaseDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
}
