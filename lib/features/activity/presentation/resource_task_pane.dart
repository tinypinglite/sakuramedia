import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sakuramedia/features/activity/data/resource_task_definition_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_record_dto.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_center_controller.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

/// 构建资源任务 Tab 的 sliver 列表。
///
/// 调用方负责把返回的 slivers 放进外层 [CustomScrollView]。
/// 详情抽屉由外层 [buildResourceTaskDetailOverlay] 叠加到 Stack 上。
List<Widget> buildResourceTaskSlivers({
  required BuildContext context,
  required ResourceTaskCenterController controller,
  required DateFormat dateFormat,
}) {
  if (controller.isInitialLoading) {
    return const <Widget>[
      SliverToBoxAdapter(child: _ResourceTaskInitialLoading()),
    ];
  }

  if (controller.initialErrorMessage != null) {
    return <Widget>[
      SliverToBoxAdapter(
        child: _ResourceTaskInitialError(
          message: controller.initialErrorMessage!,
          onRetry: controller.retryInitialize,
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
        child: _ResourceTaskListError(
          message: controller.recordsLoadErrorMessage!,
          onRetry: controller.refreshRecords,
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
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.md),
          child: RepaintBoundary(
            child: _ResourceTaskRecordTile(
              record: record,
              dateFormat: dateFormat,
              isSelected:
                  controller.selectedRecord?.recordKey == record.recordKey,
              onTap: () => controller.openDetail(record),
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
  required DateFormat dateFormat,
}) {
  final record = controller.selectedRecord;
  if (record == null) {
    return const SizedBox.shrink();
  }
  return _ResourceTaskDetailDrawer(
    record: record,
    dateFormat: dateFormat,
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

class _ResourceTaskInitialError extends StatelessWidget {
  const _ResourceTaskInitialError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        Center(child: AppButton(label: '重试', onPressed: () => onRetry())),
      ],
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

class _ResourceTaskListError extends StatelessWidget {
  const _ResourceTaskListError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.lg,
        vertical: context.appSpacing.xl,
      ),
      child: Column(
        children: [
          AppEmptyState(message: message),
          SizedBox(height: context.appSpacing.md),
          AppButton(label: '重试', onPressed: () => onRetry()),
        ],
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
    final theme = Theme.of(context);
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
            color: isActive ? colors.selectionForeground : colors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              definition.displayName.isEmpty
                  ? definition.taskKey
                  : definition.displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color:
                    isActive
                        ? colors.selectionForeground
                        : colors.textSecondary,
                fontWeight: FontWeight.w700,
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
    final filterTextStyle = Theme.of(context).textTheme.labelMedium;
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

class _ResourceTaskRecordTile extends StatelessWidget {
  const _ResourceTaskRecordTile({
    required this.record,
    required this.dateFormat,
    required this.isSelected,
    required this.onTap,
  });

  final ResourceTaskRecordDto record;
  final DateFormat dateFormat;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
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
    final timeLabel =
        lastAttempted != null
            ? '最近尝试 ${dateFormat.format(lastAttempted.toLocal())}'
            : '尚未执行';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.appRadius.mdBorder,
        child: Container(
          key: Key('resource-task-record-${record.recordKey}'),
          width: double.infinity,
          padding: EdgeInsets.all(context.appSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(
              color:
                  isSelected ? colors.selectionForeground : colors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitleText != null) ...[
                          SizedBox(height: context.appSpacing.xs),
                          Text(
                            subtitleText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  Text(
                    timeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
              if (record.isFailed &&
                  (record.lastError ?? '').trim().isNotEmpty) ...[
                SizedBox(height: context.appSpacing.md),
                Text(
                  record.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.errorForeground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceTaskDetailDrawer extends StatelessWidget {
  const _ResourceTaskDetailDrawer({
    required this.record,
    required this.dateFormat,
    required this.onClose,
  });

  final ResourceTaskRecordDto record;
  final DateFormat dateFormat;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
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
                                  _formatDate(
                                    record.lastAttemptedAt,
                                    dateFormat,
                                  ),
                                ),
                                _DetailRow(
                                  '最近成功',
                                  _formatDate(
                                    record.lastSucceededAt,
                                    dateFormat,
                                  ),
                                ),
                                _DetailRow(
                                  '最近失败',
                                  _formatDate(record.lastErrorAt, dateFormat),
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
                                  _formatDate(record.createdAt, dateFormat),
                                ),
                                _DetailRow(
                                  '更新时间',
                                  _formatDate(record.updatedAt, dateFormat),
                                ),
                              ],
                            ),
                            if ((record.lastError ?? '').trim().isNotEmpty) ...[
                              SizedBox(height: context.appSpacing.lg),
                              Text(
                                '最近错误',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textSecondary,
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
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.errorForeground,
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
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
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
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            row.label,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ),
        Expanded(
          child: SelectableText(
            row.value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime? value, DateFormat formatter) {
  if (value == null) {
    return '—';
  }
  return formatter.format(value.toLocal());
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
