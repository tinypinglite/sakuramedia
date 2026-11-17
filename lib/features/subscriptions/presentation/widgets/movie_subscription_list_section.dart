import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_delete_dialog.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_files_dialog.dart';
import 'package:sakuramedia/widgets/domain/subscriptions/movie_subscription_sort_menu_button.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' show HookConsumerWidget;
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_filter_sections.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_row.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_row_actions.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_placeholders.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/use_selection_controller.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_magnet_search_launcher.dart';

/// 订阅管理页的列表主体：顶栏（筛选 / 计数 / 操作）+ 行卡片列表。
///
/// 双端分流只发生在容器层：筛选桌面走就地浮层、移动走底部抽屉；多选态桌面用
/// 玻璃多选头原地改写整行，移动用 `AppMobileSelectionHeader`
/// （顶）+ [AppSelectionBottomBar]（底）。列表体、行卡片、空态完全共用。
///
/// 状态分段签不在这里——它归页面，固定在滚动区之上。
class MovieSubscriptionListSection extends HookConsumerWidget {
  const MovieSubscriptionListSection({
    super.key,
    required this.onOpenMovie,
    required this.onOpenDownloads,
    this.mobile = false,
    this.scrollController,
  });

  /// 打开影片详情。桌面 / 移动的详情路由不同，由各自的页面注入——本组件不认路由。
  final void Function(BuildContext context, String movieNumber) onOpenMovie;

  /// 打开该订阅片对应的下载任务列表，同样由页面注入各自的平台路由。
  final void Function(BuildContext context, String movieNumber) onOpenDownloads;

  /// 移动端布局：底部抽屉筛选 + 贴底批量操作条。
  final bool mobile;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerProvider = movieSubscriptionManagerProvider(
      ref.watch(movieSubscriptionStatusSelectionProvider),
    );
    final selection = useSelectionController<String>(
      orderedIds: () {
        final status = ref.read(movieSubscriptionStatusSelectionProvider);
        final state = ref.read(movieSubscriptionManagerProvider(status)).value;
        return state?.paged.items
                .map((item) => item.movieNumber)
                .where((number) => number.isNotEmpty)
                .toList(growable: false) ??
            const <String>[];
      },
    );
    useListenable(selection);
    final spacing = context.appSpacing;
    final ownedScrollController = useScrollController();
    final effectiveScrollController = scrollController ?? ownedScrollController;
    // 移动端删除下载任务 / 重新导入的 loading：顶栏（退出 / 全选）和贴底操作条要同步禁用。
    final batchDeleting = useState(false);
    final batchImporting = useState(false);
    ref.listen(managerProvider.select((value) => value.value?.filter), (
      previous,
      next,
    ) {
      if (previous != null && next != null && previous != next) {
        selection.exitSelection();
        if (effectiveScrollController.hasClients) {
          unawaited(
            effectiveScrollController.animateTo(
              0,
              duration: context.appMotion.fast,
              curve: context.appMotion.standard,
            ),
          );
        }
      }
    });
    final pagedView = ref.watch(
      managerProvider.select(
        (asyncState) => (
          isLoading: asyncState.value?.paged.filterUpdate.isLoading ?? false,
          hasPreviousItems: asyncState.value?.paged.items.isNotEmpty ?? false,
        ),
      ),
    );
    final resultView = AppFixedHeaderLayout(
      header: _ListHeader(
        mobile: mobile,
        selection: selection,
        batchDeleting: batchDeleting.value,
        batchImporting: batchImporting.value,
      ),
      headerBottomSpacing: context.appSpacing.lg,
      child: AppFilterResultLoadingOverlay(
        surfaceColor: mobile
            ? context.appColors.surfaceCard
            : context.appColors.surfaceElevated,
        isLoading: pagedView.isLoading,
        hasPreviousItems: pagedView.hasPreviousItems,
        child: AppPagedLoadMoreScope(
          canLoadMore: () =>
              ref.read(managerProvider).value?.paged.canAutoLoadMore ?? false,
          onLoadMore: () => ref.read(managerProvider.notifier).loadMore(),
          child: CustomScrollView(
            key: PageStorageKey(managerProvider),
            controller: effectiveScrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _queryExplanationTip(AppLocalizations.of(context)),
              ),
              SliverToBoxAdapter(child: SizedBox(height: spacing.md)),
              _ListBodySliver(
                onOpenMovie: onOpenMovie,
                onOpenDownloads: onOpenDownloads,
                mobile: mobile,
                selection: selection,
              ),
              // loadMore 的 loading / 失败提示独立订阅：翻页状态翻转只重建这个
              // footer，不重建上面的列表本体。
              PagedLoadMoreFooterSliver(
                watchFooter: (ref) => ref.watch(
                  managerProvider.select(
                    (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
                  ),
                ),
                onLoadMore: (ref) =>
                    unawaited(ref.read(managerProvider.notifier).loadMore()),
              ),
              ...bottomSafeAreaSliver(context),
            ],
          ),
        ),
      ),
    );
    if (!mobile) return resultView;
    if (!selection.active) return resultView;
    return Column(
      children: [
        Expanded(child: resultView),
        _MobileSelectionBar(
          state: ref.read(managerProvider).value,
          selection: selection,
          deleting: batchDeleting.value,
          onDeletingChanged: (value) => batchDeleting.value = value,
          importing: batchImporting.value,
          onImportingChanged: (value) => batchImporting.value = value,
        ),
      ],
    );
  }
}

