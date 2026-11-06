import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/moment_collection_placeholders.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_detail_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_moments_to_collection_dialog.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/pick_moment_collection_dialog.dart';
import 'package:sakuramedia/features/moments/presentation/actions/moment_preview_flow.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

/// 时刻合集详情共享实现：桌面 / 移动双端壳差异收在 [isMobile] 参数里。
///
/// 交互范式对齐切片合集详情：桌面玻璃控制条 + 内联批量操作；
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
        final l10n = AppLocalizations.of(context);
        if (!isLoading && async.hasError && state == null) {
          return AppEmptyState(
            message: apiErrorMessage(
              async.error!,
              fallback: l10n.momentErrorCollectionDetailLoadFailed,
              l10n: l10n,
            ),
          );
        }
        if (!isLoading && state == null) {
          return const SizedBox.shrink();
        }
        // loading 用占位数据渲染同一份真实布局，由 [AppSkeletonizer] 灰化，
        // 骨架与数据到位后的首屏严格同形。
        final displayState = isLoading
            ? momentCollectionDetailPlaceholder()
            : state!;
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
      return content;
    }
    return AppPageRefreshScope(
      onRefresh: ref.read(_providerRef.notifier).refresh,
      child: content,
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
    final l10n = AppLocalizations.of(context);
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
            tooltip: l10n.momentCollectionEditTitle,
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

  /// 成员列表顶栏：桌面玻璃分组，移动端紧凑图标行。
  /// **本页没有筛选维度**——时刻合集是手动顺序，不接筛选入口。
  Widget _buildListHeader(
    BuildContext context,
    MomentCollectionDetailState state,
  ) {
    final hasPoints = state.points.isNotEmpty;
    final l10n = AppLocalizations.of(context);
    if (!_isMobile) {
      return AppGlassListHeader(
        leading: Text(
          l10n.momentCollectionAllMomentsTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        trailing: AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: Key('$_keyPrefix-add-moments-button'),
              icon: Icons.bookmark_add_outlined,
              label: l10n.momentAddMomentsAction,
              onTap: () => _addMoments(context),
            ),
            if (hasPoints)
              AppGlassHeaderButton(
                key: Key('$_keyPrefix-enter-selection-button'),
                icon: Icons.check_circle_outline,
                label: l10n.baseSelect,
                onTap: enterSelection,
              ),
          ],
        ),
      );
    }
    return AppMobileListHeader(
      leading: AppMobileHeaderText(title: l10n.momentCollectionAllMomentsTitle),
      actions: <Widget>[
        AppGlassIconButton(
          key: Key('$_keyPrefix-add-moments-button'),
          tooltip: l10n.momentAddAction,
          icon: Icons.bookmark_add_outlined,
          onPressed: () => _addMoments(context),
        ),
        AppGlassIconButton(
          key: Key('$_keyPrefix-rename-button'),
          tooltip: l10n.momentCollectionEditTitle,
          onPressed: () => _editCollection(context),
          icon: Icons.edit_outlined,
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
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.momentCollectionAdd,
      BatchOperationType.momentCollectionRemove,
      BatchOperationType.mediaPointDelete,
    ]);
    final l10n = AppLocalizations.of(context);
    if (_isMobile) {
      return AppMobileSelectionHeader(
        selectionLabel: l10n.momentSelectedCount(selectedCount),
        exitKey: Key('$_keyPrefix-exit-selection-button'),
        onExitSelection: exitSelection,
        selectAllKey: Key('$_keyPrefix-select-all-button'),
        selectAllTooltip: allSelected
            ? l10n.momentDeselectAll
            : l10n.momentSelectAll,
        onToggleAll: () => toggleSelectAll(pointIds),
      );
    }
    return AppGlassSelectionHeader(
      selectionLabel: l10n.momentSelectedCount(selectedCount),
      selectAllLabel: allSelected
          ? l10n.momentDeselectAll
          : l10n.momentSelectAll,
      selectAllKey: Key('$_keyPrefix-select-all-button'),
      onToggleAll: () => toggleSelectAll(pointIds),
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: Key('$_keyPrefix-batch-remove-button'),
          label: l10n.momentCollectionRemoveAction,
          icon: Icons.playlist_remove_rounded,
          onTap: hasSelection && !submitting ? () => _batchRemove(state) : null,
        ),
        AppGlassSelectionAction(
          key: Key('$_keyPrefix-batch-delete-button'),
          label: l10n.momentDeleteTitle,
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          onTap: hasSelection && !submitting ? () => _batchDelete(state) : null,
        ),
      ],
      exitKey: Key('$_keyPrefix-exit-selection-button'),
      onExitSelection: exitSelection,
    );
  }

  Widget _buildBatchBar(
    BuildContext context,
    MomentCollectionDetailState state,
  ) {
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.momentCollectionAdd,
      BatchOperationType.momentCollectionRemove,
      BatchOperationType.mediaPointDelete,
    ]);
    final l10n = AppLocalizations.of(context);
    return AppSelectionBottomBar(
      key: Key('$_keyPrefix-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('$_keyPrefix-batch-add-collection-button'),
          label: l10n.momentAddToCollection,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('$_keyPrefix-batch-remove-button'),
          label: l10n.momentRemoveAction,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchRemove(state)
              : null,
        ),
        AppButton(
          key: Key('$_keyPrefix-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          onPressed: hasSelection && !submitting
              ? () => _batchDelete(state)
              : null,
        ),
      ],
    );
  }

  // --------------------------------------------------------- body

  Widget _buildPoints(BuildContext context, MomentCollectionDetailState state) {
    if (state.points.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return AppEmptyState(
        message: _isMobile
            ? l10n.momentCollectionEmptyDetailMobile
            : l10n.momentCollectionEmptyDetailDesktop,
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
          orientation: AppCardGridOrientation.landscape,
        );
        return GridView.builder(
          key: Key('$_keyPrefix-detail-grid'),
          // 底部 = 区块留白 + 底部安全区：外壳不吞安全区，多选态底部操作条之上
          // 也要留出 home indicator 的高度。
          padding: _isMobile
              ? EdgeInsets.only(
                  bottom: spacing.lg + MediaQuery.paddingOf(context).bottom,
                )
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
            return _buildGridCard(
              point,
              item,
              context,
              onLongPress: _isMobile && !selectionMode
                  ? () {
                      enterSelection();
                      toggleSelect(point.pointId);
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildGridCard(
    MomentCollectionPointDto point,
    MomentListItem item,
    BuildContext context, {
    VoidCallback? onLongPress,
  }) {
    // 网格统一走「整卡即封面 + 桌面悬停披露」：收起态只留封面，悬停渐显信息与
    // 动作行；移动端没有 hover，收起态同样不铺文字，信息与播放入口走点击后的预览层。
    final canPlay = item.mediaId > 0;
    final l10n = AppLocalizations.of(context);
    return CollectionMemberCard(
      key: ValueKey<int>(point.pointId),
      coverUrl: item.image?.origin,
      coverAspectRatio: 16 / 9,
      title: item.localizedDisplayLabel(l10n),
      subtitle: item.localizedHoverMeta(l10n),
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
      openSourceLabel: l10n.momentSourceMovie,
      openSourceButtonKey: Key('$_keyPrefix-grid-movie-${point.pointId}'),
      onRemove: _isMobile ? null : () => _removePoint(point),
      removeButtonKey: Key('$_keyPrefix-grid-remove-${point.pointId}'),
      onDelete: _isMobile ? null : () => _deletePoint(point),
      deleteButtonKey: Key('$_keyPrefix-grid-delete-${point.pointId}'),
      deleteLabel: l10n.momentDeleteTitle,
      selectionMode: selectionMode,
      onLongPress: onLongPress,
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
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(_providerRef.notifier).removePoint(point.pointId);
      if (!mounted) {
        return;
      }
      // 合集封面 / 计数可能变化，广播给上层合集列表（首页横滑区、全部合集页）。
      _mutationBroadcaster.reportChanged(widget.collectionId);
      showToast(l10n.momentCollectionRemovedToast, tone: AppToastTone.success);
    } catch (error) {
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.momentErrorRemoveFromCollectionFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  /// 彻底删除时刻标记本体（由后端从所有合集级联移除，不可恢复）：先确认，再走
  /// notifier 乐观删除并广播。与「移出合集」不同。
  Future<void> _deletePoint(MomentCollectionPointDto point) async {
    final l10n = AppLocalizations.of(context);
    final item = point.toMomentListItem();
    final confirmed = await _confirm(
      title: l10n.momentDeleteTitle,
      message: l10n.momentDeleteConfirmMessage(
        item.localizedDisplayLabel(l10n),
      ),
      confirmLabel: _isMobile ? l10n.commonDelete : l10n.momentConfirm,
      confirmKey: Key('$_keyPrefix-delete-confirm-button'),
      drawerKey: _isMobile ? Key('$_keyPrefix-delete-drawer') : null,
      onConfirm: () =>
          ref.read(_providerRef.notifier).deletePoint(point.pointId),
    );
    if (!mounted || !confirmed) {
      return;
    }
    _mutationBroadcaster.reportChanged(widget.collectionId);
    showToast(l10n.momentDeletedToast, tone: AppToastTone.success);
  }

  Future<void> _editCollection(BuildContext context) async {
    final collection = ref.read(_providerRef).value?.collection;
    if (collection == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final updated = await showMomentCollectionEditor(
      context,
      collection: collection,
    );
    if (!mounted || updated == null) {
      return;
    }
    ref.read(_providerRef.notifier).replaceCollection(updated);
    _mutationBroadcaster.reportChanged(widget.collectionId);
    showToast(l10n.commonSaved, tone: AppToastTone.success);
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
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.momentCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((point) => point.pointId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchRemove(MomentCollectionDetailState state) async {
    final selected = _selectedPoints(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.momentCollectionRemoveAction,
      message: l10n.momentCollectionBatchRemoveMessage(selected.length),
      confirmLabel: _isMobile ? l10n.momentRemoveAction : l10n.momentConfirm,
      confirmKey: Key('$_keyPrefix-batch-remove-confirm-button'),
      drawerKey: _isMobile ? Key('$_keyPrefix-batch-remove-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.momentCollectionRemove,
      targetCollectionId: widget.collectionId,
      ids: selected.map((point) => point.pointId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchDelete(MomentCollectionDetailState state) async {
    final selected = _selectedPoints(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.momentDeleteTitle,
      message: l10n.momentBatchDeleteConfirmMessage(selected.length),
      confirmLabel: _isMobile ? l10n.commonDelete : l10n.momentConfirm,
      confirmKey: Key('$_keyPrefix-batch-delete-confirm-button'),
      drawerKey: _isMobile ? Key('$_keyPrefix-batch-delete-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.mediaPointDelete,
      ids: selected.map((point) => point.pointId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
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
      failureFallback: AppLocalizations.of(context).momentErrorDeleteFailed,
    );
  }
}
