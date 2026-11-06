import 'package:sakuramedia/core/network/api_error_message.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_placeholders.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_delete_dialog.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_files_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';

/// 构建「下载任务」页的头部。
///
/// 调用方负责把列表 slivers 放进外层滚动视图。
Widget buildDownloadTaskHeader({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onManualAdd,
}) {
  // 只订阅头部渲染所需的字段：进度轮询 tick 不重建头部。
  final header = ref.watch(
    downloadTaskCenterProvider.select((asyncState) {
      final state = asyncState.value;
      return (
        selectionMode: state?.selectionMode ?? false,
        selectionCount: state?.selectionCount ?? 0,
        loadedCount: state?.paged.items.length ?? 0,
        hasSelection: state?.hasSelection ?? false,
        filterUpdate:
            state?.paged.filterUpdate ?? const FilterUpdateState.idle(),
        hasItems: state?.paged.items.isNotEmpty ?? false,
        filter: state?.filter ?? DownloadTaskFilterState.initial,
        clientOptions: state?.clientOptions ?? const <DownloadClientOption>[],
      );
    }),
  );
  final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
  // 首次加载也渲染初始筛选栏：骨架列表与数据回来后的最终布局保持一致，
  // 避免头部突然多出一行导致内容下跳。
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (header.selectionMode)
        isMobile
            ? _MobileSelectionHeader(
                selectionCount: header.selectionCount,
                loadedCount: header.loadedCount,
              )
            : _DesktopSelectionHeader(
                selectionCount: header.selectionCount,
                loadedCount: header.loadedCount,
              )
      else if (isMobile)
        _DownloadFilterBar(
          filter: header.filter,
          clientOptions: header.clientOptions,
          hasItems: header.hasItems,
          onManualAdd: onManualAdd,
        )
      else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DownloadFilterBar(
                filter: header.filter,
                clientOptions: header.clientOptions,
                hasItems: header.hasItems,
                onManualAdd: onManualAdd,
              ),
            ),
            SizedBox(width: context.appSpacing.md),
            _buildManualAddAction(context, onManualAdd, isMobile: false),
            SizedBox(width: context.appSpacing.sm),
            AppSelectionEntryButton(
              key: const Key('download-tasks-selection-entry'),
              onPressed: header.loadedCount == 0
                  ? null
                  : () => ref
                        .read(downloadTaskCenterProvider.notifier)
                        .enterSelectionMode(),
            ),
          ],
        ),
      AppFilterUpdateBar(
        key: const Key('download-tasks-reloading-indicator'),
        state: header.filterUpdate,
        hasPreviousItems: header.hasItems,
        onRetry: () => unawaited(
          ref.read(downloadTaskCenterProvider.notifier).retryFilter(),
        ),
      ),
      SizedBox(height: context.appSpacing.lg),
    ],
  );
}

Widget _buildManualAddAction(
  BuildContext context,
  VoidCallback onManualAdd, {
  required bool isMobile,
}) {
  final l10n = AppLocalizations.of(context);
  if (isMobile) {
    return AppIconButton(
      key: const Key('download-tasks-manual-add'),
      tooltip: l10n.downloadManualAddTitle,
      icon: const Icon(Icons.add_rounded),
      onPressed: onManualAdd,
    );
  }
  return AppButton(
    key: const Key('download-tasks-manual-add'),
    label: l10n.downloadManualAddAction,
    icon: const Icon(Icons.add_rounded),
    size: AppButtonSize.small,
    variant: AppButtonVariant.primary,
    onPressed: onManualAdd,
  );
}

/// 移动端多选态把页面内容包成「列表 + 贴底批量操作条」；桌面或非多选态原样返回。
///
/// 下载 tab 的多选动作在桌面顶栏、移动贴底条，两处不共存。只在调用方确认当前是
/// 下载 tab 时调用，避免提前初始化下载任务 Provider。
Widget wrapDownloadTaskSelectionBar({
  required BuildContext context,
  required WidgetRef ref,
  required Widget child,
}) {
  if (AppPlatformScope.maybeOf(context) != AppPlatform.mobile) return child;
  final selectionMode = ref.watch(
    downloadTaskCenterProvider.select(
      (asyncState) => asyncState.value?.selectionMode ?? false,
    ),
  );
  if (!selectionMode) return child;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: child),
      const _MobileSelectionBar(),
    ],
  );
}