// --- 顶栏 -------------------------------------------------------------------

class _ListHeader extends ConsumerWidget {
  const _ListHeader({
    required this.mobile,
    required this.selection,
    required this.batchDeleting,
    required this.batchImporting,
  });

  final bool mobile;
  final SelectionController<String> selection;
  final bool batchDeleting;
  final bool batchImporting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerProvider = movieSubscriptionManagerProvider(
      ref.watch(movieSubscriptionStatusSelectionProvider),
    );
    final asyncState = ref.watch(managerProvider);
    final current = asyncState.value;
    if (current != null && selection.active) {
      return mobile
          ? _MobileSelectionHeader(
              state: current,
              selection: selection,
              batchDeleting: batchDeleting,
              batchImporting: batchImporting,
            )
          : _SelectionHeader(state: current, selection: selection);
    }

    final filter =
        current?.filter ??
        MovieSubscriptionFilterState.initial.copyWith(
          status: ref.watch(movieSubscriptionStatusSelectionProvider),
        );
    final total = current?.paged.total ?? 0;
    final hasItems = current?.paged.items.isNotEmpty ?? false;
    final isInitialLoading = asyncState.isLoading && !asyncState.hasValue;
    final l10n = AppLocalizations.of(context);

    void applyFilter(MovieSubscriptionFilterState next) {
      unawaited(ref.read(managerProvider.notifier).applyFilterState(next));
    }

    if (!mobile) {
      return AppGlassListHeader(
        leading: AppGlassFilterPopover(
          panelKey: const Key('movie-subscriptions-filter-panel'),
          scrollable: true,
          isDefault: filter.isPanelDefault,
          onReset: () => applyFilter(filter.resetPanel()),
          resetKey: const Key('movie-subscriptions-filter-reset'),
          triggerKey: const Key('movie-subscriptions-filter-button'),
          label: filter.triggerLabel(l10n),
          tooltip: l10n.baseFilterTooltip,
          info: <Widget>[
            AppGlassHeaderText(
              key: const Key('movie-subscriptions-total-info'),
              label: l10n.subscriptionListTotalCount(total),
            ),
          ],
          panelBuilder: (context) => MovieSubscriptionFilterSectionGroup(
            filterState: filter,
            onChanged: applyFilter,
          ),
        ),
        trailing: AppGlassHeaderGroup(
          children: <Widget>[
            MovieSubscriptionSortMenuButton(
              triggerKey: const Key('movie-subscriptions-sort-trigger'),
              panelKey: const Key('movie-subscriptions-sort-panel'),
              keyPrefix: 'movie-subscriptions',
              filterState: filter,
              onChanged: applyFilter,
              glassGrouped: true,
            ),
            AppGlassHeaderButton(
              key: const Key('movie-subscriptions-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              enabled: hasItems,
              onTap: hasItems ? selection.enterSelection : () {},
            ),
            AppGlassHeaderButton(
              key: const Key('movie-subscriptions-refresh-button'),
              icon: Icons.refresh_rounded,
              label: isInitialLoading
                  ? l10n.subscriptionListRefreshing
                  : l10n.commonRefresh,
              enabled: !isInitialLoading,
              onTap: isInitialLoading ? () {} : () => _refresh(ref),
            ),
          ],
        ),
        filterUpdate:
            current?.paged.filterUpdate ?? const FilterUpdateState.idle(),
        hasPreviousFilterItems: hasItems,
        onRetryFilter: () =>
            unawaited(ref.read(managerProvider.notifier).retryFilter()),
      );
    }

    return AppMobileListHeader(
      key: const Key('movie-subscriptions-list-header'),
      leading: AppMobileHeaderText(
        key: const Key('movie-subscriptions-total-info'),
        countLabel: l10n.subscriptionListTotalCount(total),
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: const Key('movie-subscriptions-filter-button'),
          summary: filter.triggerLabel(l10n),
          isActive: !filter.isPanelDefault,
          onPressed: () => _openMobileFilterDrawer(context, ref, filter),
        ),
        MovieSubscriptionSortMenuButton(
          triggerKey: const Key('movie-subscriptions-sort-trigger'),
          panelKey: const Key('movie-subscriptions-sort-panel'),
          drawerKey: const Key('mobile-movie-subscriptions-sort-drawer'),
          keyPrefix: 'mobile-movie-subscriptions',
          filterState: filter,
          onChanged: applyFilter,
          useDrawer: true,
          iconOnly: true,
        ),
        AppGlassIconButton(
          key: const Key('movie-subscriptions-enter-selection-button'),
          tooltip: l10n.baseSelect,
          icon: Icons.check_circle_outline,
          onPressed: hasItems ? selection.enterSelection : null,
        ),
        AppGlassIconButton(
          key: const Key('movie-subscriptions-refresh-button'),
          icon: Icons.refresh_rounded,
          tooltip: isInitialLoading
              ? l10n.subscriptionListRefreshing
              : l10n.commonRefresh,
          onPressed: isInitialLoading ? null : () => _refresh(ref),
        ),
      ],
      filterUpdate:
          current?.paged.filterUpdate ?? const FilterUpdateState.idle(),
      hasPreviousFilterItems: hasItems,
      onRetryFilter: () =>
          unawaited(ref.read(managerProvider.notifier).retryFilter()),
    );
  }
}

