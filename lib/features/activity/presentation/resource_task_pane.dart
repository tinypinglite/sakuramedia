import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/resource_task_definition_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_record_dto.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_center_controller.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 构建资源任务 Tab 的 sliver 列表。
///
/// 调用方负责把返回的 slivers 放进外层 [CustomScrollView]。
/// 详情抽屉由外层 [buildResourceTaskDetailOverlay] 叠加到 Stack 上。
List<Widget> buildResourceTaskSlivers({
  required BuildContext context,
  required ResourceTaskCenterController controller,
}) {
  if (controller.isInitialLoading) {
    return const <Widget>[
      SliverToBoxAdapter(child: _ResourceTaskInitialLoading()),
    ];
  }

  if (controller.initialErrorMessage != null) {
    return <Widget>[
      SliverToBoxAdapter(
        child: AppEmptyState(
          message: controller.initialErrorMessage!,
          onRetry: () => controller.retryInitialize(),
        ),
      ),
    ];
  }

  if (controller.definitions.isEmpty) {
    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.appSpacing.xxl),
          child: const AppEmptyState(message: '当前没有已注册的资源任务'),
        ),
      ),
    ];
  }

  final slivers = <Widget>[
    SliverToBoxAdapter(
      child: Column(
        key: const Key('activity-resource-tasks-tab'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResourceTaskSubTabBar(controller: controller),
          SizedBox(height: context.appSpacing.lg),
          _ResourceTaskFilterBar(controller: controller),
          if (controller.supportsBatchReset) ...[
            SizedBox(height: context.appSpacing.md),
            _ResourceTaskSelectionBar(controller: controller),
          ],
          if (controller.recordsLoadErrorMessage != null &&
              controller.activeRecords.isNotEmpty) ...[
            SizedBox(height: context.appSpacing.md),
            AppPagedLoadMoreFooter(
              isLoading: false,
              errorMessage: controller.recordsLoadErrorMessage,
              onRetry: controller.refreshRecords,
            ),
          ],
          SizedBox(height: context.appSpacing.lg),
        ],
      ),
    ),
  ];

  if (controller.isLoadingRecords && controller.activeRecords.isEmpty) {
    slivers.add(const SliverToBoxAdapter(child: _ResourceTaskListLoading()));
    return slivers;
  }

  if (controller.recordsLoadErrorMessage != null &&
      controller.activeRecords.isEmpty) {
    slivers.add(
      SliverToBoxAdapter(
        child: AppEmptyState(
          message: controller.recordsLoadErrorMessage!,
          onRetry: () => controller.refreshRecords(),
        ),
      ),
    );
    return slivers;
  }

  if (controller.activeRecords.isEmpty && controller.hasLoadedActiveRecords) {
    slivers.add(
      const SliverToBoxAdapter(child: AppEmptyState(message: '当前筛选下暂无资源任务记录')),
    );
    return slivers;
  }

  slivers.add(
    SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final record = controller.activeRecords[index];
        final isLast = index == controller.activeRecords.length - 1;
        final inSelectionMode = controller.selectionMode;
        final isBatchSelectable = record.isFailed;
        final isBatchSelected = controller.isRecordSelected(record.resourceId);
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.md),
          child: RepaintBoundary(
            child: _ResourceTaskRecordTile(
              record: record,
              isSelected:
                  !inSelectionMode &&
                  controller.selectedRecord?.recordKey == record.recordKey,
              inSelectionMode: inSelectionMode,
              isBatchSelectable: isBatchSelectable,
              isBatchSelected: isBatchSelected,
              onTap: () {
                if (inSelectionMode) {
                  if (!isBatchSelectable) {
                    showToast('仅可重置失败的任务');
                    return;
                  }
                  final ok = controller.toggleRecordSelection(record.resourceId);
                  if (!ok) {
                    showToast(
                      '最多可选 ${ResourceTaskCenterController.maxBatchResetCount} 项',
                    );
                  }
                  return;
                }
                controller.openDetail(record);
              },
            ),
          ),
        );
      }, childCount: controller.activeRecords.length),
    ),
  );

  slivers.add(
    SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(height: context.appSpacing.lg),
          AppPagedLoadMoreFooter(
            isLoading: controller.isLoadingMoreRecords,
            errorMessage: controller.recordsLoadMoreErrorMessage,
            onRetry: controller.loadMoreRecords,
          ),
          SizedBox(height: context.appSpacing.xl),
        ],
      ),
    ),
  );
  return slivers;
}

