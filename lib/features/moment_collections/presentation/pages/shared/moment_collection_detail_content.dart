import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/moment_collection_placeholders.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_detail_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_moments_to_collection_dialog.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/pick_moment_collection_dialog.dart';
import 'package:sakuramedia/features/moments/presentation/actions/moment_preview_flow.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

/// 时刻合集详情共享实现：桌面 / 移动双端壳差异收在 [isMobile] 参数里。
///
/// 交互范式对齐切片合集详情：桌面标题块 + [AppListHeader] + 内联批量操作；
/// 移动端合集名上报返回栏、长按进多选、批量动作走贴底条；双端网格，成员点击
/// 统一弹时刻预览层；桌面网格卡悬停渐显信息与动作行（来源媒体已删除时隐藏播放）。
class MomentCollectionDetailContent extends ConsumerStatefulWidget {
  const MomentCollectionDetailContent({
    super.key,
    required this.collectionId,
    required this.isMobile,
  });

  final int collectionId;
  final bool isMobile;

  @override
  ConsumerState<MomentCollectionDetailContent> createState() =>
      _MomentCollectionDetailContentState();
}

class _MomentCollectionDetailContentState
    extends ConsumerState<MomentCollectionDetailContent>
    with MultiSelectStateMixin<MomentCollectionDetailContent, int> {
  bool get _isMobile => widget.isMobile;

  String get _keyPrefix =>
      _isMobile ? 'mobile-moment-collection' : 'moment-collection';

  String get _fallbackPath => _isMobile
      ? '$mobileMomentCollectionsPath/${widget.collectionId}'
      : '$desktopMomentCollectionsPath/${widget.collectionId}';

  MomentCollectionDetailProvider get _providerRef =>
      momentCollectionDetailProvider(widget.collectionId);

  MomentCollectionMutationEvents get _mutationBroadcaster =>
      ref.read(momentCollectionMutationEventsProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_providerRef);
    final state = async.value;
    if (_isMobile) {
      _reportTitleToShell(state?.collection);
    }
    final isLoading = async.isLoading && state == null;

    final content = Builder(
      builder: (context) {
        if (!isLoading && async.hasError && state == null) {
          return AppEmptyState(
            message: apiErrorMessage(
              async.error!,
              fallback: '合集详情暂时无法加载，请稍后重试',
            ),
          );
        }
        if (!isLoading && state == null) {
          return const SizedBox.shrink();
        }
        // loading 用占位数据渲染同一份真实布局，由 [AppSkeletonizer] 灰化，
        // 骨架与数据到位后的首屏严格同形。
        final displayState =
            isLoading ? momentCollectionDetailPlaceholder() : state!;
        return AppSkeletonizer(
          enabled: isLoading,
          child: Column(
            key: Key('$_keyPrefix-detail-page-body'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isMobile) ...[
                _buildTitleBlock(context, displayState),
                SizedBox(height: context.appSpacing.md),
              ],
              if (selectionMode)
                _buildSelectionHeader(context, displayState)
              else
                _buildListHeader(context, displayState),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildPoints(context, displayState)),
              if (_isMobile && selectionMode)
                _buildBatchBar(context, displayState),
            ],
          ),
        );
      },
    );

    if (_isMobile) {
      return ColoredBox(color: context.appColors.surfaceCard, child: content);
    }
    return AppPageRefreshScope(
      onRefresh: ref.read(_providerRef.notifier).refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: content,
      ),
    );
  }

  /// 把合集名报给外层返回栏。数据是异步来的，所以用 post-frame 回调写。
  void _reportTitleToShell(MomentCollectionDto? collection) {
    final name = collection?.name.trim() ?? '';
    if (name.isEmpty) {
      return;
    }
    final notifier = AppMobileSubpageTitle.read(context);
    if (notifier == null || notifier.value == name) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notifier.value = name;
      }
    });
  }

  // --------------------------------------------------------- 标题块

  /// 标题块（仅桌面）：合集名 + 「编辑合集」。
  Widget _buildTitleBlock(
    BuildContext context,
    MomentCollectionDetailState state,
  ) {
    final collection = state.collection;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            collection.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        // 多选态隐藏「编辑合集」，避免和批量操作混在一起误触。
        if (!selectionMode) ...[
          SizedBox(width: context.appSpacing.xs),
          AppIconButton(
            key: Key('$_keyPrefix-rename-button'),
            tooltip: '编辑合集',
            onPressed: () => _editCollection(context),
            icon: Icon(
              Icons.edit_outlined,
              size: context.appComponentTokens.iconSizeSm,
            ),
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------------- 顶栏

  /// 成员列表顶栏：与其它列表页共用同一条 `AppListHeader`。
  /// **本页没有筛选维度**——时刻合集是手动顺序，不接筛选入口。
  Widget _buildListHeader(
    BuildContext context,
    MomentCollectionDetailState state,
  ) {
    final count = state.collection.pointCount;
    final hasPoints = state.points.isNotEmpty;
    return AppListHeader(
      informationSlots: [
        AppListHeaderInfo(key: Key('$_keyPrefix-total'), label: '$count 个时刻'),
      ],
      actionSlots: [
        if (_isMobile)
          AppTextButton(
            key: Key('$_keyPrefix-add-moments-button'),
            label: '添加',
            size: AppTextButtonSize.xSmall,
            onPressed: () => _addMoments(context),
          )
        else
          AppTextButton(
            key: Key('$_keyPrefix-add-moments-button'),
            label: '添加时刻',
            size: AppTextButtonSize.small,
            onPressed: () => _addMoments(context),
          ),
        if (hasPoints && !_isMobile)
          AppSelectionEntryButton(
            key: Key('$_keyPrefix-enter-selection-button'),
            onPressed: enterSelection,
          ),
        if (_isMobile)
          AppIconButton(
            key: Key('$_keyPrefix-rename-button'),
            tooltip: '编辑合集',
            onPressed: () => _editCollection(context),
            icon: Icon(
              Icons.edit_outlined,
              size: context.appComponentTokens.iconSizeSm,
            ),
          ),
      ],
    );
  }

  /// 多选态顶栏：桌面原地改写整条顶栏（批量动作内联），移动端只留退出/计数/全选、
  /// 批量动作走贴底 [_buildBatchBar]。
  Widget _buildSelectionHeader(
    BuildContext context,
    MomentCollectionDetailState state,
  ) {
    final pointIds = state.points.map((point) => point.pointId);
    final allSelected = isAllSelected(pointIds);
    final hasSelection = selectedCount > 0;
    if (_isMobile) {
      return AppListHeader.selection(
        selectionLabel: '已选 $selectedCount 个',
        selectionExitButtonKey: Key('$_keyPrefix-exit-selection-button'),
        onExitSelection: exitSelection,
        actionSlots: [
          AppButton(
            key: Key('$_keyPrefix-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: () => toggleSelectAll(pointIds),
          ),
        ],
      );
    }
    return AppSelectionHeaderToolbar(
      countLabel: '已选 $selectedCount 个',
      selectAllLabel: allSelected ? '取消全选' : '全选',
      selectAllKey: Key('$_keyPrefix-select-all-button'),
      onToggleAll: () => toggleSelectAll(pointIds),
      actions: [
        AppButton(
          key: Key('$_keyPrefix-batch-remove-button'),
          label: '从合集移除',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? () => _batchRemove(state) : null,
        ),
        AppButton(
          key: Key('$_keyPrefix-batch-delete-button'),
          label: '删除时刻',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? () => _batchDelete(state) : null,
        ),
      ],
      exitKey: Key('$_keyPrefix-exit-selection-button'),
      onExit: exitSelection,
    );
  }

  Widget _buildBatchBar(
    BuildContext context,
    MomentCollectionDetailState state,
  ) {
    final hasSelection = selectedCount > 0;
    return AppSelectionBottomBar(
      key: Key('$_keyPrefix-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('$_keyPrefix-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('$_keyPrefix-batch-remove-button'),
          label: '移除',
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection ? () => _batchRemove(state) : null,
        ),
        AppButton(
          key: Key('$_keyPrefix-batch-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          onPressed: hasSelection ? () => _batchDelete(state) : null,
        ),
      ],
    );
  }

  // --------------------------------------------------------- body

  Widget _buildPoints(BuildContext context, MomentCollectionDetailState state) {
    if (state.points.isEmpty) {
      return AppEmptyState(
        message: _isMobile ? '合集还没有时刻，点右上角「添加」加入吧' : '合集还没有时刻，去「时刻」里加入吧',
      );
    }
    return _buildGrid(context, state);
  }

  Widget _buildGrid(BuildContext context, MomentCollectionDetailState state) {
    final points = state.points;
    final spacing = context.appSpacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = resolveAppCardGridColumnCount(
          context,
          width: constraints.maxWidth,
          spacing: spacing.md,
        );
        return GridView.builder(
          key: Key('$_keyPrefix-detail-grid'),
          padding: _isMobile
              ? EdgeInsets.only(bottom: spacing.lg)
              : EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 9,
          ),
          itemCount: points.length,
          itemBuilder: (context, index) {
            final point = points[index];
            final item = point.toMomentListItem();
            if (_isMobile) {
              return GestureDetector(
                onLongPress: selectionMode
                    ? null
                    : () {
                        enterSelection();
                        toggleSelect(point.pointId);
                      },
                child: _buildGridCard(point, item, context),
              );
            }
            return _buildGridCard(point, item, context);
          },
        );
      },
    );
  }

  Widget _buildGridCard(
    MomentCollectionPointDto point,
    MomentListItem item,
    BuildContext context,
  ) {
    // 桌面网格走悬停披露：收起态只留封面，悬停渐显信息与动作行；移动端没有
    // hover，保持标题常显，信息与播放入口走点击后的预览层。
    final canPlay = item.mediaId > 0;
    return CollectionMemberCard(
      key: ValueKey<int>(point.pointId),
      coverUrl: item.image?.bestAvailableUrl,
      coverAspectRatio: 16 / 9,
      title: item.displayLabel,
      subtitle: _isMobile
          ? formatMediaTimecode(item.offsetSeconds)
          : item.hoverMeta,
      overlayCaption: _isMobile,
      clipOverlay: !_isMobile,
      onPlay: canPlay && !_isMobile
          ? () => unawaited(
              playMomentItem(
                context: context,
                item: item,
                fallbackPath: _fallbackPath,
              ),
            )
          : null,
      playButtonKey: _isMobile
          ? null
          : Key('$_keyPrefix-grid-play-${point.pointId}'),
      onTap: selectionMode
          ? () => toggleSelect(point.pointId)
          : () => _preview(context, item),
      menuKey: Key('$_keyPrefix-grid-menu-${point.pointId}'),
      onOpenSource: _isMobile ? null : _openMovieCallback(item),
      openSourceLabel: '影片',
      openSourceButtonKey: Key('$_keyPrefix-grid-movie-${point.pointId}'),
      onRemove: _isMobile ? null : () => _removePoint(point),
      removeButtonKey: Key('$_keyPrefix-grid-remove-${point.pointId}'),
      onDelete: _isMobile ? null : () => _deletePoint(point),
      deleteButtonKey: Key('$_keyPrefix-grid-delete-${point.pointId}'),
      deleteLabel: '删除时刻',
      selectionMode: selectionMode,
      isSelected: isSelected(point.pointId),
    );
  }

  // --------------------------------------------------------- 单条动作

  /// 悬停 / 右键「影片」：打开来源影片详情；起播由同卡的播放键
  /// （[playMomentItem]）覆盖，这里不再从该时刻起播。
  VoidCallback? _openMovieCallback(MomentListItem item) {
    if (item.isVideo) {
      return null;
    }
    final movieNumber = item.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return null;
    }
    return () => openMomentSourceMovie(
      context: context,
      item: item,
      fallbackPath: _fallbackPath,
    );
  }

  Future<void> _preview(BuildContext context, MomentListItem item) {
    return showMomentPreviewFlow(
      context: context,
      item: item,
      fallbackPath: _fallbackPath,
      drawerKey: _isMobile
          ? const Key('mobile-moment-collection-preview-bottom-sheet')
          : null,
      onPointRemoved: () {
        ref.read(_providerRef.notifier).refresh();
        _mutationBroadcaster.reportChanged(widget.collectionId);
      },
    );
  }

  Future<void> _removePoint(MomentCollectionPointDto point) async {
    try {
      await ref.read(_providerRef.notifier).removePoint(point.pointId);
      if (!mounted) {
        return;
      }
      // 合集封面 / 计数可能变化，广播给上层合集列表（首页横滑区、全部合集页）。
      _mutationBroadcaster.reportChanged(widget.collectionId);
      showToast('已从合集移除');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '移出合集失败，请重试'));
    }
  }

  /// 彻底删除时刻标记本体（由后端从所有合集级联移除，不可恢复）：先确认，再走
  /// notifier 乐观删除并广播。与「移出合集」不同。
  Future<void> _deletePoint(MomentCollectionPointDto point) async {
    final item = point.toMomentListItem();
    final label = '“${item.displayLabel}”';
    final confirmed = await _confirm(
      title: '删除时刻',
      message: '确认删除$label？该时刻标记会被永久删除，该操作不可恢复。',
      confirmLabel: _isMobile ? '删除' : '确认',
      confirmKey: Key('$_keyPrefix-delete-confirm-button'),
      drawerKey: _isMobile ? Key('$_keyPrefix-delete-drawer') : null,
      onConfirm: () =>
          ref.read(_providerRef.notifier).deletePoint(point.pointId),
    );
    if (!mounted || !confirmed) {
      return;
    }
    _mutationBroadcaster.reportChanged(widget.collectionId);
    showToast('已删除时刻');
  }

  Future<void> _editCollection(BuildContext context) async {
    final collection = ref.read(_providerRef).value?.collection;
    if (collection == null) {
      return;
    }
    final updated = await showMomentCollectionEditor(
      context,
      collection: collection,
    );
    if (!mounted || updated == null) {
      return;
    }
    ref.read(_providerRef.notifier).replaceCollection(updated);
    _mutationBroadcaster.reportChanged(widget.collectionId);
    showToast('已保存');
  }

  Future<void> _addMoments(BuildContext context) async {
    final currentPoints =
        ref.read(_providerRef).value?.points ??
        const <MomentCollectionPointDto>[];
    await showAddMomentsToCollectionDialog(
      context,
      collectionId: widget.collectionId,
      memberPointIds: currentPoints.map((point) => point.pointId).toSet(),
    );
    if (!mounted) {
      return;
    }
    // 选择器内可能增删了成员，回来统一刷新时刻列表与计数。
    await ref.read(_providerRef.notifier).refresh();
    if (!mounted) {
      return;
    }
    _mutationBroadcaster.reportChanged(widget.collectionId);
  }

  // --------------------------------------------------------- 选择 / 批量

  List<MomentCollectionPointDto> _selectedPoints(
    MomentCollectionDetailState state,
  ) => state.points
      .where((point) => isSelected(point.pointId))
      .toList(growable: false);

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个时刻');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

  /// 「加入其它合集」批量动作是**移动端独有**（桌面时刻合集没有此入口），
  /// 按 [isMobile] 门控展示。
  Future<void> _batchAddToOtherCollection(
    MomentCollectionDetailState state,
  ) async {
    final selected = _selectedPoints(state);
    if (selected.isEmpty) {
      return;
    }
    final MomentCollectionDto? target = await showPickMomentCollectionDialog(
      context,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    final api = ref.read(momentCollectionsApiProvider);
    final result = await runBatchOperation<MomentCollectionPointDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (point) =>
          api.addPoint(collectionId: target.id, pointId: point.pointId),
    );
    if (!mounted) {
      return;
    }
    _mutationBroadcaster.reportChanged(target.id);
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _batchRemove(MomentCollectionDetailState state) async {
    final selected = _selectedPoints(state);
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await _confirm(
      title: '从合集移除',
      message: '确认从合集移除选中的 ${selected.length} 个时刻？时刻本身不会被删除。',
      confirmLabel: _isMobile ? '移除' : '确认',
      confirmKey: Key('$_keyPrefix-batch-remove-confirm-button'),
      drawerKey: _isMobile ? Key('$_keyPrefix-batch-remove-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final notifier = ref.read(_providerRef.notifier);
    final result = await runBatchOperation<MomentCollectionPointDto>(
      context,
      title: '正在从合集移除',
      items: selected,
      action: (point) => notifier.removePoint(point.pointId),
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与时刻，校准本页头部计数与列表。
    await notifier.refresh();
    if (!mounted) {
      return;
    }
    _mutationBroadcaster.reportChanged(widget.collectionId);
    _showBatchToast('移除', result);
    exitSelection();
  }

  Future<void> _batchDelete(MomentCollectionDetailState state) async {
    final selected = _selectedPoints(state);
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await _confirm(
      title: '删除时刻',
      message: '确认删除选中的 ${selected.length} 个时刻？该操作不可恢复。',
      confirmLabel: _isMobile ? '删除' : '确认',
      confirmKey: Key('$_keyPrefix-batch-delete-confirm-button'),
      drawerKey: _isMobile ? Key('$_keyPrefix-batch-delete-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final mediaApi = ref.read(mediaApiProvider);
    final result = await runBatchOperation<MomentCollectionPointDto>(
      context,
      title: '正在删除时刻',
      items: selected,
      action: (point) => mediaApi.deleteMediaPointById(pointId: point.pointId),
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与时刻，校准本页头部计数与列表。
    await ref.read(_providerRef.notifier).refresh();
    if (!mounted) {
      return;
    }
    _mutationBroadcaster.reportChanged(widget.collectionId);
    _showBatchToast('删除', result);
    exitSelection();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Key confirmKey,
    Key? drawerKey,
    Future<void> Function()? onConfirm,
  }) {
    return showAppConfirmDialog(
      context,
      title: title,
      message: message,
      danger: true,
      confirmLabel: confirmLabel,
      dialogKey: drawerKey,
      confirmKey: confirmKey,
      onConfirm: onConfirm,
      failureFallback: '删除失败，请重试',
    );
  }
}