/// 桌面多选态顶栏：原地改写筛选行，批量动作与移动贴底条共用。
class _DesktopSelectionHeader extends ConsumerWidget {
  const _DesktopSelectionHeader({
    required this.selectionCount,
    required this.loadedCount,
  });

  final int selectionCount;
  final int loadedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(downloadTaskCenterProvider.notifier);
    final allSelected = loadedCount > 0 && selectionCount >= loadedCount;
    return AppSelectionHeaderToolbar(
      key: const Key('download-tasks-selection-header'),
      countLabel: l10n.downloadSelectionCount(selectionCount),
      countKey: const Key('download-tasks-selection-count'),
      selectAllLabel: allSelected
          ? l10n.downloadSelectionClearAll
          : l10n.downloadSelectionSelectAll(loadedCount),
      selectAllKey: const Key('download-tasks-select-all-button'),
      onToggleAll: loadedCount == 0 ? null : notifier.toggleSelectAllLoaded,
      exitKey: const Key('download-tasks-selection-exit'),
      onExit: notifier.exitSelectionMode,
      actions: <Widget>[
        _buildBatchDeleteButton(
          context,
          ref,
          selectionCount,
          size: AppButtonSize.small,
        ),
      ],
    );
  }
}

/// 移动端多选态顶栏：与订阅管理 / PornBox 的 `AppListHeader.selection` 同一套，
/// 危险动作下沉到贴底条 [_MobileSelectionBar]。
class _MobileSelectionHeader extends ConsumerWidget {
  const _MobileSelectionHeader({
    required this.selectionCount,
    required this.loadedCount,
  });

  final int selectionCount;
  final int loadedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(downloadTaskCenterProvider.notifier);
    final allSelected = loadedCount > 0 && selectionCount >= loadedCount;
    return AppListHeader.selection(
      key: const Key('download-tasks-selection-header'),
      selectionLabel: l10n.downloadSelectionCount(selectionCount),
      selectionExitButtonKey: const Key('download-tasks-selection-exit'),
      onExitSelection: notifier.exitSelectionMode,
      actionSlots: <Widget>[
        AppTextButton(
          key: const Key('download-tasks-select-all-button'),
          label: allSelected
              ? l10n.downloadSelectionClearAll
              : l10n.downloadSelectionSelectAll(loadedCount),
          size: AppTextButtonSize.small,
          onPressed: loadedCount == 0 ? null : notifier.toggleSelectAllLoaded,
        ),
      ],
    );
  }
}

/// 移动端贴底批量操作条：危险动作放在拇指够得到的地方。
class _MobileSelectionBar extends ConsumerWidget {
  const _MobileSelectionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionCount = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) => asyncState.value?.selectionCount ?? 0,
      ),
    );
    return AppSelectionBottomBar(
      actions: <Widget>[_buildBatchDeleteButton(context, ref, selectionCount)],
    );
  }
}

Widget _buildBatchDeleteButton(
  BuildContext context,
  WidgetRef ref,
  int selectionCount, {
  AppButtonSize size = AppButtonSize.medium,
}) {
  final l10n = AppLocalizations.of(context);
  final submitting = watchBatchOperationSubmitting(ref, const [
    BatchOperationType.downloadTaskDelete,
  ]);
  return AppButton(
    key: const Key('download-tasks-batch-delete-button'),
    label: l10n.downloadSelectionDelete(selectionCount),
    size: size,
    variant: AppButtonVariant.danger,
    icon: const Icon(Icons.delete_outline_rounded),
    onPressed: selectionCount > 0 && !submitting
        ? () => unawaited(_deleteSelectedTasks(context, ref))
        : null,
  );
}

/// 批量删除所选下载任务：确认后提交后端批量操作任务，进度与结果在活动中心查看。
Future<void> _deleteSelectedTasks(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(downloadTaskCenterProvider.notifier);
  final tasks = notifier.selectedLoadedTasks();
  if (tasks.isEmpty) return;
  final deleteFiles = await showDownloadTaskDeleteDialog(context, tasks: tasks);
  if (!context.mounted || deleteFiles == null) return;
  final submitted = await submitBatchOperation(
    context,
    ref,
    operation: BatchOperationType.downloadTaskDelete,
    ids: tasks.map((task) => task.id).toList(growable: false),
    deleteFiles: deleteFiles,
  );
  if (!context.mounted) return;
  if (submitted) notifier.exitSelectionMode();
}