/// 构建资源任务详情抽屉覆盖层（供外层 Stack 使用）。
///
/// 当没有选中记录时返回 `SizedBox.shrink()`，调用方可以无条件插入 Stack。
Widget buildResourceTaskDetailOverlay({
  required BuildContext context,
  required ResourceTaskCenterController controller,
}) {
  final record = controller.selectedRecord;
  if (record == null) {
    return const SizedBox.shrink();
  }
  return _ResourceTaskDetailDrawer(
    record: record,
    onClose: controller.closeDetail,
  );
}

class _ResourceTaskInitialLoading extends StatelessWidget {
  const _ResourceTaskInitialLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xxl),
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
          ),
        ),
      ),
    );
  }
}

class _ResourceTaskListLoading extends StatelessWidget {
  const _ResourceTaskListLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xl),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
          ),
        ),
      ),
    );
  }
}

class _ResourceTaskSubTabBar extends StatelessWidget {
  const _ResourceTaskSubTabBar({required this.controller});

  final ResourceTaskCenterController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final definition in controller.definitions) ...[
            _ResourceTaskSubTab(
              definition: definition,
              isActive: controller.activeTaskKey == definition.taskKey,
              onTap: () => controller.selectTaskKey(definition.taskKey),
            ),
            SizedBox(width: context.appSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ResourceTaskSubTab extends StatelessWidget {
  const _ResourceTaskSubTab({
    required this.definition,
    required this.isActive,
    required this.onTap,
  });

  final ResourceTaskDefinitionDto definition;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final counts = definition.stateCounts;
    final badgeTone =
        counts.failed > 0
            ? AppBadgeTone.error
            : counts.running > 0
            ? AppBadgeTone.warning
            : AppBadgeTone.neutral;
    final badgeCount =
        counts.failed > 0
            ? counts.failed
            : counts.running > 0
            ? counts.running
            : counts.total;

    return InkWell(
      onTap: onTap,
      borderRadius: context.appRadius.pillBorder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.md,
          vertical: context.appSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.selectionSurface : colors.surfaceMuted,
          borderRadius: context.appRadius.pillBorder,
          border: Border.all(
            color:
                isActive ? context.appTextPalette.accent : colors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              definition.displayName.isEmpty
                  ? definition.taskKey
                  : definition.displayName,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.tertiary,
              ).copyWith(
                color:
                    isActive
                        ? context.appTextPalette.accent
                        : context.appTextPalette.secondary,
              ),
            ),
            if (counts.total > 0) ...[
              SizedBox(width: context.appSpacing.sm),
              AppBadge(
                label: '$badgeCount',
                tone: badgeTone,
                size: AppBadgeSize.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResourceTaskFilterBar extends StatefulWidget {
  const _ResourceTaskFilterBar({required this.controller});

  final ResourceTaskCenterController controller;

  @override
  State<_ResourceTaskFilterBar> createState() => _ResourceTaskFilterBarState();
}

class _ResourceTaskFilterBarState extends State<_ResourceTaskFilterBar> {
  late final TextEditingController _searchController;
  String _attachedFilterSearch = '';

  @override
  void initState() {
    super.initState();
    final initialSearch = widget.controller.filter.search;
    _attachedFilterSearch = initialSearch;
    _searchController = TextEditingController(text: initialSearch);
  }

  @override
  void didUpdateWidget(covariant _ResourceTaskFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换 task_key 时，filter 可能来自另一个 bucket；用 _attachedFilterSearch
    // 跟踪上一次已经同步到输入框的值，避免用户正在输入时被外部覆盖。
    final currentSearch = widget.controller.filter.search;
    if (currentSearch != _attachedFilterSearch &&
        currentSearch != _searchController.text) {
      _searchController.text = currentSearch;
    }
    _attachedFilterSearch = currentSearch;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch(String value) async {
    final next = widget.controller.filter.copyWith(search: value);
    _attachedFilterSearch = value;
    await widget.controller.applyFilter(next);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final layoutTokens = context.appLayoutTokens;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );
    final isLoading = controller.isLoadingRecords;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<ResourceTaskRecordStateFilter>(
            key: const Key('resource-task-state-filter'),
            value: controller.filter.stateFilter,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: ResourceTaskRecordStateFilter.values
                .map(
                  (value) => DropdownMenuItem<ResourceTaskRecordStateFilter>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged:
                isLoading
                    ? null
                    : (value) => controller.applyFilter(
                      controller.filter.copyWith(
                        stateFilter: value ?? ResourceTaskRecordStateFilter.all,
                      ),
                    ),
          ),
        ),
        SizedBox(
          width: layoutTokens.filterFieldWidthLg,
          child: AppTextField(
            fieldKey: const Key('resource-task-search-field'),
            controller: _searchController,
            hintText: '搜索影片番号或标题',
            textInputAction: TextInputAction.search,
            onFieldSubmitted: _submitSearch,
            enabled: !isLoading,
          ),
        ),
        SizedBox(
          width: layoutTokens.filterFieldWidthXl,
          child: AppSelectField<ResourceTaskRecordSort>(
            key: const Key('resource-task-sort-filter'),
            value: controller.filter.sort,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: ResourceTaskRecordSort.values
                .map(
                  (value) => DropdownMenuItem<ResourceTaskRecordSort>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged:
                isLoading
                    ? null
                    : (value) => controller.applyFilter(
                      controller.filter.copyWith(
                        sort: value ?? ResourceTaskRecordSort.backendDefault,
                      ),
                    ),
          ),
        ),
        _FilterLoadingDot(isVisible: isLoading),
      ],
    );
  }
}

class _FilterLoadingDot extends StatelessWidget {
  const _FilterLoadingDot({required this.isVisible});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child:
            isVisible
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2.2),
                )
                : null,
      ),
    );
  }
}

