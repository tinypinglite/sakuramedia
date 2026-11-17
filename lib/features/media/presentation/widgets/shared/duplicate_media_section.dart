import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/features/media/data/duplicate_media_group_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_placeholders.dart';
import 'package:sakuramedia/features/media/presentation/providers/duplicate_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_group_batch_selection.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_file_group_card.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_group_paged_slivers.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_collection_chips.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

class DuplicateMediaSection extends HookConsumerWidget {
  const DuplicateMediaSection({
    super.key,
    required this.scrollController,
    required this.kind,
    required this.onKindChanged,
    required this.keyPrefix,
    required this.mobile,
    required this.onRefresh,
    this.refreshError,
    required this.onOpenVideoCollectionDetail,
    this.onOpenMovieDetail,
  });

  final ScrollController scrollController;
  final MediaListItemKind kind;
  final ValueChanged<MediaListItemKind> onKindChanged;
  final String keyPrefix;
  final bool mobile;
  final Future<void> Function() onRefresh;
  final String? refreshError;
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
    final selection = useMediaGroupBatchSelection(
      context: context,
      ref: ref,
      groups: groups,
      itemsOf: (group) => group.mediaItems,
      currentGroups: () => ref.read(provider).value?.items ?? const [],
      keyBase: '$keyPrefix-duplicates',
      confirmTitle: l10n.mediaListDuplicateBatchDeleteTitle,
      confirmMessage: l10n.mediaListDuplicateBatchDeleteMessage,
      changedMessage: l10n.mediaListDuplicateChanged,
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
        message: l10n.mediaListDuplicateDeleteMessage(
          item.fileName,
          remainingHint,
        ),
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
        showToast(l10n.mediaListDuplicateDeleted, tone: AppToastTone.success);
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
        selectedIds: selection.selectionMode ? selection.selectedIds : null,
        onToggle: selection.toggle,
        itemSupplement: (item) {
          final headingDiffers =
              item.displayHeading(l10n) != first.displayHeading(l10n);
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
      header: selection.selectionMode
          ? selection.buildHeader(context, mobile: mobile)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DuplicateMediaHeader(
                  mobile: mobile,
                  kind: kind,
                  keyPrefix: keyPrefix,
                  onKindChanged: (next) {
                    selection.exitSelection();
                    onKindChanged(next);
                  },
                  onRefresh: onRefresh,
                  onSelect: groups.isEmpty ? null : selection.enterSelection,
                ),
                if (refreshError != null)
                  Padding(
                    padding: EdgeInsets.only(top: spacing.sm),
                    child: AppInlineErrorBanner(
                      message: refreshError!,
                      onRetry: onRefresh,
                    ),
                  ),
              ],
            ),
      headerBottomSpacing: context.appSpacing.lg,
      child: CustomScrollView(
        key: Key('$keyPrefix-duplicate-scroll-view'),
        controller: scrollController,
        slivers: mediaGroupPagedSlivers<DuplicateMediaGroupDto>(
          context: context,
          description: selection.selectionMode
              ? l10n.mediaListDuplicateSelectionHint
              : l10n.mediaListDuplicateDescription,
          descriptionKey: Key('$keyPrefix-duplicate-description'),
          asyncState: asyncState,
          skeletonItems: duplicateMediaGroupPlaceholders(),
          itemBuilder: (context, group, index) => buildGroup(context, group),
          initialErrorMessage: l10n.errorDuplicateMediaLoadFailed,
          emptyMessage: l10n.mediaListDuplicateEmpty,
          initialRetryKey: Key('$keyPrefix-duplicate-initial-retry-button'),
          onReload: () => unawaited(ref.read(provider.notifier).reload()),
          onLoadMore: () => unawaited(ref.read(provider.notifier).loadMore()),
          watchFooter: (ref) => ref.watch(
            duplicateMediaProvider(
              kind,
            ).select((s) => pagedLoadMoreFooterSnapshot(s.value)),
          ),
          footerLoadMore: (ref) => unawaited(
            ref.read(duplicateMediaProvider(kind).notifier).loadMore(),
          ),
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

    Widget filterSection(BuildContext context) => HookBuilder(
      builder: (context) {
        useListenable(selectedKind);
        return AppFilterChoiceSection<MediaListItemKind>(
          title: l10n.mediaListDuplicateKindTitle,
          controlKey: Key('$keyPrefix-duplicates-kind-filter'),
          items: <AppSegmentedItem<MediaListItemKind>>[
            for (final option in [
              MediaListItemKind.jav,
              MediaListItemKind.video,
            ])
              AppSegmentedItem(
                value: option,
                label: option.labelWith(l10n: l10n),
                key: Key('$keyPrefix-duplicate-kind-${option.name}'),
              ),
          ],
          selected: selectedKind.value,
          onChanged: applyKind,
        );
      },
    );

    Widget filterFooter() => HookBuilder(
      builder: (context) {
        useListenable(selectedKind);
        return AppGlassFilterFooter(
          isDefault: selectedKind.value == MediaListItemKind.jav,
          onReset: () => applyKind(MediaListItemKind.jav),
        );
      },
    );

    if (!mobile) {
      return AppGlassListHeader(
        leading: AppGlassFilterPopover(
          panelKey: Key('$keyPrefix-duplicates-filter-panel'),
          footerBuilder: (context, close) => filterFooter(),
          triggerKey: Key('$keyPrefix-duplicates-filter'),
          label: selectedKind.value.labelWith(l10n: l10n),
          info: <Widget>[
            AppGlassHeaderText(
              key: Key('$keyPrefix-duplicate-total-text'),
              label: l10n.mediaListTotalGroups(total),
            ),
          ],
          panelBuilder: filterSection,
        ),
        trailing: AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: Key('$keyPrefix-duplicates-select'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              enabled: onSelect != null,
              onTap: onSelect ?? () {},
            ),
            AppGlassHeaderButton(
              key: Key('$keyPrefix-duplicate-refresh-button'),
              icon: Icons.refresh_rounded,
              label: isInitialLoading
                  ? l10n.mediaListRefreshing
                  : l10n.commonRefresh,
              enabled: !isInitialLoading,
              onTap: isInitialLoading ? () {} : () => unawaited(onRefresh()),
            ),
          ],
        ),
      );
    }

    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: Key('$keyPrefix-duplicate-total-text'),
        countLabel: l10n.mediaListTotalGroups(total),
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: Key('$keyPrefix-duplicates-filter'),
          summary: selectedKind.value.labelWith(l10n: l10n),
          isActive: selectedKind.value != MediaListItemKind.jav,
          onPressed: () => showAppBottomDrawer(
            context: context,
            drawerKey: Key('$keyPrefix-duplicates-filter-drawer'),
            maxHeightFactor: 0.8,
            builder: (context) => AppMobileFilterDrawerScaffold(
              footer: filterFooter(),
              child: filterSection(context),
            ),
          ),
        ),
        AppGlassIconButton(
          key: Key('$keyPrefix-duplicates-select'),
          tooltip: l10n.baseSelect,
          icon: Icons.check_circle_outline,
          onPressed: onSelect,
        ),
        AppGlassIconButton(
          key: Key('$keyPrefix-duplicate-refresh-button'),
          tooltip: isInitialLoading
              ? l10n.mediaListRefreshing
              : l10n.commonRefresh,
          icon: Icons.refresh_rounded,
          onPressed: isInitialLoading ? null : onRefresh,
        ),
      ],
    );
  }
}