/// 单条删除保持同步：确认后在弹窗内等待删除接口完成，成功才关闭弹窗。
Future<void> _deleteTask(
  BuildContext context,
  WidgetRef ref,
  DownloadTaskDto task,
) async {
  final notifier = ref.read(downloadTaskCenterProvider.notifier);
  await showDownloadTaskDeleteDialog(
    context,
    tasks: [task],
    onConfirm: (deleteFiles) =>
        notifier.deleteTask(task.id, deleteFiles: deleteFiles),
  );
}

List<Widget> buildDownloadTaskSlivers({required VoidCallback onManualAdd}) {
  // 列表本体与页脚各自独立订阅：进度 tick 只重建变化的行，
  // 翻页状态翻转只重建页脚，不重建整个列表。
  return <Widget>[
    _DownloadTasksBodySliver(onManualAdd: onManualAdd),
    // 无更多且无失败时不占位；「还有更多」时页脚常驻（空闲也留好间距）。
    // 空列表与页脚互斥：hasMore 但 items 为空时渲染的是空态文案
    // （见 _DownloadTasksBodySliver），不再出现「加载更多」。
    PagedLoadMoreFooterSliver(
      topSpacing: PagedFooterSpacing.lg,
      padWhenIdle: true,
      bottomSpacing: PagedFooterSpacing.xl,
      watchFooter: (ref) => ref.watch(
        downloadTaskCenterProvider.select((asyncState) {
          final paged = asyncState.value?.paged;
          if (paged == null ||
              paged.items.isEmpty ||
              (!paged.hasMore && paged.loadMoreErrorMessage == null)) {
            return null;
          }
          return (
            isLoading: paged.isLoadingMore,
            errorMessage: paged.loadMoreErrorMessage,
          );
        }),
      ),
      onLoadMore: (ref) =>
          unawaited(ref.read(downloadTaskCenterProvider.notifier).loadMore()),
    ),
  ];
}

/// 按 task id 取行快照（行卡独立订阅用）；缺失返回 null，调用方回退 prop。
DownloadTaskRowState? _rowById(DownloadTaskCenterState? state, int taskId) {
  final items = state?.paged.items;
  if (items == null) return null;
  for (final row in items) {
    if (row.task.id == taskId) return row;
  }
  return null;
}

/// 下载任务列表本体：只订阅结构（条目 id 序列）与四态。
///
/// 进度 tick 只改变行内数据（条目序列不变），不重建列表；
/// 各行通过 [_DownloadTaskCard] 独立订阅自己的行状态。
class _DownloadTasksBodySliver extends ConsumerWidget {
  const _DownloadTasksBodySliver({required this.onManualAdd});

  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(
      downloadTaskCenterProvider.select((asyncState) {
        final state = asyncState.value;
        return (
          isLoading: asyncState.isLoading,
          hasValue: asyncState.hasValue,
          hasError: asyncState.hasError,
          error: asyncState.error,
          ids: state?.paged.items.map((row) => row.task.id).join(','),
          filterUpdate:
              state?.paged.filterUpdate ?? const FilterUpdateState.idle(),
          isEmpty: state?.paged.items.isEmpty ?? true,
          stateFilter:
              state?.filter.stateFilter ?? DownloadTaskStateFilter.downloading,
          hasSearchOrClientFilter:
              (state?.filter.normalizedSearch.isNotEmpty ?? false) ||
              (state?.filter.clientId != null),
        );
      }),
    );

