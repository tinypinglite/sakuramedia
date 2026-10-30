import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/media/data/duplicate_media_group_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_placeholders.dart';
import 'package:sakuramedia/features/media/presentation/providers/duplicate_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_file_group_card.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_collection_chips.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';

class DuplicateMediaSection extends HookConsumerWidget {
  const DuplicateMediaSection({
    super.key,
    required this.scrollController,
    required this.kind,
    required this.onKindChanged,
    required this.keyPrefix,
    required this.mobile,
    required this.onRefresh,
    required this.onOpenVideoCollectionDetail,
    this.onOpenMovieDetail,
  });

  final ScrollController scrollController;
  final MediaListItemKind kind;
  final ValueChanged<MediaListItemKind> onKindChanged;
  final String keyPrefix;
  final bool mobile;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext context, int collectionId)
  onOpenVideoCollectionDetail;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = duplicateMediaProvider(kind);
    // 列表本体忽略 loadMore 状态：翻页 loading/失败只重建独立页脚。
    final asyncState = ref.watch(
      provider.select(
        (asyncValue) => asyncValue.whenData(withoutLoadMoreStatus),
      ),
    );
    final groups = asyncState.value?.items ?? const <DuplicateMediaGroupDto>[];
    final spacing = context.appSpacing;
    final selectionMode = useState(false);
    final selectedIds = useState(<int>{});
    final deleting = useState(false);
    final selected = [
      for (final group in groups)
        for (final item in group.mediaItems)
          if (selectedIds.value.contains(item.id)) item,
    ];
    void exitSelection() {
      selectionMode.value = false;
      selectedIds.value = {};
    }

    Future<void> deleteSelected() async {
      if (deleting.value || selected.isEmpty) return;
      final l10n = AppLocalizations.of(context);
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.mediaListDuplicateBatchDeleteTitle,
        message: l10n.mediaListDuplicateBatchDeleteMessage(selected.length),
        confirmLabel: l10n.commonDelete,
        danger: true,
        dialogKey: Key('$keyPrefix-duplicates-batch-confirm-dialog'),
        confirmKey: Key('$keyPrefix-duplicates-batch-confirm'),
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
        exitSelection();
        showToast(l10n.mediaListDuplicateChanged);
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
      if (submitted) exitSelection();
    }

    final deleteButton = AppButton(
      key: Key('$keyPrefix-duplicates-batch-delete'),
      label: l10n.mediaListBatchDeleteSelected,
      icon: const Icon(Icons.delete_outline_rounded),
      variant: AppButtonVariant.danger,
      size: mobile ? AppButtonSize.medium : AppButtonSize.small,
      isLoading: deleting.value,
      onPressed: selected.isEmpty || deleting.value ? null : deleteSelected,
    );

    Future<void> deleteMedia(
      DuplicateMediaGroupDto group,
      MediaListItemDto item,
    ) async {
      final remainingCount = group.mediaItems.length - 1;
      final remainingHint = remainingCount >= 2
          ? l10n.mediaListDuplicateRemainingHint(remainingCount)
          : l10n.mediaListDuplicateNoLongerHint;
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.mediaListDuplicateDeleteTitle,
        message: l10n.mediaListDuplicateDeleteMessage(item.fileName, remainingHint),
        confirmLabel: l10n.commonDelete,
        danger: true,
        dialogKey: Key('$keyPrefix-duplicate-delete-dialog-${item.id}'),
        confirmKey: Key(
          '$keyPrefix-duplicate-delete-confirm-button-${item.id}',
        ),
        cancelKey: Key('$keyPrefix-duplicate-delete-cancel-button-${item.id}'),
        onConfirm: () async {
          await ref
              .read(duplicateMediaProvider(kind).notifier)
              .deleteDuplicateMedia(mediaId: item.id);
        },
        failureFallback: l10n.mediaListDuplicateDeleteFailed,
      );
      if (confirmed && context.mounted) {
        showToast(l10n.mediaListDuplicateDeleted);
      }
    }

    Widget buildGroup(BuildContext context, DuplicateMediaGroupDto group) {
      if (group.mediaItems.isEmpty) return const SizedBox.shrink();
      final first = group.mediaItems.first;
      return MediaFileGroupCard(
        key: Key('$keyPrefix-duplicate-group-${first.id}'),
        items: group.mediaItems,
        countLabel: l10n.mediaListDuplicateCopiesCount(group.mediaCount),
        headerKey: Key('$keyPrefix-duplicate-cover-tap-${first.id}'),
        deleteLabel: l10n.mediaListDuplicateDeleteItem,
        keyPrefix: '$keyPrefix-duplicate',
        mobile: mobile,
        onOpen:
            first.isJav &&
                first.movieNumber != null &&
                onOpenMovieDetail != null
            ? () => onOpenMovieDetail!(context, first.movieNumber!)
            : null,
        onDelete: (item) => unawaited(deleteMedia(group, item)),
        selectedIds: selectionMode.value ? selectedIds.value : null,
        onToggle: (item) {
          final next = {...selectedIds.value};
          if (!next.remove(item.id)) next.add(item.id);
          selectedIds.value = next;
        },
        itemSupplement: (item) {
          final headingDiffers =
              item.displayHeading(l10n) !=
              first.displayHeading(l10n);
          final showCollections = item.isVideo && item.collections.isNotEmpty;
          if (!headingDiffers && !showCollections) {
            return null;
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (headingDiffers)
                if (item.isJav &&
                    item.movieNumber != null &&
                    onOpenMovieDetail != null)
                  AppTextButton(
                    label: item.displayHeading(l10n),
                    size: AppTextButtonSize.xxSmall,
                    onPressed: () =>
                        onOpenMovieDetail!(context, item.movieNumber!),
                  )
                else
                  Text(
                    item.displayHeading(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.medium,
                      tone: AppTextTone.secondary,
                    ),
                  ),
              if (headingDiffers && showCollections)
                SizedBox(width: spacing.sm),
              if (showCollections)
                VideoCollectionChips(
                  collections: item.collections,
                  onCollectionTap: (collection) =>
                      onOpenVideoCollectionDetail(context, collection.id),
                ),
            ],
          );
        },
      );
    }

    final content = AppFixedHeaderLayout(
      header: selectionMode.value
          ? AppSelectionHeaderToolbar(
              countLabel: l10n.mediaListSelectedCopies(selected.length),
              countKey: Key('$keyPrefix-duplicates-selected-count'),
              selectAllLabel: l10n.mediaListClearSelection,
              selectAllKey: Key('$keyPrefix-duplicates-clear-selection'),
              onToggleAll: deleting.value || selected.isEmpty
                  ? null
                  : () => selectedIds.value = {},
              actions: mobile ? [] : [deleteButton],
              exitKey: Key('$keyPrefix-duplicates-exit-selection'),
              onExit: deleting.value ? null : exitSelection,
            )
          : _DuplicateMediaHeader(
              mobile: mobile,
              kind: kind,
              keyPrefix: keyPrefix,
              onKindChanged: (next) {
                exitSelection();
                onKindChanged(next);
              },
              onRefresh: onRefresh,
              onSelect: groups.isEmpty
                  ? null
                  : () => selectionMode.value = true,
            ),
      child: CustomScrollView(
        key: Key('$keyPrefix-duplicate-scroll-view'),
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: spacing.md),
              child: Text(
                selectionMode.value
                    ? l10n.mediaListDuplicateSelectionHint
                    : l10n.mediaListDuplicateDescription,
                key: Key('$keyPrefix-duplicate-description'),
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
            PagedListState<DuplicateMediaGroupDto>,
            DuplicateMediaGroupDto
          >(
            asyncState: asyncState,
            pagedOf: (state) => state,
            itemSpacing: spacing.lg,
            initialErrorMessage: l10n.errorDuplicateMediaLoadFailed,
            emptyMessage: l10n.mediaListDuplicateEmpty,
            // loading 用占位分组渲染真实组卡，由 [AppSkeletonizer] 灰化。
            skeletonBuilder: (context) {
              final placeholders = duplicateMediaGroupPlaceholders();
              return AppSkeletonizer(
                enabled: true,
                child: Column(
                  children: [
                    for (var index = 0;
                        index < placeholders.length;
                        index++) ...[
                      if (index > 0) SizedBox(height: spacing.lg),
                      buildGroup(context, placeholders[index]),
                    ],
                  ],
                ),
              );
            },
            initialRetryKey: Key('$keyPrefix-duplicate-initial-retry-button'),
            onReload: () => unawaited(ref.read(provider.notifier).reload()),
            onLoadMore: () => unawaited(ref.read(provider.notifier).loadMore()),
            itemBuilder: (context, group, index) => buildGroup(context, group),
            // 页脚由 [PagedLoadMoreFooterSliver] 独立渲染。
            showLoadMoreFooter: false,
          ),
          // 页脚独立订阅 loadMore 状态：翻页 loading/失败翻转只重建它。
          PagedLoadMoreFooterSliver(
            watchFooter: (ref) => ref.watch(
              duplicateMediaProvider(
                kind,
              ).select((s) => pagedLoadMoreFooterSnapshot(s.value)),
            ),
            onLoadMore: (ref) => unawaited(
              ref.read(duplicateMediaProvider(kind).notifier).loadMore(),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: spacing.xxl)),
          ...bottomSafeAreaSliver(context),
        ],
      ),
    );
    return Column(
      children: [
        Expanded(child: content),
        if (mobile && selectionMode.value)
          AppSelectionBottomBar(actions: [deleteButton]),
      ],
    );
  }
}