/// 移动端筛选底部抽屉：与桌面浮层共用 [MovieSubscriptionFilterSectionGroup] 和
/// [AppGlassFilterFooter]，只有外壳不同。本地态 + 即时外发，与其它移动抽屉一致。
Future<void> _openMobileFilterDrawer(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionFilterState filter,
) {
  final managerProvider = movieSubscriptionManagerProvider(filter.status);
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('movie-subscriptions-filter-drawer'),
    // 内容自适应高度（最多 60% 屏高），避免「搜索」的短面板拖一大片空白。
    maxHeightFactor: 0.6,
    builder: (_) => AppMobileFilterDrawer<MovieSubscriptionFilterState>(
      current: filter,
      initial: filter.resetPanel(),
      isDefault: (value) => value.isPanelDefault,
      onChanged: (next) =>
          unawaited(ref.read(managerProvider.notifier).applyFilterState(next)),
      scrollViewKey: const Key('movie-subscriptions-filter-scroll-view'),
      contentBuilder: (context, local, onApply) =>
          MovieSubscriptionFilterSectionGroup(
            filterState: local,
            onChanged: onApply,
          ),
    ),
  );
}

void _refresh(WidgetRef ref) {
  final managerProvider = movieSubscriptionManagerProvider(
    ref.read(movieSubscriptionStatusSelectionProvider),
  );
  unawaited(ref.read(managerProvider.notifier).refresh());
}

// --- 多选态顶栏 --------------------------------------------------------------

class _SelectionHeader extends HookConsumerWidget {
  const _SelectionHeader({required this.state, required this.selection});

  final MovieSubscriptionManagerState state;
  final SelectionController<String> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingDownloads = useState(false);
    final loadingImports = useState(false);
    final busy =
        state.isBatchRunning || loadingDownloads.value || loadingImports.value;

    final loadedIds = state.paged.items
        .map((item) => item.movieNumber)
        .toList(growable: false);
    final selectionCount = selection.selectedCount;
    final hasSelection = selectionCount > 0;
    final allSelected = selection.isAllSelected(loadedIds);
    final l10n = AppLocalizations.of(context);
    final selectAllLabel = allSelected
        ? l10n.subscriptionSelectionClearAll
        : l10n.subscriptionSelectionSelectAll(loadedIds.length);

    return AppGlassSelectionHeader(
      key: const Key('movie-subscriptions-selection-header'),
      selectionLabel: l10n.subscriptionSelectionCount(selectionCount),
      countKey: const Key('movie-subscriptions-selection-count'),
      selectAllLabel: selectAllLabel,
      selectAllKey: const Key('movie-subscriptions-select-all-button'),
      onToggleAll: busy || loadedIds.isEmpty
          ? null
          : () => selection.toggleSelectAll(loadedIds),
      exitKey: const Key('movie-subscriptions-selection-exit'),
      onExitSelection: busy ? null : selection.exitSelection,
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: const Key('movie-subscriptions-batch-retrigger-imports-button'),
          label: l10n.subscriptionActionRetriggerImport,
          icon: Icons.refresh_rounded,
          onTap: busy || !hasSelection
              ? null
              : () => unawaited(
                  _retriggerSelectedImports(
                    context,
                    ref,
                    state,
                    selection,
                    onLoadingChanged: (value) => loadingImports.value = value,
                  ),
                ),
        ),
        AppGlassSelectionAction(
          key: const Key('movie-subscriptions-batch-delete-downloads-button'),
          label: l10n.subscriptionActionDeleteDownloads,
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          onTap: busy || !hasSelection
              ? null
              : () => unawaited(
                  _deleteSelectedDownloads(
                    context,
                    ref,
                    state,
                    selection,
                    onLoadingChanged: (value) => loadingDownloads.value = value,
                  ),
                ),
        ),
        AppGlassSelectionAction(
          key: const Key('movie-subscriptions-batch-unsubscribe-button'),
          label: l10n.subscriptionBatchUnsubscribeWithCount(selectionCount),
          icon: Icons.bookmark_remove_outlined,
          foregroundColor: context.appTextPalette.error,
          onTap: busy || !hasSelection
              ? null
              : () => unawaited(
                  _confirmBatchUnsubscribe(context, ref, state, selection),
                ),
        ),
      ],
    );
  }
}