    if (body.isLoading && !body.hasValue) {
      // loading 用占位任务渲染真实任务卡，由 [AppSkeletonizer] 灰化。
      // 按视口高度补足卡片数量，避免高窗口下骨架只占上方一小块。
      final cardExtent =
          context.appComponentTokens.downloadTaskCardMinHeight +
          context.appSpacing.md;
      final placeholderCount = (MediaQuery.sizeOf(context).height / cardExtent)
          .ceil()
          .clamp(3, 8)
          .toInt();
      final placeholders = downloadTaskPlaceholders(
        count: placeholderCount,
        l10n: AppLocalizations.of(context),
      );
      return AppSkeletonizer.sliver(
        enabled: true,
        child: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final isLast = index == placeholders.length - 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : context.appSpacing.md,
              ),
              child: RepaintBoundary(
                child: _DownloadTaskCard(row: placeholders[index]),
              ),
            );
          }, childCount: placeholders.length),
        ),
      );
    }
    if (body.hasError && !body.hasValue) {
      final l10n = AppLocalizations.of(context);
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: apiErrorMessage(
            body.error!,
            fallback: l10n.errorDownloadTaskLoadFailed,
            l10n: l10n,
          ),
          onRetry: () => ref.invalidate(downloadTaskCenterProvider),
        ),
      );
    }

    // 条目快照只读不订阅：结构变化（增删/重排）时本体重建，快照即新；
    // 进度 tick 不重建本体，各行独立订阅（见 _DownloadTaskCard）。
    final items =
        ref.read(downloadTaskCenterProvider).value?.paged.items ??
        const <DownloadTaskRowState>[];
    if (items.isEmpty) {
      if (body.filterUpdate.hasFailed) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      // 独立下载页默认只看「下载中」：空态必须给一个出口，否则只有已完成任务的
      // 用户会以为列表是空的。
      final l10n = AppLocalizations.of(context);
      final hasFilter =
          body.stateFilter != DownloadTaskStateFilter.all ||
          body.hasSearchOrClientFilter;
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: hasFilter ? l10n.downloadEmptyFiltered : l10n.downloadEmpty,
          icon: hasFilter ? Icons.search_off_rounded : Icons.download_outlined,
          onRetry: hasFilter
              ? () => unawaited(
                  ref
                      .read(downloadTaskCenterProvider.notifier)
                      .applyFilter(
                        const DownloadTaskFilterState(
                          stateFilter: DownloadTaskStateFilter.all,
                        ),
                      ),
                )
              : onManualAdd,
          retryLabel: hasFilter
              ? l10n.downloadViewAllTasks
              : l10n.downloadManualAddAction,
          retryKey: hasFilter
              ? const Key('download-empty-view-all')
              : const Key('download-empty-manual-add'),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final row = items[index];
        final isLast = index == items.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.md),
          child: RepaintBoundary(child: _DownloadTaskCard(row: row)),
        );
      }, childCount: items.length),
    );
  }
}

class _DownloadTaskCard extends ConsumerWidget {
  const _DownloadTaskCard({required this.row});