class _ResourceTaskSelectionBar extends StatelessWidget {
  const _ResourceTaskSelectionBar({required this.controller});

  final ResourceTaskCenterController controller;

  Future<void> _handleConfirmReset(BuildContext context) async {
    final selectedCount = controller.selectedCount;
    if (selectedCount == 0) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '重置生成状态',
      message: '将把选中的 $selectedCount 条媒体缩略图生成任务重置为待处理，后台会重新排队生成。',
      confirmLabel: '重置',
      dialogKey: const Key('resource-task-batch-reset-dialog'),
      confirmKey: const Key('resource-task-batch-reset-confirm'),
      failureFallback: '重置失败，请稍后重试',
      onConfirm: () async {
        await controller.resetSelectedFailed();
      },
    );
    if (confirmed) {
      showToast('已重置 $selectedCount 条');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.selectionMode) {
      return _ResourceTaskSelectionEntryRow(controller: controller);
    }
    final spacing = context.appSpacing;
    final failedCount = controller.visibleFailedCount;
    final allSelected = controller.isAllVisibleFailedSelected;
    final hasSelection = controller.hasSelection;
    final isBusy = controller.isResetting;

    return Row(
      children: [
        Text(
          '已选 ${controller.selectedCount} 个',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        const Spacer(),
        AppTextButton(
          key: const Key('resource-task-select-all-button'),
          label: allSelected ? '取消全选' : '全选',
          size: AppTextButtonSize.small,
          onPressed:
              (isBusy || failedCount == 0)
                  ? null
                  : controller.toggleSelectAllVisibleFailed,
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('resource-task-batch-reset-button'),
          label: '重置生成状态',
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          isLoading: isBusy,
          onPressed:
              (!hasSelection || isBusy) ? null : () => _handleConfirmReset(context),
        ),
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: const Key('resource-task-exit-selection-button'),
          label: '取消',
          size: AppTextButtonSize.small,
          onPressed: isBusy ? null : controller.exitSelectionMode,
        ),
      ],
    );
  }
}

class _ResourceTaskSelectionEntryRow extends StatelessWidget {
  const _ResourceTaskSelectionEntryRow({required this.controller});

  final ResourceTaskCenterController controller;

  @override
  Widget build(BuildContext context) {
    final canEnter = controller.visibleFailedCount > 0;
    return Row(
      children: [
        const Spacer(),
        AppTextButton(
          key: const Key('resource-task-enter-selection-button'),
          label: '选择',
          size: AppTextButtonSize.small,
          icon: const Icon(Icons.check_circle_outline, size: 16),
          onPressed: canEnter ? controller.enterSelectionMode : null,
        ),
      ],
    );
  }
}