class _DuplicateMediaHeader extends HookConsumerWidget {
  const _DuplicateMediaHeader({
    required this.mobile,
    required this.kind,
    required this.keyPrefix,
    required this.onKindChanged,
    required this.onRefresh,
    required this.onSelect,
  });

  final bool mobile;
  final MediaListItemKind kind;
  final String keyPrefix;
  final ValueChanged<MediaListItemKind> onKindChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 头部只订阅总数与首载状态：翻页 loading/失败不重建头部。
    final header = ref.watch(
      duplicateMediaProvider(kind).select(
        (asyncState) => (
          total: asyncState.value?.total ?? 0,
          isInitialLoading: asyncState.isLoading && !asyncState.hasValue,
        ),
      ),
    );
    final total = header.total;
    final isInitialLoading = header.isInitialLoading;
    final selectedKind = useState(kind);
    void applyKind(MediaListItemKind next) {
      selectedKind.value = next;
      onKindChanged(next);
    }

    Widget filterOptions(BuildContext context) => HookBuilder(
      builder: (context) {
        useListenable(selectedKind);
        return Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: [
            for (final option in [
              MediaListItemKind.jav,
              MediaListItemKind.video,
            ])
              AppTextButton(
                key: Key('$keyPrefix-duplicate-kind-${option.name}'),
                label: option.labelWith(l10n: l10n),
                size: AppTextButtonSize.xSmall,
                isSelected: selectedKind.value == option,
                onPressed: () => applyKind(option),
              ),
          ],
        );
      },
    );

    Widget filterFooter() => HookBuilder(
      builder: (context) {
        useListenable(selectedKind);
        return AppFilterPanelFooter(
          isDefault: selectedKind.value == MediaListItemKind.jav,
          onReset: () => applyKind(MediaListItemKind.jav),
        );
      },
    );

    return AppListHeader(
      filterButtonKey: Key('$keyPrefix-duplicates-filter'),
      filterLabel: kind.labelWith(l10n: l10n),
      filterPanelKey: Key('$keyPrefix-duplicates-filter-panel'),
      filterPanelBuilder: mobile ? null : filterOptions,
      filterPanelFooter: mobile ? null : filterFooter(),
      onFilterTap: mobile
          ? () => showAppBottomDrawer(
              context: context,
              drawerKey: Key('$keyPrefix-duplicates-filter-drawer'),
              maxHeightFactor: 0.8,
              builder: (context) => AppMobileFilterDrawerScaffold(
                footer: filterFooter(),
                child: filterOptions(context),
              ),
            )
          : null,
      informationSlots: [
        AppListHeaderInfo(
          key: Key('$keyPrefix-duplicate-total-text'),
          label: l10n.mediaListTotalGroups(total),
        ),
      ],
      actionSlots: [
        AppSelectionEntryButton(
          key: Key('$keyPrefix-duplicates-select'),
          onPressed: onSelect,
        ),
        AppIconButton(
          key: Key('$keyPrefix-duplicate-refresh-button'),
          tooltip: isInitialLoading
              ? l10n.mediaListRefreshing
              : l10n.commonRefresh,
          icon: const Icon(Icons.refresh_rounded),
          onPressed: isInitialLoading ? null : onRefresh,
        ),
      ],
    );
  }
}