  final DownloadTaskRowState row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final taskId = row.task.id;
    // 行内数据独立订阅：进度 tick 只重建本行，不重建整个列表。
    // 首屏骨架的占位行在 provider 无 value 时回退到传入的 row。
    final liveRow = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) => _rowById(asyncState.value, taskId),
      ),
    );
    final selection = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) => (
          mode: asyncState.value?.selectionMode ?? false,
          selected: asyncState.value?.isSelected(taskId) ?? false,
          pending: asyncState.value?.isTaskPending(taskId) ?? false,
        ),
      ),
    );
    final task = liveRow?.task ?? row.task;
    final clientName = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) => asyncState.value?.clientNames[task.clientId],
      ),
    );
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final progress = (liveRow?.progress ?? row.progress).clamp(0.0, 1.0);
    final taskState = liveRow?.state ?? row.state;
    final isPending = selection.pending;
    final isImportRunning = task.importStatus == 'running';
    final movieNumber = task.movieNumber;
    final hasMovieNumber = (movieNumber ?? '').isNotEmpty;
    final displayTitle = _resolveDisplayTitle(task);
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final selectionMode = selection.mode;
    final isSelected = selection.selected;
    final thinCoverUrl = task.movieThinCover?.origin.trim() ?? '';
    final wideCoverUrl = task.movieCover?.origin.trim() ?? '';
    final coverUrl = isMobile && thinCoverUrl.isNotEmpty
        ? thinCoverUrl
        : wideCoverUrl;

    // 骨架态整卡收敛成一块 shimmer 圆角块：进度条 / 状态角标不再透出自有颜色。
    return AppSkeletonUnite(
      borderRadius: context.appRadius.mdBorder,
      child: AppLeftCoverCard(
        key: Key('download-task-${task.id}'),
        coverWidth: componentTokens.downloadTaskCoverWidth,
        bodyMinHeight: componentTokens.downloadTaskCardMinHeight,
        selected: selectionMode && isSelected,
        onTap: selectionMode
            ? () => ref
                  .read(downloadTaskCenterProvider.notifier)
                  .toggleSelection(task.id)
            : null,
        cover: _DownloadTaskCover(
          coverUrl: coverUrl,
          movieNumber: hasMovieNumber ? movieNumber : null,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onTap: selectionMode || !hasMovieNumber
              ? null
              : () {
                  if (isMobile) {
                    context.pushMobileMovieDetail(movieNumber: movieNumber!);
                    return;
                  }
                  context.pushDesktopMovieDetail(
                    movieNumber: movieNumber!,
                    fallbackPath: desktopDownloadTasksPath,
                  );
                },
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① 番号：把用户"扫一眼找番号"的心智放最顶。空番号（predownload）不渲染。
            if (hasMovieNumber)
              AppBadge(
                key: Key('download-task-movie-number-${movieNumber!}'),
                label: movieNumber,
                tone: AppBadgeTone.neutral,
                size: AppBadgeSize.compact,
              ),
            if (hasMovieNumber) SizedBox(height: context.appSpacing.xs),
            // ② 标题：中文标题优先，1 行 ellipsis。
            Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: context.appSpacing.sm),
            // ③ 进度条：已完成态用中性灰，避免深色进度条抢眼。
            ClipRRect(
              borderRadius: context.appRadius.pillBorder,
              child: LinearProgressIndicator(
                minHeight: componentTokens.downloadTaskProgressHeight,
                value: progress,
                backgroundColor: colors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _progressBarColor(context, taskState),
                ),
              ),
            ),
            SizedBox(height: context.appSpacing.sm),
            // ④ 下载状态一行：状态 badge + 百分比 + 导入短标签
            Wrap(
              spacing: context.appSpacing.sm,
              runSpacing: context.appSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppBadge(
                  label: _labelForDownloadState(taskState, l10n),
                  tone: _toneForDownloadState(taskState),
                  size: AppBadgeSize.compact,
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: _statTextStyle(context),
                ),
                // 导入 badge 用短标签，完整文案挂 Tooltip 里
                if (task.importStatusLabel.isNotEmpty)
                  Tooltip(
                    message: task.importStatusLabel,
                    child: AppBadge(
                      label: _shortImportLabel(
                        task.importStatus,
                        fallback: task.importStatusLabel,
                        l10n: l10n,
                      ),
                      tone: _toneForImportStatus(task.importStatus),
                      size: AppBadgeSize.compact,
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.appSpacing.sm),
            // ⑤ 客户端 + 创建时间（靠左）+ 操作按钮（靠右）
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: context.appSpacing.sm,
                    runSpacing: context.appSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        clientName ??
                            l10n.downloadClientFallbackName(task.clientId),
                        style: _footnoteTextStyle(context),
                      ),
                      if (formatUpdatedAtLabel(task.createdAt) != null)
                        Text(
                          l10n.downloadCreatedAt(
                            formatUpdatedAtLabel(task.createdAt)!,
                          ),
                          style: _footnoteTextStyle(context),
                        ),
                    ],
                  ),
                ),
                if (!selectionMode && task.state == 'completed') ...[
                  AppIconButton(
                    key: Key('download-task-files-${task.id}'),
                    icon: const Icon(Icons.folder_open_rounded),
                    tooltip: l10n.downloadViewFiles,
                    onPressed: () => showDownloadTaskFilesDialog(
                      context: context,
                      taskId: task.id,
                      movieNumber: movieNumber ?? '',
                      title: displayTitle,
                    ),
                  ),
                  SizedBox(width: context.appSpacing.xs),
                ],
                if (!selectionMode && task.canRetriggerImport) ...[
                  AppIconButton(
                    key: Key('download-task-retrigger-import-${task.id}'),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: l10n.downloadRetriggerImport,
                    onPressed: isPending
                        ? null
                        : () =>
                              unawaited(_triggerImport(context, ref, task.id)),
                  ),
                  SizedBox(width: context.appSpacing.xs),
                ],
                if (!selectionMode)
                  AppIconButton(
                    key: Key('download-task-delete-${task.id}'),
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: isImportRunning
                        ? l10n.downloadDeleteBlockedImporting
                        : l10n.commonDelete,
                    onPressed: (isPending || isImportRunning)
                        ? null
                        : () => unawaited(_deleteTask(context, ref, task)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _resolveDisplayTitle(DownloadTaskDto task) {
    final displayName = (task.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final movieTitle = (task.movieTitle ?? '').trim();
    if (movieTitle.isNotEmpty) {
      return movieTitle;
    }
    return task.name.isEmpty ? task.remoteId : task.name;
  }
}

TextStyle _statTextStyle(BuildContext context) => resolveAppTextStyle(
  context,
  size: AppTextSize.s12,
  weight: AppTextWeight.regular,
  tone: AppTextTone.muted,
);

TextStyle _footnoteTextStyle(BuildContext context) => resolveAppTextStyle(
  context,
  size: AppTextSize.s10,
  weight: AppTextWeight.regular,
  tone: AppTextTone.tertiary,
);

Color _progressBarColor(BuildContext context, String state) {
  final palette = context.appTextPalette;
  final colors = context.appColors;
  return switch (state) {
    'downloading' => palette.accent,
    'failed' => palette.error,
    _ => colors.borderStrong,
  };
}

/// 导入状态短标签映射。后端 `describe_import_status` 里的完整中文（如
/// "已导入：媒体文件全部成功入库"）在 badge 上过长；这里给出 4 字内的短版，
/// 完整文案通过 Tooltip 保留在 hover 里。
String _shortImportLabel(
  String status, {
  required String fallback,
  required AppLocalizations l10n,
}) {
  return switch (status) {
    'pending' => l10n.downloadImportStatusPending,
    'running' => l10n.downloadImportStatusRunning,
    'completed' => l10n.downloadImportStatusCompleted,
    'failed' => l10n.downloadImportStatusFailed,
    'skipped' => l10n.downloadImportStatusSkipped,
    _ => fallback,
  };
}

Future<void> _triggerImport(
  BuildContext context,
  WidgetRef ref,
  int taskId,
) async {
  try {
    await ref.read(downloadTaskCenterProvider.notifier).triggerImport(taskId);
    if (context.mounted) {
      showToast(
        AppLocalizations.of(context).downloadImportSubmitted,
        tone: AppToastTone.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.downloadImportSubmitFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }
}

/// 卡片左侧封面由外层 Positioned 提供固定宽度和全高约束，贴合卡片上下缘。
/// 圆角由最外层卡片 `clipBehavior` 统一裁剪；仅封面本身接收详情跳转，避免误吞右侧操作。
///
/// 多选态封面只作展示 + 左上角勾选标记，点击交给整卡统一处理。
class _DownloadTaskCover extends StatelessWidget {
  const _DownloadTaskCover({
    required this.coverUrl,
    required this.movieNumber,
    required this.onTap,
    required this.selectionMode,
    required this.isSelected,
  });

  final String coverUrl;
  final String? movieNumber;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    // 横向封面居中裁切，圆角由外层下载任务卡统一处理。
    final image = MaskedImage(
      url: coverUrl,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );

    final Widget content;
    if (onTap == null) {
      content = image;
    } else {
      content = Semantics(
        button: true,
        label: AppLocalizations.of(
          context,
        ).downloadViewMovieDetails(movieNumber ?? ''),
        child: Material(
          color: Colors.transparent,
          child: AppInteractiveSurface(
            key: Key('download-task-cover-tap-${movieNumber ?? ''}'),
            onTap: onTap,
            child: image,
          ),
        ),
      );
    }

    if (!selectionMode) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        PositionedDirectional(
          top: context.appSpacing.sm,
          start: context.appSpacing.sm,
          child: SelectionCheckBadge(isSelected: isSelected),
        ),
      ],
    );
  }
}

String _labelForDownloadState(String state, AppLocalizations l10n) {
  return switch (state) {
    'downloading' => l10n.downloadStateDownloading,
    'queued' => l10n.downloadStateQueued,
    'completed' => l10n.downloadStateCompleted,
    'failed' => l10n.downloadStateFailed,
    _ => state.isEmpty ? l10n.commonUnknown : state,
  };
}

AppBadgeTone _toneForDownloadState(String state) {
  return switch (state) {
    'downloading' => AppBadgeTone.primary,
    'queued' => AppBadgeTone.neutral,
    'completed' => AppBadgeTone.success,
    'failed' => AppBadgeTone.error,
    _ => AppBadgeTone.neutral,
  };
}

AppBadgeTone _toneForImportStatus(String state) {
  return switch (state) {
    'running' => AppBadgeTone.primary,
    'completed' => AppBadgeTone.success,
    'failed' => AppBadgeTone.error,
    'pending' || 'skipped' => AppBadgeTone.neutral,
    _ => AppBadgeTone.neutral,
  };
}

/// 下载任务筛选栏：番号搜索（回车提交）+ 状态下拉 + 客户端下拉（仅在客户端 ≥2 时显示）。
///
/// 遵循「筛选状态驱动」范式：所有变更走 `notifier.applyFilter(...)`。
/// 搜索输入沿用项目其它筛选栏习惯——**不做打字 debounce**，仅回车/失焦提交。
class _DownloadFilterBar extends StatelessWidget {
  const _DownloadFilterBar({
    required this.filter,
    required this.clientOptions,
    required this.hasItems,
    required this.onManualAdd,
  });

  final DownloadTaskFilterState filter;
  final List<DownloadClientOption> clientOptions;
  final bool hasItems;
  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context) {
    if (AppPlatformScope.maybeOf(context) == AppPlatform.mobile) {
      return _MobileDownloadFilterEntry(
        filter: filter,
        clientOptions: clientOptions,
        hasItems: hasItems,
        onManualAdd: onManualAdd,
      );
    }
    return _DesktopDownloadFilterBar(
      filter: filter,
      clientOptions: clientOptions,
    );
  }
}