/// 与 [SelectionCheckBadge] 同尺寸，但用 sakura 品牌 `appTextPalette.accent`
/// 而非历史 `selectionBorder`(Ant 蓝)。仅本文件用。
class _AccentCheckBadge extends StatelessWidget {
  const _AccentCheckBadge({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? context.appTextPalette.accent
            : Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}

class _ResourceTaskRecordTile extends StatelessWidget {
  const _ResourceTaskRecordTile({
    required this.record,
    required this.isSelected,
    required this.onTap,
    this.inSelectionMode = false,
    this.isBatchSelectable = false,
    this.isBatchSelected = false,
  });

  final ResourceTaskRecordDto record;
  final bool isSelected;
  final VoidCallback onTap;
  final bool inSelectionMode;
  final bool isBatchSelectable;
  final bool isBatchSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resource = record.resource;
    final titleText =
        resource?.movieNumber?.trim().isNotEmpty == true
            ? resource!.movieNumber!
            : (resource?.title?.trim().isNotEmpty == true
                ? resource!.title!
                : '资源 #${record.resourceId}');
    final subtitleText =
        resource?.title?.trim().isNotEmpty == true &&
                resource!.title != titleText
            ? resource.title!
            : null;
    final lastAttempted = record.lastAttemptedAt;
    final lastAttemptedLabel = formatUpdatedAtLabel(lastAttempted);
    final timeLabel =
        lastAttemptedLabel != null ? '最近尝试 $lastAttemptedLabel' : '尚未执行';
    final showAsBatchSelected = inSelectionMode && isBatchSelected;
    final dimmed = inSelectionMode && !isBatchSelectable;
    // sakura 品牌选中色统一走 palette accent（0xFF6B2D2A 樱酒红），
    // 不复用 selectionBorder(Ant 蓝)——参考 AppLeftCoverCard 里的说明。
    final borderColor = (showAsBatchSelected || isSelected)
        ? context.appTextPalette.accent
        : colors.borderSubtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.appRadius.mdBorder,
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: Container(
            key: Key('resource-task-record-${record.recordKey}'),
            width: double.infinity,
            padding: EdgeInsets.all(context.appSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: context.appRadius.mdBorder,
              border: Border.all(
                color: borderColor,
                width: showAsBatchSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (inSelectionMode) ...[
                      Padding(
                        padding: EdgeInsets.only(right: context.appSpacing.md),
                        child: _AccentCheckBadge(isSelected: isBatchSelected),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s14,
                              weight: AppTextWeight.regular,
                              tone: AppTextTone.secondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (subtitleText != null) ...[
                          SizedBox(height: context.appSpacing.xs),
                          Text(
                            subtitleText,
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s14,
                              weight: AppTextWeight.regular,
                              tone: AppTextTone.secondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: context.appSpacing.md),
                  AppBadge(
                    label: _labelForResourceTaskState(record.state),
                    tone: _toneForResourceTaskState(record.state),
                  ),
                ],
              ),
              SizedBox(height: context.appSpacing.md),
              Wrap(
                spacing: context.appSpacing.sm,
                runSpacing: context.appSpacing.sm,
                children: [
                  AppBadge(
                    label: '尝试 ${record.attemptCount} 次',
                    tone: AppBadgeTone.neutral,
                    size: AppBadgeSize.compact,
                  ),
                  if ((record.lastTriggerType ?? '').trim().isNotEmpty)
                    AppBadge(
                      label: _labelForResourceTaskTrigger(
                        record.lastTriggerType!,
                      ),
                      tone: AppBadgeTone.neutral,
                      size: AppBadgeSize.compact,
                    ),
                  if (resource?.path != null) ...[
                    SizedBox(
                      width: 260,
                      child: Text(
                        resource!.path!,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  Text(
                    timeLabel,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
              if (record.isFailed &&
                  (record.lastError ?? '').trim().isNotEmpty) ...[
                SizedBox(height: context.appSpacing.md),
                Text(
                  record.lastError!,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _ResourceTaskDetailDrawer extends StatelessWidget {
  const _ResourceTaskDetailDrawer({
    required this.record,
    required this.onClose,
  });

  final ResourceTaskRecordDto record;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resource = record.resource;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(
              color: colors.mediaOverlayStrong.withValues(alpha: 0.2),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            heightFactor: 1,
            widthFactor: 0.4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 360, maxWidth: 520),
              child: Container(
                key: const Key('resource-task-detail-drawer'),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  border: Border(left: BorderSide(color: colors.borderStrong)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.appSpacing.lg,
                        context.appSpacing.lg,
                        context.appSpacing.sm,
                        context.appSpacing.md,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _drawerTitle(record),
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s18,
                                weight: AppTextWeight.semibold,
                                tone: AppTextTone.primary,
                              ),
                            ),
                          ),
                          AppIconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClose,
                            tooltip: '关闭',
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.borderSubtle),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(context.appSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AppBadge(
                                  label: _labelForResourceTaskState(
                                    record.state,
                                  ),
                                  tone: _toneForResourceTaskState(record.state),
                                ),
                                SizedBox(width: context.appSpacing.sm),
                                AppBadge(
                                  label: '尝试 ${record.attemptCount} 次',
                                  tone: AppBadgeTone.neutral,
                                  size: AppBadgeSize.compact,
                                ),
                              ],
                            ),
                            SizedBox(height: context.appSpacing.lg),
                            _DetailSection(
                              title: '资源信息',
                              rows: <_DetailRow>[
                                _DetailRow('资源 ID', '${record.resourceId}'),
                                if ((resource?.movieNumber ?? '').isNotEmpty)
                                  _DetailRow('影片番号', resource!.movieNumber!),
                                if ((resource?.title ?? '').isNotEmpty)
                                  _DetailRow('标题', resource!.title!),
                                if ((resource?.path ?? '').isNotEmpty)
                                  _DetailRow('路径', resource!.path!),
                                if (resource?.valid != null)
                                  _DetailRow(
                                    '是否有效',
                                    resource!.valid! ? '是' : '否',
                                  ),
                              ],
                            ),
                            SizedBox(height: context.appSpacing.lg),
                            _DetailSection(
                              title: '任务执行',
                              rows: <_DetailRow>[
                                _DetailRow(
                                  '最近尝试',
                                  formatUpdatedAtLabel(
                                        record.lastAttemptedAt,
                                      ) ??
                                      '—',
                                ),
                                _DetailRow(
                                  '最近成功',
                                  formatUpdatedAtLabel(
                                        record.lastSucceededAt,
                                      ) ??
                                      '—',
                                ),
                                _DetailRow(
                                  '最近失败',
                                  formatUpdatedAtLabel(record.lastErrorAt) ??
                                      '—',
                                ),
                                _DetailRow(
                                  '触发来源',
                                  (record.lastTriggerType ?? '').isEmpty
                                      ? '未知'
                                      : _labelForResourceTaskTrigger(
                                        record.lastTriggerType!,
                                      ),
                                ),
                                if (record.lastTaskRunId != null)
                                  _DetailRow(
                                    '最近批次 ID',
                                    '#${record.lastTaskRunId}',
                                  ),
                                _DetailRow(
                                  '创建时间',
                                  formatUpdatedAtLabel(record.createdAt) ??
                                      '—',
                                ),
                                _DetailRow(
                                  '更新时间',
                                  formatUpdatedAtLabel(record.updatedAt) ??
                                      '—',
                                ),
                              ],
                            ),
                            if ((record.lastError ?? '').trim().isNotEmpty) ...[
                              SizedBox(height: context.appSpacing.lg),
                              Text(
                                '最近错误',
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s12,
                                  weight: AppTextWeight.regular,
                                  tone: AppTextTone.secondary,
                                ),
                              ),
                              SizedBox(height: context.appSpacing.sm),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(context.appSpacing.md),
                                decoration: BoxDecoration(
                                  color: colors.errorSurface,
                                  borderRadius: context.appRadius.smBorder,
                                ),
                                child: SelectableText(
                                  record.lastError!,
                                  style: resolveAppTextStyle(
                                    context,
                                    size: AppTextSize.s12,
                                    weight: AppTextWeight.regular,
                                    tone: AppTextTone.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _drawerTitle(ResourceTaskRecordDto record) {
    final resource = record.resource;
    if ((resource?.movieNumber ?? '').isNotEmpty) {
      return resource!.movieNumber!;
    }
    if ((resource?.title ?? '').isNotEmpty) {
      return resource!.title!;
    }
    return '资源 #${record.resourceId}';
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        for (var i = 0; i < rows.length; i++) ...[
          _DetailRowTile(row: rows[i]),
          if (i != rows.length - 1) SizedBox(height: context.appSpacing.xs),
        ],
      ],
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
}

class _DetailRowTile extends StatelessWidget {
  const _DetailRowTile({required this.row});

  final _DetailRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            row.label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            row.value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.primary,
            ),
          ),
        ),
      ],
    );
  }
}

String _labelForResourceTaskState(String state) {
  return switch (state) {
    'pending' => '待处理',
    'running' => '运行中',
    'succeeded' => '已成功',
    'failed' => '失败',
    _ => state.isEmpty ? '未知' : state,
  };
}

AppBadgeTone _toneForResourceTaskState(String state) {
  return switch (state) {
    'failed' => AppBadgeTone.error,
    'succeeded' => AppBadgeTone.success,
    'running' => AppBadgeTone.primary,
    'pending' => AppBadgeTone.warning,
    _ => AppBadgeTone.neutral,
  };
}

String _labelForResourceTaskTrigger(String value) {
  return switch (value) {
    'scheduled' => '定时触发',
    'manual' => '手动触发',
    'startup' => '启动触发',
    'internal' => '内部触发',
    _ => value,
  };
}
