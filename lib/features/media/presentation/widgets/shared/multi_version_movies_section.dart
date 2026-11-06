import 'dart:async';

import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/multi_version_movie_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_placeholders.dart';
import 'package:sakuramedia/features/media/presentation/providers/multi_version_movies_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_group_batch_selection.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_file_group_card.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

class MultiVersionMoviesSection extends HookConsumerWidget {
  const MultiVersionMoviesSection({
    super.key,
    required this.scrollController,
    required this.keyPrefix,
    required this.mobile,
    required this.onOpenMovieDetail,
    required this.includeVr,
    required this.includeFc2,
    required this.includeProcessed,
  });

  final ValueNotifier<bool> includeVr;
  final ValueNotifier<bool> includeFc2;
  final ValueNotifier<bool> includeProcessed;
  final ScrollController scrollController;
  final String keyPrefix;
  final bool mobile;
  final void Function(BuildContext, String) onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = multiVersionMoviesProvider(
      includeVr: includeVr.value,
      includeFc2: includeFc2.value,
      includeProcessed: includeProcessed.value,
    );
    // 列表本体忽略 loadMore 状态：翻页 loading/失败只重建独立页脚。
    final asyncState = ref.watch(
      provider.select(
        (asyncValue) => asyncValue.whenData(withoutLoadMoreStatus),
      ),
    );
    final spacing = context.appSpacing;
    final deleting = useState(false);
    final updatingMovieNumber = useState<String?>(null);
    final groups = asyncState.value?.items ?? const <MultiVersionMovieDto>[];
    final selection = useMediaGroupSelection<MultiVersionMovieDto>(
      currentGroups: () =>
          ref
              .read(
                multiVersionMoviesProvider(
                  includeVr: includeVr.value,
                  includeFc2: includeFc2.value,
                  includeProcessed: includeProcessed.value,
                ),
              )
              .value
              ?.items ??
          const <MultiVersionMovieDto>[],
      itemsOf: (group) => group.mediaItems,
    );
    final selected = selectedMediaGroupItems(
      groups: groups,
      itemsOf: (group) => group.mediaItems,
      selectedIds: selection.selectedIds,
    );