class _DesktopDownloadFilterBar extends HookConsumerWidget {
  const _DesktopDownloadFilterBar({
    required this.filter,
    required this.clientOptions,
  });

  final DownloadTaskFilterState filter;
  final List<DownloadClientOption> clientOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController(text: filter.search);
    // 若外部通过其它入口（如「清除筛选」）改了 filter.search，同步进输入框；
    // 用户正在输入时（controller.text 与最近同步值不一致）避免打断。
    final attachedSearch = useRef<String>(filter.search);
    useEffect(() {
      final external = filter.search;
      if (external != attachedSearch.value &&
          external != searchController.text) {
        searchController.text = external;
      }
      attachedSearch.value = external;
      return null;
    }, [filter.search]);

    final l10n = AppLocalizations.of(context);
    final layoutTokens = context.appLayoutTokens;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );

    Future<void> submitSearch(String value) async {
      final next = filter.copyWith(search: value.trim());
      attachedSearch.value = next.search;
      await ref.read(downloadTaskCenterProvider.notifier).applyFilter(next);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthLg,
          child: AppTextField(
            fieldKey: const Key('download-filter-search'),
            controller: searchController,
            hintText: l10n.downloadSearchByMovieNumber,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: submitSearch,
            enabled: true,
          ),
        ),
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<DownloadTaskStateFilter>(
            key: const Key('download-filter-state'),
            value: filter.stateFilter,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: DownloadTaskStateFilter.values
                .map(
                  (value) => DropdownMenuItem<DownloadTaskStateFilter>(
                    value: value,
                    child: Text(value.label(l10n)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => ref
                .read(downloadTaskCenterProvider.notifier)
                .applyFilter(
                  filter.copyWith(
                    stateFilter: value ?? DownloadTaskStateFilter.downloading,
                  ),
                ),
          ),
        ),
        if (clientOptions.length >= 2)
          SizedBox(
            width: layoutTokens.filterFieldWidthMd,
            child: AppSelectField<int?>(
              key: const Key('download-filter-client'),
              value: filter.clientId,
              size: AppSelectFieldSize.compact,
              textStyle: filterTextStyle,
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.downloadFilterAllClients),
                ),
                for (final option in clientOptions)
                  DropdownMenuItem<int?>(
                    value: option.id,
                    child: Text(option.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => ref
                  .read(downloadTaskCenterProvider.notifier)
                  .applyFilter(filter.copyWith(clientId: value)),
            ),
          ),
      ],
    );
  }
}