/// 移动端多选态顶栏：与 PornBox / 媒体管理共用紧凑玻璃多选头。
class _MobileSelectionHeader extends ConsumerWidget {
  const _MobileSelectionHeader({
    required this.state,
    required this.selection,
    required this.batchDeleting,
    required this.batchImporting,
  });

  final MovieSubscriptionManagerState state;
  final SelectionController<String> selection;
  final bool batchDeleting;
  final bool batchImporting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = state.isBatchRunning || batchDeleting || batchImporting;
    final loadedIds = state.paged.items
        .map((item) => item.movieNumber)
        .toList(growable: false);
    final selectionCount = selection.selectedCount;
    final allSelected = selection.isAllSelected(loadedIds);
    final l10n = AppLocalizations.of(context);

    return AppMobileSelectionHeader(
      key: const Key('movie-subscriptions-selection-header'),
      selectionLabel: l10n.subscriptionSelectionCount(selectionCount),
      exitKey: const Key('movie-subscriptions-selection-exit'),
      onExitSelection: busy ? null : selection.exitSelection,
      selectAllKey: const Key('movie-subscriptions-select-all-button'),
      selectAllTooltip: allSelected
          ? l10n.subscriptionSelectionClearAll
          : l10n.subscriptionSelectionSelectAll(loadedIds.length),
      onToggleAll: busy || loadedIds.isEmpty
          ? null
          : () => selection.toggleSelectAll(loadedIds),
    );
  }
}

/// 移动端贴底批量操作条：真正的危险动作放拇指够得到的地方，顶栏只留退出 / 全选。
class _MobileSelectionBar extends ConsumerWidget {
  const _MobileSelectionBar({
    required this.state,
    required this.selection,
    required this.deleting,
    required this.onDeletingChanged,
    required this.importing,
    required this.onImportingChanged,
  });

  final MovieSubscriptionManagerState? state;
  final SelectionController<String> selection;
  final bool deleting;
  final ValueChanged<bool> onDeletingChanged;
  final bool importing;
  final ValueChanged<bool> onImportingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentState = state;
    if (currentState == null) return const SizedBox.shrink();
    return AppSelectionBottomBar(
      actions: _buildBatchActions(
        context,
        ref,
        currentState,
        selection,
        compactLabels: true,
        loadingDownloads: deleting,
        loadingImports: importing,
        onRetriggerImports: () => unawaited(
          _retriggerSelectedImports(
            context,
            ref,
            currentState,
            selection,
            onLoadingChanged: onImportingChanged,
          ),
        ),
        onDeleteDownloads: () => unawaited(
          _deleteSelectedDownloads(
            context,
            ref,
            currentState,
            selection,
            onLoadingChanged: onDeletingChanged,
          ),
        ),
      ),
    );
  }
}

/// 多选态的批量操作按钮。桌面放进 `AppGlassSelectionHeader.actions`（small），
/// 移动贴底 `AppSelectionBottomBar` 用默认 medium 撑满等宽。
///
/// 移动端三个按钮平分宽度，图标 + 长标签会省略；[compactLabels] 用不带图标的
/// 短标签（已选数量由顶栏「已选 N 部」表达）。
List<Widget> _buildBatchActions(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionManagerState state,
  SelectionController<String> selection, {
  AppButtonSize size = AppButtonSize.medium,
  bool compactLabels = false,
  required bool loadingDownloads,
  required bool loadingImports,
  required VoidCallback onRetriggerImports,
  required VoidCallback onDeleteDownloads,
}) {
  final busy = state.isBatchRunning || loadingDownloads || loadingImports;
  final hasSelection = selection.selectedCount > 0;
  final l10n = AppLocalizations.of(context);
  return <Widget>[
    AppButton(
      key: const Key('movie-subscriptions-batch-retrigger-imports-button'),
      label: l10n.subscriptionActionRetriggerImport,
      size: size,
      icon: compactLabels ? null : const Icon(Icons.refresh_rounded),
      isLoading: loadingImports,
      onPressed: busy || !hasSelection ? null : onRetriggerImports,
    ),
    AppButton(
      key: const Key('movie-subscriptions-batch-delete-downloads-button'),
      label: compactLabels
          ? l10n.subscriptionBatchDeleteTasksLabel
          : l10n.subscriptionActionDeleteDownloads,
      size: size,
      variant: AppButtonVariant.danger,
      icon: compactLabels ? null : const Icon(Icons.delete_outline_rounded),
      isLoading: loadingDownloads,
      onPressed: busy || !hasSelection ? null : onDeleteDownloads,
    ),
    AppButton(
      key: const Key('movie-subscriptions-batch-unsubscribe-button'),
      label: compactLabels
          ? l10n.subscriptionActionUnsubscribe
          : l10n.subscriptionBatchUnsubscribeWithCount(selection.selectedCount),
      size: size,
      variant: AppButtonVariant.danger,
      icon: compactLabels ? null : const Icon(Icons.bookmark_remove_outlined),
      isLoading: state.isBatchActionRunning(
        MovieSubscriptionBatchAction.unsubscribe,
      ),
      onPressed: busy || !hasSelection
          ? null
          : () => unawaited(
              _confirmBatchUnsubscribe(context, ref, state, selection),
            ),
    ),
  ];
}

