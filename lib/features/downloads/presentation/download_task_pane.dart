import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/downloads/presentation/download_placeholders.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/downloads/presentation/widgets/download_task_card.dart';
import 'package:sakuramedia/features/downloads/presentation/widgets/download_task_filter_panel.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_delete_dialog.dart';

/// 构建「下载任务」页的头部。
///
/// 调用方负责把列表 slivers 放进外层滚动视图。
Widget buildDownloadTaskHeader({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onManualAdd,
  required SelectionController<int> selection,
}) {
  // 只订阅头部渲染所需的字段：进度轮询 tick 不重建头部。
  final header = ref.watch(
    downloadTaskCenterProvider.select((asyncState) {
      final state = asyncState.value;
      return (
        loadedCount: state?.paged.items.length ?? 0,
        filterUpdate:
            state?.paged.filterUpdate ?? const FilterUpdateState.idle(),
        hasItems: state?.paged.items.isNotEmpty ?? false,
        filter: state?.filter ?? DownloadTaskFilterState.initial,
        clientOptions: state?.clientOptions ?? const <DownloadClientOption>[],
      );
    }),
  );
  final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
  if (!isMobile && !selection.active) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(downloadTaskCenterProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGlassListHeader(
          leading: AppGlassFilterPopover(
            panelKey: const Key('download-filter-panel'),
            scrollable: true,
            isDefault: header.filter.isDefault,
            onReset: () => unawaited(
              notifier.applyFilter(DownloadTaskFilterState.initial),
            ),
            resetKey: const Key('download-filter-reset'),
            triggerKey: const Key('download-filter-button'),
            label: downloadTaskFilterSummary(
              header.filter,
              header.clientOptions,
              l10n,
            ),
            tooltip: l10n.downloadFilterTitle,
            panelBuilder: (context) => DownloadTaskFilterSections(
              filter: header.filter,
              clientOptions: header.clientOptions,
              onChanged: (next) => unawaited(notifier.applyFilter(next)),
            ),
          ),
          trailing: AppGlassHeaderGroup(
            children: <Widget>[
              AppGlassHeaderButton(
                key: const Key('download-tasks-manual-add'),
                icon: Icons.add_rounded,
                label: l10n.downloadManualAddAction,
                onTap: onManualAdd,
              ),
              AppGlassHeaderButton(
                key: const Key('download-tasks-selection-entry'),
                icon: Icons.check_circle_outline,
                label: l10n.baseSelect,
                enabled: header.loadedCount > 0,
                onTap: header.loadedCount > 0
                    ? selection.enterSelection
                    : () {},
              ),
            ],
          ),
          filterUpdate: header.filterUpdate,
          hasPreviousFilterItems: header.hasItems,
          onRetryFilter: () => unawaited(notifier.retryFilter()),
        ),
        SizedBox(height: context.appSpacing.lg),
      ],
    );
  }
  // 首次加载也渲染初始筛选栏：骨架列表与数据回来后的最终布局保持一致，
  // 避免头部突然多出一行导致内容下跳。
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (selection.active)
        isMobile
            ? _MobileSelectionHeader(selection: selection)
            : _DesktopSelectionHeader(selection: selection)
      else
        _MobileDownloadFilterEntry(
          filter: header.filter,
          clientOptions: header.clientOptions,
          hasItems: header.hasItems,
          onManualAdd: onManualAdd,
          selection: selection,
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

/// 移动端多选态把页面内容包成「列表 + 贴底批量操作条」；桌面或非多选态原样返回。
///
/// 下载 tab 的多选动作在桌面顶栏、移动贴底条，两处不共存。只在调用方确认当前是
/// 下载 tab 时调用，避免提前初始化下载任务 Provider。
Widget wrapDownloadTaskSelectionBar({
  required BuildContext context,
  required WidgetRef ref,
  required SelectionController<int> selection,
  required Widget child,
}) {
  if (AppPlatformScope.maybeOf(context) != AppPlatform.mobile) return child;
  if (!selection.active) return child;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: child),
      _MobileSelectionBar(selection: selection),
    ],
  );
}

/// 桌面多选态顶栏：原地改写筛选行，批量动作与移动贴底条共用。
class _DesktopSelectionHeader extends ConsumerWidget {
  const _DesktopSelectionHeader({required this.selection});

  final SelectionController<int> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loadedIds = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) =>
            asyncState.value?.paged.items
                .map((row) => row.task.id)
                .toList(growable: false) ??
            const <int>[],
      ),
    );
    final selectionCount = selection.selectedCount;
    final allSelected = selection.isAllSelected(loadedIds);
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.downloadTaskDelete,
    ]);
    return AppGlassSelectionHeader(
      key: const Key('download-tasks-selection-header'),
      selectionLabel: l10n.downloadSelectionCount(selectionCount),
      countKey: const Key('download-tasks-selection-count'),
      selectAllLabel: allSelected
          ? l10n.downloadSelectionClearAll
          : l10n.downloadSelectionSelectAll(loadedIds.length),
      selectAllKey: const Key('download-tasks-select-all-button'),
      onToggleAll: loadedIds.isEmpty
          ? null
          : () => selection.toggleSelectAll(loadedIds),
      exitKey: const Key('download-tasks-selection-exit'),
      onExitSelection: selection.exitSelection,
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: const Key('download-tasks-batch-delete-button'),
          label: l10n.downloadSelectionDelete(selectionCount),
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          onTap: selectionCount > 0 && !submitting
              ? () => unawaited(_deleteSelectedTasks(context, ref, selection))
              : null,
        ),
      ],
    );
  }
}

