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
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_group_paged_slivers.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
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
    final updatingMovieNumber = useState<String?>(null);
    final groups = asyncState.value?.items ?? const <MultiVersionMovieDto>[];
    final selection = useMediaGroupBatchSelection(
      context: context,
      ref: ref,
      groups: groups,
      itemsOf: (group) => group.mediaItems,
      currentGroups: () => ref.read(provider).value?.items ?? const [],
      keyBase: '$keyPrefix-versions',
      confirmTitle: l10n.mediaListVersionsBatchDeleteTitle,
      confirmMessage: l10n.mediaListVersionsBatchDeleteMessage,
      changedMessage: l10n.mediaListVersionsChanged,
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
        selectedIds: selection.selectionMode ? selection.selectedIds : null,
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
          onPressed: updatingMovieNumber.value != null || selection.deleting
              ? null
              : () => unawaited(setProcessed(group, !group.isProcessed)),
        ),
        onToggle: selection.toggle,
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
                onPressed: groups.isEmpty ? null : selection.enterSelection,
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
                  onTap: groups.isEmpty ? () {} : selection.enterSelection,
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
      header: selection.selectionMode
          ? selection.buildHeader(context, mobile: mobile)
          : filterHeader,
      headerBottomSpacing: context.appSpacing.lg,
      child: CustomScrollView(
        key: Key('$keyPrefix-versions-scroll'),
        controller: scrollController,
        slivers: mediaGroupPagedSlivers<MultiVersionMovieDto>(
          context: context,
          description: selection.selectionMode
              ? l10n.mediaListVersionsSelectionHint
              : null,
          asyncState: asyncState,
          skeletonItems: multiVersionMoviePlaceholders(),
          itemBuilder: (context, group, index) => buildGroup(context, group),
          initialErrorMessage: l10n.errorMultiVersionMovieLoadFailed,
          emptyMessage: l10n.mediaListVersionsEmpty,
          initialRetryKey: Key('$keyPrefix-versions-retry'),
          onReload: () => unawaited(ref.read(provider.notifier).reload()),
          onLoadMore: () => unawaited(ref.read(provider.notifier).loadMore()),
          watchFooter: (ref) => ref.watch(
            provider.select((s) => pagedLoadMoreFooterSnapshot(s.value)),
          ),
          footerLoadMore: (ref) =>
              unawaited(ref.read(provider.notifier).loadMore()),
        ),
      ),
    );
    return Column(
      children: [
        Expanded(child: content),
        if (mobile && selection.selectionMode)
          selection.buildBottomBar(context),
      ],
    );
  }
}