    Future<void> deleteSelected() async {
      if (deleting.value || selected.isEmpty) return;
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.mediaListVersionsBatchDeleteTitle,
        message: l10n.mediaListVersionsBatchDeleteMessage(selected.length),
        confirmLabel: l10n.commonDelete,
        danger: true,
        dialogKey: Key('$keyPrefix-versions-batch-confirm-dialog'),
        confirmKey: Key('$keyPrefix-versions-batch-confirm'),
      );
      if (!confirmed || !context.mounted) return;
      final currentGroups = ref.read(provider).value?.items ?? [];
      final ids = selected.map((item) => item.id).toSet();
      final currentIds = currentGroups
          .expand((group) => group.mediaItems)
          .map((item) => item.id)
          .toSet();
      if (!currentIds.containsAll(ids) ||
          currentGroups.any(
            (group) => group.mediaItems.every((item) => ids.contains(item.id)),
          )) {
        selection.exitSelection();
        showToast(l10n.mediaListVersionsChanged, tone: AppToastTone.success);
        return;
      }
      deleting.value = true;
      final submitted = await submitBatchOperation(
        context,
        ref,
        operation: BatchOperationType.mediaDelete,
        ids: selected.map((item) => item.id).toList(growable: false),
      );
      if (!context.mounted) return;
      deleting.value = false;
      if (submitted) selection.exitSelection();
    }

    final deleteButton = AppButton(
      key: Key('$keyPrefix-versions-batch-delete'),
      label: l10n.mediaListBatchDeleteSelected,
      icon: const Icon(Icons.delete_outline_rounded),
      variant: AppButtonVariant.danger,
      size: mobile ? AppButtonSize.medium : AppButtonSize.small,
      isLoading: deleting.value,
      onPressed: selected.isEmpty || deleting.value ? null : deleteSelected,
    );

    Future<void> refresh() async {
      final message = await ref.read(provider.notifier).refresh();
      if (message != null && context.mounted) showToast(message);
    }

    Future<void> deleteVersion(
      MultiVersionMovieDto group,
      MediaListItemDto item,
    ) async {
      final remaining = group.mediaCount - 1;
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.mediaListVersionsDeleteTitle,
        message: l10n.mediaListVersionsDeleteMessage(item.fileName, remaining),
        confirmLabel: l10n.commonDelete,
        danger: true,
        dialogKey: Key('$keyPrefix-version-delete-dialog-${item.id}'),
        confirmKey: Key('$keyPrefix-version-delete-confirm-${item.id}'),
        cancelKey: Key('$keyPrefix-version-delete-cancel-${item.id}'),
        onConfirm: () async {
          await ref.read(provider.notifier).deleteVersion(item);
        },
        failureFallback: l10n.mediaListVersionsDeleteFailed,
      );
      if (confirmed && context.mounted) {
        showToast(l10n.mediaListVersionsDeleted, tone: AppToastTone.success);
      }
    }

    Future<void> setProcessed(
      MultiVersionMovieDto group,
      bool processed,
    ) async {
      if (updatingMovieNumber.value != null) return;
      updatingMovieNumber.value = group.movieNumber;
      try {
        final notifier = ref.read(provider.notifier);
        if (processed) {
          await notifier.markProcessed(group);
        } else {
          await notifier.clearProcessed(group);
        }
        if (context.mounted) {
          showToast(
            processed
                ? l10n.mediaListVersionsMarkedProcessed
                : l10n.mediaListVersionsMarkedPending,
            tone: AppToastTone.success,
          );
        }
      } catch (error) {
        if (context.mounted) {
          showToast(
            apiErrorMessage(
              error,
              fallback: l10n.mediaListVersionsProcessFailed,
              l10n: l10n,
            ),
            tone: AppToastTone.error,
          );
        }
      } finally {
        updatingMovieNumber.value = null;
      }
    }

    Widget filterOptions(BuildContext context) => HookBuilder(
      builder: (context) {
        useListenable(includeVr);
        useListenable(includeFc2);
        useListenable(includeProcessed);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mediaListVersionsFilterTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final filter in [
                  (
                    label: l10n.mediaListVersionsIncludeVr,
                    state: includeVr,
                    key: 'vr',
                  ),
                  (
                    label: l10n.mediaListVersionsIncludeFc2,
                    state: includeFc2,
                    key: 'fc2',
                  ),
                  (
                    label: l10n.mediaListVersionsIncludeProcessed,
                    state: includeProcessed,
                    key: 'processed',
                  ),
                ])
                  AppFilterChip(
                    key: Key('$keyPrefix-versions-include-${filter.key}'),
                    label: filter.label,
                    selected: filter.state.value,
                    onPressed: () {
                      selection.exitSelection();
                      filter.state.value = !filter.state.value;
                      if (scrollController.hasClients) {
                        scrollController.jumpTo(0);
                      }
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );

    Widget filterFooter() => HookBuilder(
      builder: (context) {
        useListenable(includeVr);
        useListenable(includeFc2);
        useListenable(includeProcessed);
        return AppGlassFilterFooter(
          isDefault:
              !includeVr.value && !includeFc2.value && !includeProcessed.value,
          onReset: () {
            includeVr.value = false;
            includeFc2.value = false;
            includeProcessed.value = false;
            if (scrollController.hasClients) scrollController.jumpTo(0);
          },
        );
      },
    );

    Widget buildGroup(BuildContext context, MultiVersionMovieDto group) {
      final updating = updatingMovieNumber.value == group.movieNumber;
      return MediaFileGroupCard(
        key: Key('$keyPrefix-version-group-${group.movieNumber}'),
        items: group.mediaItems,
        countLabel: l10n.mediaListVersionsCount(group.mediaCount),
        headerKey: Key('$keyPrefix-version-movie-${group.movieNumber}'),
        deleteLabel: l10n.mediaListVersionsDeleteItem,
        keyPrefix: '$keyPrefix-version',
        mobile: mobile,
        onOpen: () => onOpenMovieDetail(context, group.movieNumber),
        onDelete: (item) => unawaited(deleteVersion(group, item)),
        selectedIds: selection.active ? selection.selectedIds : null,
        statusLabel: group.isProcessed
            ? l10n.mediaListVersionsProcessedBadge
            : null,
        footer: AppTextButton(
          key: Key('$keyPrefix-version-processed-${group.movieNumber}'),
          label: group.isProcessed
              ? l10n.mediaListVersionsMarkPending
              : l10n.mediaListVersionsMarkProcessed,
          icon: Icon(
            group.isProcessed
                ? Icons.undo_rounded
                : Icons.check_circle_outline_rounded,
          ),
          size: AppTextButtonSize.xSmall,
          isLoading: updating,
          onPressed: updatingMovieNumber.value != null || deleting.value
              ? null
              : () => unawaited(setProcessed(group, !group.isProcessed)),
        ),
        onToggle: (item) => selection.handleSelectionTap(item.id),
      );
    }

    final filterLabel =
        !includeVr.value && !includeFc2.value && !includeProcessed.value
        ? l10n.mediaListFilterTooltip
        : [
            if (includeVr.value) 'VR',
            if (includeFc2.value) 'FC2',
            if (includeProcessed.value) l10n.mediaListVersionsIncludeProcessed,
          ].join(' / ');
    final totalLabel = l10n.mediaListTotalMovies(asyncState.value?.total ?? 0);

    final selectionHeader = mobile
        ? AppMobileSelectionHeader(
            selectionLabel: l10n.mediaListSelectedCopies(selected.length),
            countKey: Key('$keyPrefix-versions-selected-count'),
            selectAllTooltip: l10n.mediaListClearSelection,
            selectAllKey: Key('$keyPrefix-versions-clear-selection'),
            onToggleAll: deleting.value || selected.isEmpty
                ? null
                : () => selection.clearSelection(),
            exitKey: Key('$keyPrefix-versions-exit-selection'),
            onExitSelection: deleting.value ? null : selection.exitSelection,
          )
        : AppGlassSelectionHeader(
            selectionLabel: l10n.mediaListSelectedCopies(selected.length),
            countKey: Key('$keyPrefix-versions-selected-count'),
            selectAllLabel: l10n.mediaListClearSelection,
            selectAllKey: Key('$keyPrefix-versions-clear-selection'),
            onToggleAll: deleting.value || selected.isEmpty
                ? null
                : () => selection.clearSelection(),
            exitKey: Key('$keyPrefix-versions-exit-selection'),
            onExitSelection: deleting.value ? null : selection.exitSelection,
            actions: <AppGlassSelectionAction>[
              AppGlassSelectionAction(
                key: Key('$keyPrefix-versions-batch-delete'),
                label: l10n.mediaListBatchDeleteSelected,
                icon: Icons.delete_outline_rounded,
                foregroundColor: context.appTextPalette.error,
                onTap: selected.isEmpty || deleting.value
                    ? null
                    : () => unawaited(deleteSelected()),
              ),
            ],
          );

    final filterHeader = mobile
        ? AppMobileListHeader(
            leading: AppMobileHeaderText(
              key: Key('$keyPrefix-versions-total'),
              countLabel: totalLabel,
            ),
            actions: <Widget>[
              AppGlassFilterIconButton(
                key: Key('$keyPrefix-versions-filter'),
                summary: filterLabel,
                isActive:
                    includeVr.value ||
                    includeFc2.value ||
                    includeProcessed.value,
                onPressed: () => showAppBottomDrawer(
                  context: context,
                  drawerKey: Key('$keyPrefix-versions-filter-drawer'),
                  maxHeightFactor: 0.8,
                  builder: (context) => AppMobileFilterDrawerScaffold(
                    footer: filterFooter(),
                    child: filterOptions(context),
                  ),
                ),
              ),
              AppGlassIconButton(
                key: Key('$keyPrefix-versions-select'),
                tooltip: l10n.baseSelect,
                icon: Icons.check_circle_outline,
                onPressed: groups.isEmpty
                    ? null
                    : () => selection.enterSelection(),
              ),
              AppGlassIconButton(
                key: Key('$keyPrefix-versions-refresh'),
                tooltip: l10n.commonRefresh,
                icon: Icons.refresh_rounded,
                onPressed: asyncState.isLoading ? null : refresh,
              ),
            ],
          )
        : AppGlassListHeader(
            leading: AppGlassFilterPopover(
              panelKey: Key('$keyPrefix-versions-filter-panel'),
              footerBuilder: (context, close) => filterFooter(),
              triggerKey: Key('$keyPrefix-versions-filter'),
              label: filterLabel,
              tooltip: l10n.mediaListVersionsFilterTitle,
              info: <Widget>[
                AppGlassHeaderText(
                  key: Key('$keyPrefix-versions-total'),
                  label: totalLabel,
                ),
              ],
              panelBuilder: filterOptions,
            ),
            trailing: AppGlassHeaderGroup(
              children: <Widget>[
                AppGlassHeaderButton(
                  key: Key('$keyPrefix-versions-select'),
                  icon: Icons.check_circle_outline,
                  label: l10n.baseSelect,
                  enabled: groups.isNotEmpty,
                  onTap: groups.isEmpty
                      ? () {}
                      : () => selection.enterSelection(),
                ),
                AppGlassHeaderButton(
                  key: Key('$keyPrefix-versions-refresh'),
                  icon: Icons.refresh_rounded,
                  label: l10n.commonRefresh,
                  enabled: !asyncState.isLoading,
                  onTap: asyncState.isLoading
                      ? () {}
                      : () => unawaited(refresh()),
                ),
              ],
            ),
          );

    final content = AppFixedHeaderLayout(
      header: selection.active ? selectionHeader : filterHeader,
      headerBottomSpacing: context.appSpacing.lg,
      child: CustomScrollView(
        key: Key('$keyPrefix-versions-scroll'),
        controller: scrollController,
        slivers: [
          if (selection.active)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: spacing.md),
                child: Text(
                  l10n.mediaListVersionsSelectionHint,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
            ),
          SliverPagedAsyncSection<
            PagedListState<MultiVersionMovieDto>,
            MultiVersionMovieDto
          >(
            asyncState: asyncState,
            pagedOf: (state) => state,
            itemSpacing: spacing.lg,
            initialErrorMessage: l10n.errorMultiVersionMovieLoadFailed,
            emptyMessage: l10n.mediaListVersionsEmpty,
            // loading 用占位分组渲染真实组卡，由 [AppSkeletonizer] 灰化。
            skeletonBuilder: (context) {
              final placeholders = multiVersionMoviePlaceholders();
              return AppSkeletonizer(
                enabled: true,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < placeholders.length;
                      index++
                    ) ...[
                      if (index > 0) SizedBox(height: spacing.lg),
                      buildGroup(context, placeholders[index]),
                    ],
                  ],
                ),
              );
            },
            initialRetryKey: Key('$keyPrefix-versions-retry'),
            onReload: () => unawaited(ref.read(provider.notifier).reload()),
            onLoadMore: () => unawaited(ref.read(provider.notifier).loadMore()),
            itemBuilder: (context, group, index) => buildGroup(context, group),
            // 页脚由 PagedLoadMoreFooterSliver 独立渲染。
            showLoadMoreFooter: false,
          ),
          PagedLoadMoreFooterSliver(
            watchFooter: (ref) => ref.watch(
              provider.select((s) => pagedLoadMoreFooterSnapshot(s.value)),
            ),
            onLoadMore: (ref) =>
                unawaited(ref.read(provider.notifier).loadMore()),
          ),
          SliverToBoxAdapter(child: SizedBox(height: spacing.xxl)),
          ...bottomSafeAreaSliver(context),
        ],
      ),
    );
    return Column(
      children: [
        Expanded(child: content),
        if (mobile && selection.active)
          AppSelectionBottomBar(actions: [deleteButton]),
      ],
    );
  }
}