/// 批量删除所选影片的下载任务：查询 → 确认 → 提交后端批量任务。
/// 桌面顶栏与移动贴底条的共用实现。
Future<void> _deleteSelectedDownloads(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionManagerState state,
  SelectionController<String> selection, {
  required ValueChanged<bool> onLoadingChanged,
}) async {
  onLoadingChanged(true);
  try {
    final tasks = <DownloadTaskDto>[];
    final result = await runLocalBatchOperation<String>(
      context,
      title: AppLocalizations.of(
        context,
      ).subscriptionBatchQueryingDownloadTasks,
      items: selection.selectedIds.toList(),
      action: (number) async {
        tasks.addAll(
          await ref.refresh(movieDownloadTasksProvider(number).future),
        );
      },
    );
    if (!context.mounted) return;
    onLoadingChanged(false);
    if (result.failed.isNotEmpty) return;
    if (tasks.isEmpty) {
      showToast(
        AppLocalizations.of(context).subscriptionBatchNoDownloadTasks,
        tone: AppToastTone.warning,
      );
      return;
    }
    final deleteFiles = await showDownloadTaskDeleteDialog(
      context,
      tasks: tasks,
    );
    if (!context.mounted || deleteFiles == null) return;
    await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.downloadTaskDelete,
      ids: tasks.map((task) => task.id).toList(growable: false),
      deleteFiles: deleteFiles,
    );
  } catch (error) {
    if (context.mounted) {
      showToast(
        apiErrorMessage(
          error,
          fallback: AppLocalizations.of(
            context,
          ).subscriptionDownloadTasksLoadFailed,
          l10n: AppLocalizations.of(context),
        ),
        tone: AppToastTone.error,
      );
    }
  } finally {
    if (context.mounted) onLoadingChanged(false);
  }
}

/// 批量重新导入所选影片最新一个失败/跳过的下载任务。
///
/// 先按影片逐条查询下载任务（与批量删除共用同一查询范式），每部片只取最新
/// 一个可重提任务，最后一次性提交批量接口；同媒体库仍由后端串行执行。
Future<void> _retriggerSelectedImports(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionManagerState state,
  SelectionController<String> selection, {
  required ValueChanged<bool> onLoadingChanged,
}) async {
  onLoadingChanged(true);
  try {
    final managerProvider = movieSubscriptionManagerProvider(
      state.filter.status,
    );
    final taskIds = <int>[];
    final result = await runLocalBatchOperation<String>(
      context,
      title: AppLocalizations.of(
        context,
      ).subscriptionBatchQueryingDownloadTasks,
      items: selection.selectedIds.toList(),
      action: (number) async {
        final tasks = await ref.refresh(
          movieDownloadTasksProvider(number).future,
        );
        final retriggerTask = tasks
            .where((task) => task.canRetriggerImport)
            .firstOrNull;
        if (retriggerTask != null) {
          taskIds.add(retriggerTask.id);
        }
      },
    );
    if (!context.mounted) return;
    onLoadingChanged(false);
    if (result.failed.isNotEmpty) return;
    if (taskIds.isEmpty) {
      showToast(
        AppLocalizations.of(context).subscriptionBatchNoRetriggerTasks,
        tone: AppToastTone.warning,
      );
      return;
    }
    final accepted = await ref
        .read(downloadsApiProvider)
        .triggerDownloadTaskBatchImport(taskIds);
    if (!context.mounted) return;
    ref.invalidate(downloadTaskCenterProvider);
    await ref.read(managerProvider.notifier).refresh();
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      final skipped = accepted.skippedTaskIds.length;
      showToast(
        skipped > 0
            ? l10n.subscriptionBatchRetriggerSubmittedSkipped(
                accepted.acceptedCount,
                skipped,
              )
            : l10n.subscriptionBatchRetriggerSubmitted(accepted.acceptedCount),
        tone: AppToastTone.warning,
      );
    }
  } catch (error) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.subscriptionBatchRetriggerSubmitFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  } finally {
    if (context.mounted) onLoadingChanged(false);
  }
}