class _MobileDownloadFilterEntry extends ConsumerWidget {
  const _MobileDownloadFilterEntry({
    required this.filter,
    required this.clientOptions,
    required this.hasItems,
    required this.onManualAdd,
  });

  final DownloadTaskFilterState filter;
  final List<DownloadClientOption> clientOptions;
  final bool hasItems;
  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isSelected = !filter.isDefault;
    return Row(
      children: [
        Expanded(
          child: Text(
            _downloadFilterSummary(filter, clientOptions, l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        _buildManualAddAction(context, onManualAdd, isMobile: true),
        SizedBox(width: context.appSpacing.xs),
        AppSelectionEntryButton(
          key: const Key('download-tasks-selection-entry'),
          onPressed: hasItems
              ? () => ref
                    .read(downloadTaskCenterProvider.notifier)
                    .enterSelectionMode()
              : null,
        ),
        SizedBox(width: context.appSpacing.sm),
        AppButton(
          key: const Key('mobile-download-filter-button'),
          label: isSelected
              ? l10n.downloadFilterApplied
              : l10n.downloadFilterAction,
          icon: const Icon(Icons.tune_rounded),
          size: AppButtonSize.small,
          isSelected: isSelected,
          onPressed: () => _showMobileDownloadFilterDrawer(
            context,
            current: filter,
            clientOptions: clientOptions,
            onChanged: (next) => unawaited(
              ref.read(downloadTaskCenterProvider.notifier).applyFilter(next),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showMobileDownloadFilterDrawer(
  BuildContext context, {
  required DownloadTaskFilterState current,
  required List<DownloadClientOption> clientOptions,
  required ValueChanged<DownloadTaskFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-download-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (_) => _MobileDownloadFilterDrawerContent(
      current: current,
      clientOptions: clientOptions,
      onChanged: onChanged,
    ),
  );
}

class _MobileDownloadFilterDrawerContent extends StatefulWidget {
  const _MobileDownloadFilterDrawerContent({
    required this.current,
    required this.clientOptions,
    required this.onChanged,
  });

  final DownloadTaskFilterState current;
  final List<DownloadClientOption> clientOptions;
  final ValueChanged<DownloadTaskFilterState> onChanged;

  @override
  State<_MobileDownloadFilterDrawerContent> createState() =>
      _MobileDownloadFilterDrawerContentState();
}

class _MobileDownloadFilterDrawerContentState
    extends State<_MobileDownloadFilterDrawerContent> {
  late DownloadTaskFilterState _local;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
    _searchController = TextEditingController(text: _local.search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _apply(DownloadTaskFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-download-filter-scroll-view'),
      footer: AppFilterPanelFooter(
        isDefault: _local.isDefault,
        onReset: () {
          _searchController.clear();
          _apply(DownloadTaskFilterState.initial);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.downloadFilterTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.lg),
          AppTextField(
            fieldKey: const Key('mobile-download-filter-search'),
            controller: _searchController,
            label: l10n.downloadMovieNumberLabel,
            hintText: l10n.downloadSearchByMovieNumber,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (value) =>
                _apply(_local.copyWith(search: value.trim())),
          ),
          SizedBox(height: context.appSpacing.md),
          AppSelectField<DownloadTaskStateFilter>(
            key: const Key('mobile-download-filter-state'),
            label: l10n.downloadStateFilterLabel,
            value: _local.stateFilter,
            items: DownloadTaskStateFilter.values
                .map(
                  (value) => DropdownMenuItem<DownloadTaskStateFilter>(
                    value: value,
                    child: Text(value.label(l10n)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => _apply(
              _local.copyWith(
                stateFilter: value ?? DownloadTaskStateFilter.downloading,
              ),
            ),
          ),
          if (widget.clientOptions.length >= 2) ...[
            SizedBox(height: context.appSpacing.md),
            AppSelectField<int?>(
              key: const Key('mobile-download-filter-client'),
              label: l10n.downloadClientFilterLabel,
              value: _local.clientId,
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.downloadFilterAllClients),
                ),
                for (final option in widget.clientOptions)
                  DropdownMenuItem<int?>(
                    value: option.id,
                    child: Text(option.name),
                  ),
              ],
              onChanged: (value) => _apply(_local.copyWith(clientId: value)),
            ),
          ],
        ],
      ),
    );
  }
}

String _downloadFilterSummary(
  DownloadTaskFilterState filter,
  List<DownloadClientOption> clientOptions,
  AppLocalizations l10n,
) {
  final values = <String>[filter.stateFilter.label(l10n)];
  if (filter.normalizedSearch.isNotEmpty) {
    values.add(filter.normalizedSearch);
  }
  final clientId = filter.clientId;
  if (clientId != null) {
    final client = clientOptions.where((item) => item.id == clientId);
    values.add(
      client.isEmpty ? l10n.downloadFilterClientSpecified : client.first.name,
    );
  }
  return values.join(' · ');
}