/// 移动端多选态顶栏：与订阅管理 / PornBox 共用紧凑玻璃多选头，
/// 危险动作下沉到贴底条 [_MobileSelectionBar]。
class _MobileSelectionHeader extends ConsumerWidget {
  const _MobileSelectionHeader({required this.selection});

  final SelectionController<int> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loadedIds = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) =>
            asyncState.value?.paged.items
                .map((row) => row.task.id)
                .toList(growable: false) ??
            const <int>[],
      ),
    );
    final selectionCount = selection.selectedCount;
    final allSelected = selection.isAllSelected(loadedIds);
    return AppMobileSelectionHeader(
      key: const Key('download-tasks-selection-header'),
      selectionLabel: l10n.downloadSelectionCount(selectionCount),
      exitKey: const Key('download-tasks-selection-exit'),
      onExitSelection: selection.exitSelection,
      selectAllKey: const Key('download-tasks-select-all-button'),
      selectAllTooltip: allSelected
          ? l10n.downloadSelectionClearAll
          : l10n.downloadSelectionSelectAll(loadedIds.length),
      onToggleAll: loadedIds.isEmpty
          ? null
          : () => selection.toggleSelectAll(loadedIds),
    );
  }
}

/// 移动端贴底批量操作条：危险动作放在拇指够得到的地方。
class _MobileSelectionBar extends ConsumerWidget {
  const _MobileSelectionBar({required this.selection});

  final SelectionController<int> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionCount = selection.selectedCount;
    return AppSelectionBottomBar(
      actions: <Widget>[
        _buildBatchDeleteButton(context, ref, selection, selectionCount),
      ],
    );
  }
}

Widget _buildBatchDeleteButton(
  BuildContext context,
  WidgetRef ref,
  SelectionController<int> selection,
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
        ? () => unawaited(_deleteSelectedTasks(context, ref, selection))
        : null,
  );
}

/// 批量删除所选下载任务：确认后提交后端批量操作任务，进度与结果在活动中心查看。
Future<void> _deleteSelectedTasks(
  BuildContext context,
  WidgetRef ref,
  SelectionController<int> selection,
) async {
  final notifier = ref.read(downloadTaskCenterProvider.notifier);
  final tasks = notifier.loadedTasksByIds(selection.selectedIds);
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
  if (submitted) selection.exitSelection();
}

List<Widget> buildDownloadTaskSlivers({
  required VoidCallback onManualAdd,
  required SelectionController<int> selection,
}) {
  // 列表本体与页脚各自独立订阅：进度 tick 只重建变化的行，
  // 翻页状态翻转只重建页脚，不重建整个列表。
  return <Widget>[
    _DownloadTasksBodySliver(onManualAdd: onManualAdd, selection: selection),
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

/// 下载任务列表本体：只订阅结构（条目 id 序列）与四态。
///
/// 进度 tick 只改变行内数据（条目序列不变），不重建列表；
/// 各行通过 [DownloadTaskCard] 独立订阅自己的行状态。
class _DownloadTasksBodySliver extends ConsumerWidget {
  const _DownloadTasksBodySliver({
    required this.onManualAdd,
    required this.selection,
  });

  final VoidCallback onManualAdd;
  final SelectionController<int> selection;

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
                child: DownloadTaskCard(
                  row: placeholders[index],
                  selection: selection,
                ),
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
    // 进度 tick 不重建本体，各行独立订阅（见 DownloadTaskCard）。
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
          child: RepaintBoundary(
            child: DownloadTaskCard(row: row, selection: selection),
          ),
        );
      }, childCount: items.length),
    );
  }
}

class _MobileDownloadFilterEntry extends ConsumerWidget {
  const _MobileDownloadFilterEntry({
    required this.filter,
    required this.clientOptions,
    required this.hasItems,
    required this.onManualAdd,
    required this.selection,
  });

  final DownloadTaskFilterState filter;
  final List<DownloadClientOption> clientOptions;
  final bool hasItems;
  final VoidCallback onManualAdd;
  final SelectionController<int> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isSelected = !filter.isDefault;
    final summary = downloadTaskFilterSummary(filter, clientOptions, l10n);
    return AppMobileListHeader(
      leading: AppMobileHeaderText(countLabel: summary),
      actions: <Widget>[
        AppGlassIconButton(
          key: const Key('download-tasks-manual-add'),
          tooltip: l10n.downloadManualAddTitle,
          icon: Icons.add_rounded,
          onPressed: onManualAdd,
        ),
        AppGlassIconButton(
          key: const Key('download-tasks-selection-entry'),
          tooltip: l10n.baseSelect,
          icon: Icons.check_circle_outline,
          onPressed: hasItems ? selection.enterSelection : null,
        ),
        AppGlassFilterIconButton(
          key: const Key('mobile-download-filter-button'),
          summary: summary,
          isActive: isSelected,
          onPressed: () => showDownloadTaskFilterDrawer(
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