Future<void> _confirmBatchUnsubscribe(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionManagerState state,
  SelectionController<String> selection,
) async {
  final managerProvider = movieSubscriptionManagerProvider(state.filter.status);
  final count = selection.selectedCount;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showAppConfirmDialog(
    context,
    dialogKey: const Key('movie-subscriptions-batch-unsubscribe-dialog'),
    title: l10n.subscriptionBatchUnsubscribeConfirmTitle(count),
    message: l10n.subscriptionBatchUnsubscribeConfirmMessage,
    confirmLabel: l10n.subscriptionActionUnsubscribe,
    danger: true,
  );
  if (!confirmed) return;

  final result = await ref
      .read(managerProvider.notifier)
      .batchUnsubscribe(movieNumbers: selection.selectedIds);
  if (!context.mounted) return;
  selection.replaceSelected(result.allSkippedNumbers);
  await showMovieSubscriptionBatchFeedback(context, result, subscribe: false);
}

// --- 查询说明 ----------------------------------------------------------------

AppNoticeCard _queryExplanationTip(AppLocalizations l10n) => AppNoticeCard(
  leadingIcon: Icons.info_outline_rounded,
  description: l10n.subscriptionQueryExplanation,
);

// --- 列表体 -----------------------------------------------------------------

class _ListBodySliver extends ConsumerWidget {
  const _ListBodySliver({
    required this.onOpenMovie,
    required this.onOpenDownloads,
    required this.mobile,
    required this.selection,
  });

  final void Function(BuildContext context, String movieNumber) onOpenMovie;
  final void Function(BuildContext context, String movieNumber) onOpenDownloads;
  final bool mobile;
  final SelectionController<String> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerProvider = movieSubscriptionManagerProvider(
      ref.watch(movieSubscriptionStatusSelectionProvider),
    );
    // 只订阅 paged 段：多选 / 进行中集合变化时它保持相等，列表 sliver 不整体重建，
    // 每行由 [_RowConsumer] 各自订阅自己的选中 / pending 态。
    // loadMore 的 loading / 失败只影响页脚：这里清成中立值，翻页状态翻转
    // 不重建列表 sliver（页脚由 [PagedLoadMoreFooterSliver] 展示）。
    final asyncPaged = ref.watch(
      managerProvider.select(
        (asyncState) =>
            asyncState.whenData((state) => withoutLoadMoreStatus(state.paged)),
      ),
    );
    final notifier = ref.read(managerProvider.notifier);

    // 不传 fixedItemExtent：错误行是条件渲染、进度行会换行，行高本来就不固定，
    // 强行给固定 extent 会让内容溢出。
    return SliverPagedAsyncSection<
      PagedListState<MovieSubscriptionListItemDto>,
      MovieSubscriptionListItemDto
    >(
      asyncState: asyncPaged,
      pagedOf: (paged) => paged,
      itemSpacing: context.appSpacing.sm,
      initialErrorMessage: AppLocalizations.of(
        context,
      ).errorSubscriptionListLoadFailed,
      emptyMessage: AppLocalizations.of(context).subscriptionListEmptyFiltered,
      emptyBuilder: (context) => const _EmptyState(),
      // loading 用占位订阅渲染真实行，由 [AppSkeletonizer] 灰化。
      skeletonBuilder: (context) {
        final placeholders = movieSubscriptionListItemPlaceholders();
        return AppSkeletonizer(
          enabled: true,
          child: Column(
            children: [
              for (var index = 0; index < placeholders.length; index++) ...[
                if (index > 0) SizedBox(height: context.appSpacing.sm),
                MovieSubscriptionRow(
                  item: placeholders[index],
                  selectionMode: false,
                  isSelected: false,
                  isPending: false,
                  onTap: () {},
                  onOpenDownloads: null,
                  onSearchMagnet: () {},
                  onUnsubscribe: () {},
                  mobile: mobile,
                ),
              ],
            ],
          ),
        );
      },
      initialRetryKey: const Key('movie-subscriptions-initial-retry-button'),
      onReload: () => unawaited(notifier.reload()),
      onLoadMore: () => unawaited(notifier.loadMore()),
      itemBuilder: (context, item, _) => _RowConsumer(
        item: item,
        mobile: mobile,
        onOpenMovie: onOpenMovie,
        onOpenDownloads: onOpenDownloads,
        selection: selection,
      ),
      // 页脚由 [PagedLoadMoreFooterSliver] 独立渲染。
      showLoadMoreFooter: false,
    );
  }
}

/// 分状态的空态文案。
///
/// 待办三态为空是**好消息**，不该用「暂无数据」这种失败口吻打发——说清"没有卡住
/// 的订阅"，并给一个「看全部订阅」的去处，免得用户以为页面坏了。
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerProvider = movieSubscriptionManagerProvider(
      ref.watch(movieSubscriptionStatusSelectionProvider),
    );
    final filter =
        ref.watch(
          managerProvider.select((asyncState) => asyncState.value?.filter),
        ) ??
        MovieSubscriptionFilterState.initial;

    final l10n = AppLocalizations.of(context);
    if (filter.hasSearch) {
      return AppEmptyState(
        key: const Key('movie-subscriptions-empty-state'),
        icon: Icons.search_off_rounded,
        message: l10n.subscriptionEmptyNoSearchMatch(filter.trimmedSearch),
      );
    }

    final (icon, title, message) = switch (filter.status) {
      MovieSubscriptionStatus.missing => (
        Icons.check_circle_outline_rounded,
        l10n.subscriptionEmptyMissingTitle,
        l10n.subscriptionEmptyMissingMessage,
      ),
      MovieSubscriptionStatus.exhausted => (
        Icons.check_circle_outline_rounded,
        l10n.subscriptionEmptyExhaustedTitle,
        l10n.subscriptionEmptyExhaustedMessage,
      ),
      MovieSubscriptionStatus.importFailed => (
        Icons.check_circle_outline_rounded,
        l10n.subscriptionEmptyImportFailedTitle,
        l10n.subscriptionEmptyImportFailedMessage,
      ),
      MovieSubscriptionStatus.failed => (
        Icons.check_circle_outline_rounded,
        l10n.subscriptionEmptyFailedTitle,
        l10n.subscriptionEmptyFailedMessage,
      ),
      MovieSubscriptionStatus.pending => (
        Icons.hourglass_empty_rounded,
        l10n.subscriptionEmptyPendingTitle,
        l10n.subscriptionEmptyPendingMessage,
      ),
      MovieSubscriptionStatus.downloading => (
        Icons.download_outlined,
        l10n.subscriptionEmptyDownloadingTitle,
        l10n.subscriptionEmptyDownloadingMessage,
      ),
      MovieSubscriptionStatus.imported => (
        Icons.inbox_outlined,
        l10n.subscriptionEmptyImportedTitle,
        l10n.subscriptionEmptyImportedMessage,
      ),
      MovieSubscriptionStatus.unknown || null => (
        Icons.bookmark_border_rounded,
        l10n.subscriptionEmptyNoneTitle,
        l10n.subscriptionEmptyNoneMessage,
      ),
    };

    final isFilteredView = filter.status != null;
    return Column(
      children: [
        AppEmptyState(
          key: const Key('movie-subscriptions-empty-state'),
          icon: icon,
          title: title,
          message: message,
        ),
        if (isFilteredView) ...[
          SizedBox(height: context.appSpacing.md),
          AppButton(
            key: const Key('movie-subscriptions-empty-see-all-button'),
            label: l10n.subscriptionEmptySeeAll,
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed: () => ref
                .read(movieSubscriptionStatusSelectionProvider.notifier)
                .select(null),
          ),
        ],
      ],
    );
  }
}

/// 单行的订阅者：只 watch 自己的选中 / pending 态，避免整表重建。
class _RowConsumer extends HookConsumerWidget {
  const _RowConsumer({
    required this.item,
    required this.onOpenMovie,
    required this.onOpenDownloads,
    required this.mobile,
    required this.selection,
  });

  final MovieSubscriptionListItemDto item;
  final void Function(BuildContext context, String movieNumber) onOpenMovie;
  final void Function(BuildContext context, String movieNumber) onOpenDownloads;
  final bool mobile;
  final SelectionController<String> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerProvider = movieSubscriptionManagerProvider(
      ref.watch(movieSubscriptionStatusSelectionProvider),
    );
    final selectionMode = selection.active;
    final isSelected = selection.isSelected(item.movieNumber);
    final isPending = ref.watch(
      managerProvider.select(
        (asyncState) => asyncState.value?.isPending(item.movieNumber) ?? false,
      ),
    );
    final notifier = ref.read(managerProvider.notifier);
    final deleting = useState(false);
    final retriggering = useState(false);
    final tasksProvider = movieDownloadTasksProvider(item.movieNumber);
    final tasks = ref.watch(tasksProvider).value;
    // 重复下载可能留下多个已完成任务；列表按创建时间倒序，取最新一个看文件。
    final completedTask = tasks
        ?.where((task) => task.state == 'completed')
        .firstOrNull;
    // 与下载任务中心同一规则：导入失败或已跳过的任务可重新导入，取最新一个。
    final retriggerTask = tasks
        ?.where((task) => task.canRetriggerImport)
        .firstOrNull;

    void openFiles() {
      final task = completedTask!;
      unawaited(
        showDownloadTaskFilesDialog(
          context: context,
          taskId: task.id,
          movieNumber: item.movieNumber,
          title: item.title,
        ),
      );
    }

    Future<void> retriggerImport() async {
      if (retriggering.value) return;
      final task = retriggerTask!;
      retriggering.value = true;
      try {
        await ref.read(downloadsApiProvider).triggerDownloadTaskImport(task.id);
        if (!context.mounted) return;
        showToast(
          AppLocalizations.of(context).subscriptionImportTaskSubmitted,
          tone: AppToastTone.success,
        );
        ref.invalidate(downloadTaskCenterProvider);
        await notifier.refresh();
      } catch (error) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          showToast(
            apiErrorMessage(
              error,
              fallback: l10n.subscriptionImportSubmitFailed,
              l10n: l10n,
            ),
            tone: AppToastTone.error,
          );
        }
      } finally {
        if (context.mounted) retriggering.value = false;
      }
    }

    Future<void> deleteDownloads() async {
      deleting.value = true;
      try {
        final currentTasks = await ref.refresh(tasksProvider.future);
        if (!context.mounted) return;
        if (currentTasks.isEmpty) {
          showToast(
            AppLocalizations.of(context).subscriptionDownloadTaskMissing,
            tone: AppToastTone.warning,
          );
          await notifier.refresh();
          return;
        }
        deleting.value = false;
        final deleteFiles = await showDownloadTaskDeleteDialog(
          context,
          tasks: currentTasks,
        );
        if (!context.mounted || deleteFiles == null) return;
        await submitBatchOperation(
          context,
          ref,
          operation: BatchOperationType.downloadTaskDelete,
          ids: currentTasks.map((task) => task.id).toList(growable: false),
          deleteFiles: deleteFiles,
        );
      } catch (error) {
        if (context.mounted) {
          showToast(
            apiErrorMessage(
              error,
              fallback: AppLocalizations.of(
                context,
              ).subscriptionDownloadTasksLoadFailed,
              l10n: AppLocalizations.of(context),
            ),
            tone: AppToastTone.error,
          );
        }
      } finally {
        if (context.mounted) deleting.value = false;
      }
    }

    void searchMagnet() {
      showMovieMagnetSearchDialog(
        context: context,
        movieNumber: item.movieNumber,
      );
    }

    // 移动端「更多」：先弹底部操作表，再把选中的动作派发到现有实现。
    Future<void> openActions() async {
      final action = await showMovieSubscriptionRowActions(
        context: context,
        movieNumber: item.movieNumber,
        movieTitle: item.title,
        hasDownloads: tasks?.isNotEmpty == true,
        hasFiles: completedTask != null,
        canRetriggerImport: retriggerTask != null,
      );
      if (!context.mounted || action == null) return;
      switch (action) {
        case MovieSubscriptionRowAction.openDownloads:
          onOpenDownloads(context, item.movieNumber);
        case MovieSubscriptionRowAction.viewFiles:
          openFiles();
        case MovieSubscriptionRowAction.retriggerImport:
          await retriggerImport();
        case MovieSubscriptionRowAction.searchMagnet:
          searchMagnet();
        case MovieSubscriptionRowAction.deleteDownloads:
          await deleteDownloads();
        case MovieSubscriptionRowAction.unsubscribe:
          await _unsubscribeRow(context, ref, item.movieNumber);
      }
    }

    return MovieSubscriptionRow(
      item: item,
      mobile: mobile,
      selectionMode: selectionMode,
      isSelected: isSelected,
      isPending: isPending || deleting.value,
      onTap: selection.tapHandler(
        item.movieNumber,
        () => onOpenMovie(context, item.movieNumber),
      ),
      onOpenDownloads: tasks?.isNotEmpty == true
          ? () => onOpenDownloads(context, item.movieNumber)
          : null,
      onViewFiles: completedTask == null ? null : openFiles,
      onRetriggerImport: retriggerTask == null ? null : retriggerImport,
      isRetriggering: retriggering.value,
      onOpenActions: () => unawaited(openActions()),
      onSearchMagnet: searchMagnet,
      onDeleteDownloads: tasks == null || tasks.isEmpty
          ? null
          : deleteDownloads,
      onUnsubscribe: () =>
          unawaited(_unsubscribeRow(context, ref, item.movieNumber)),
    );
  }
}

/// 单条取消订阅不弹确认：它是可逆的（重新订阅即可）、也不删任何文件，
/// 二次确认只会让日常清理变啰嗦。批量才确认——那一下影响面大得多。
Future<void> _unsubscribeRow(
  BuildContext context,
  WidgetRef ref,
  String movieNumber,
) async {
  final l10n = AppLocalizations.of(context);
  final managerProvider = movieSubscriptionManagerProvider(
    ref.read(movieSubscriptionStatusSelectionProvider),
  );
  final result = await ref
      .read(managerProvider.notifier)
      .unsubscribe(movieNumber);
  showMovieSubscriptionFeedback(result, l10n: l10n);
}
