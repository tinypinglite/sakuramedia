import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/actions/media_row_action_flow.dart';
import 'package:sakuramedia/features/media/presentation/media_placeholders.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_card.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';

/// 「失效媒体」列表：后端只提供列表和删除，因此每条记录直接允许删除。
///
/// 普通态点击卡片打开媒体操作弹层；选择态点击卡片切换勾选。桌面和移动端
/// 都从顶栏「选择」进入选择态，移动端仍可长按卡片直接进入选择态。
class InvalidMediaSection extends ConsumerStatefulWidget {
  const InvalidMediaSection({
    super.key,
    required this.scrollController,
    required this.onRefresh,
    this.refreshError,
    this.onOpenMovieDetail,
    this.mobile = false,
  });

  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final String? refreshError;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;
  final bool mobile;

  @override
  ConsumerState<InvalidMediaSection> createState() =>
      _InvalidMediaSectionState();
}

class _InvalidMediaSectionState extends ConsumerState<InvalidMediaSection>
    with MultiSelectStateMixin<InvalidMediaSection, int> {
  @override
  List<int> get selectionOrderedIds =>
      ref
          .read(invalidMediaProvider)
          .value
          ?.paged
          .items
          .map((item) => item.id)
          .toList(growable: false) ??
      const <int>[];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = AppFixedHeaderLayout(
      header: _InvalidMediaHeader(
        mobile: widget.mobile,
        selectionMode: selectionMode,
        selectedIds: selectedIds,
        isAllSelected: (ids) => isAllSelected(ids),
        onEnterSelection: enterSelection,
        onExitSelection: exitSelection,
        onToggleAll: toggleSelectAll,
        onBatchDelete: _batchDelete,
        onRefresh: widget.onRefresh,
        refreshError: widget.refreshError,
      ),
      headerBottomSpacing: context.appSpacing.lg,
      child: CustomScrollView(
        key: const Key('invalid-media-scroll-view'),
        controller: widget.scrollController,
        slivers: [
          _InvalidMediaBodySliver(
            mobile: widget.mobile,
            selectionMode: selectionMode,
            selectedIds: selectedIds,
            onSelectionGesture: (id, gesture) =>
                handleSelectTap(id, gesture: gesture),
            onOpenMovieDetail: widget.onOpenMovieDetail,
            onEnterSelection: (id) => enterSelection(initial: id),
          ),
          // loadMore 的 loading / 失败提示独立订阅：翻页状态翻转只重建这个
          // footer，不重建上面的列表本体。
          PagedLoadMoreFooterSliver(
            watchFooter: (ref) => ref.watch(
              invalidMediaProvider.select(
                (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
              ),
            ),
            onLoadMore: (ref) =>
                unawaited(ref.read(invalidMediaProvider.notifier).loadMore()),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xxl)),
          ...bottomSafeAreaSliver(context),
        ],
      ),
    );

    if (!widget.mobile || !selectionMode) return content;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.mediaDelete,
    ]);
    return Column(
      children: [
        Expanded(child: content),
        AppSelectionBottomBar(
          leading: Text(
            l10n.mediaListSelectedItems(selectedCount),
            key: const Key('invalid-media-bottom-selection-count'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          actions: [
            AppButton(
              key: const Key('invalid-media-batch-delete-button'),
              label: l10n.commonDelete,
              variant: AppButtonVariant.danger,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: selectedCount == 0 || submitting
                  ? null
                  : () => _batchDelete(selectedIds.toList(growable: false)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _batchDelete(List<int> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      dialogKey: const Key('invalid-media-batch-delete-dialog'),
      confirmKey: const Key('invalid-media-batch-delete-confirm-button'),
      cancelKey: const Key('invalid-media-batch-delete-cancel-button'),
      title: l10n.mediaListInvalidBatchDeleteTitle,
      message: l10n.mediaListInvalidBatchDeleteMessage(mediaIds.length),
      confirmLabel: l10n.commonDelete,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.mediaDelete,
      ids: mediaIds,
    );
    if (!mounted) return;
    if (submitted) exitSelection();
  }
}

class _InvalidMediaHeader extends ConsumerWidget {
  const _InvalidMediaHeader({
    required this.mobile,
    required this.selectionMode,
    required this.selectedIds,
    required this.isAllSelected,
    required this.onEnterSelection,
    required this.onExitSelection,
    required this.onToggleAll,
    required this.onBatchDelete,
    required this.onRefresh,
    required this.refreshError,
  });

  final bool mobile;
  final bool selectionMode;
  final Set<int> selectedIds;
  final bool Function(List<int> ids) isAllSelected;
  final VoidCallback onEnterSelection;
  final VoidCallback onExitSelection;
  final void Function(List<int> ids) onToggleAll;
  final Future<void> Function(List<int> mediaIds) onBatchDelete;
  final Future<void> Function() onRefresh;
  final String? refreshError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      invalidMediaProvider.select(
        (asyncState) => (
          total: asyncState.value?.paged.total ?? 0,
          ids:
              asyncState.value?.paged.items
                  .map((item) => item.id)
                  .toList(growable: false) ??
              const <int>[],
          isInitialLoading: asyncState.isLoading && !asyncState.hasValue,
        ),
      ),
    );
    final loadedIds = state.ids;
    final selectedCount = selectedIds.length;
    final allSelected = isAllSelected(loadedIds);

    if (mobile && selectionMode) {
      return AppMobileSelectionHeader(
        key: const Key('invalid-media-selection-header'),
        selectionLabel: l10n.mediaListSelectedItems(selectedCount),
        exitKey: const Key('invalid-media-exit-selection-button'),
        onExitSelection: onExitSelection,
        selectAllKey: const Key('invalid-media-select-all-button'),
        selectAllTooltip: allSelected
            ? l10n.mediaListClearSelectAllLoaded
            : l10n.mediaListSelectAllLoaded,
        onToggleAll: loadedIds.isEmpty ? null : () => onToggleAll(loadedIds),
      );
    }

    if (!mobile && selectionMode) {
      final submitting = watchBatchOperationSubmitting(ref, const [
        BatchOperationType.mediaDelete,
      ]);
      return AppGlassSelectionHeader(
        selectionLabel: l10n.mediaListSelectedRecords(selectedCount),
        countKey: const Key('invalid-media-selection-count'),
        selectAllKey: const Key('invalid-media-select-all-button'),
        exitKey: const Key('invalid-media-exit-selection-button'),
        selectAllLabel: allSelected
            ? l10n.mediaListClearSelectAllLoaded
            : l10n.mediaListSelectAllLoaded,
        onToggleAll: loadedIds.isEmpty ? null : () => onToggleAll(loadedIds),
        onExitSelection: onExitSelection,
        actions: <AppGlassSelectionAction>[
          AppGlassSelectionAction(
            key: const Key('invalid-media-batch-delete-button'),
            label: l10n.mediaListBatchDelete(selectedCount),
            icon: Icons.delete_outline_rounded,
            foregroundColor: context.appTextPalette.error,
            onTap: selectedCount == 0 || submitting
                ? null
                : () => onBatchDelete(selectedIds.toList(growable: false)),
          ),
        ],
      );
    }

    final description = Text(
      l10n.mediaListInvalidDescription,
      key: const Key('invalid-media-section-description'),
      maxLines: mobile ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.muted,
      ),
    );
    final totalText = l10n.mediaListTotalInvalidItems(state.total);
    final canEnterSelection = loadedIds.isNotEmpty && !state.isInitialLoading;
    if (!mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppGlassListHeader(
            leading: AppGlassHeaderGroup(
              children: <Widget>[
                AppGlassHeaderText(
                  key: const Key('invalid-media-total-text'),
                  label: totalText,
                ),
                AppGlassHeaderText(
                  key: const Key('invalid-media-section-description'),
                  label: l10n.mediaListInvalidDescription,
                ),
              ],
            ),
            trailing: AppGlassHeaderGroup(
              children: <Widget>[
                AppGlassHeaderButton(
                  key: const Key('invalid-media-enter-selection-button'),
                  icon: Icons.check_circle_outline,
                  label: l10n.mediaListEnterSelection,
                  enabled: canEnterSelection,
                  onTap: canEnterSelection ? onEnterSelection : () {},
                ),
                AppGlassHeaderButton(
                  key: const Key('invalid-media-refresh-button'),
                  icon: Icons.refresh_rounded,
                  label: state.isInitialLoading
                      ? l10n.mediaListRefreshing
                      : l10n.commonRefresh,
                  enabled: !state.isInitialLoading,
                  onTap: state.isInitialLoading
                      ? () {}
                      : () => unawaited(onRefresh()),
                ),
              ],
            ),
          ),
          if (refreshError != null)
            Padding(
              padding: EdgeInsets.only(top: context.appSpacing.sm),
              child: AppInlineErrorBanner(
                message: refreshError!,
                onRetry: onRefresh,
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        description,
        SizedBox(height: context.appSpacing.sm),
        AppMobileListHeader(
          leading: AppMobileHeaderText(
            key: const Key('invalid-media-total-text'),
            countLabel: totalText,
          ),
          actions: <Widget>[
            AppGlassIconButton(
              key: const Key('invalid-media-enter-selection-button'),
              tooltip: l10n.mediaListEnterSelection,
              icon: Icons.check_circle_outline,
              onPressed: canEnterSelection ? onEnterSelection : null,
            ),
            AppGlassIconButton(
              key: const Key('invalid-media-refresh-button'),
              tooltip: state.isInitialLoading
                  ? l10n.mediaListRefreshing
                  : l10n.commonRefresh,
              icon: Icons.refresh_rounded,
              onPressed: state.isInitialLoading
                  ? null
                  : () => unawaited(onRefresh()),
            ),
          ],
        ),
        if (refreshError != null)
          Padding(
            padding: EdgeInsets.only(top: context.appSpacing.sm),
            child: AppInlineErrorBanner(
              message: refreshError!,
              onRetry: onRefresh,
            ),
          ),
      ],
    );
  }
}

class _InvalidMediaBodySliver extends ConsumerWidget {
  const _InvalidMediaBodySliver({
    required this.mobile,
    required this.selectionMode,
    required this.selectedIds,
    required this.onSelectionGesture,
    this.onOpenMovieDetail,
    required this.onEnterSelection,
  });

  final bool mobile;
  final bool selectionMode;
  final Set<int> selectedIds;
  final void Function(int id, SelectionGesture gesture) onSelectionGesture;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;
  final ValueChanged<int> onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // loadMore 的 loading / 失败只影响页脚：这里清成中立值，翻页状态翻转
    // 不重建列表 sliver（页脚由 [PagedLoadMoreFooterSliver] 展示）。
    final asyncPaged = ref.watch(
      invalidMediaProvider.select(
        (asyncState) =>
            asyncState.whenData((state) => withoutLoadMoreStatus(state.paged)),
      ),
    );
    return SliverPagedAsyncSection<
      PagedListState<InvalidMediaDto>,
      InvalidMediaDto
    >(
      asyncState: asyncPaged,
      pagedOf: (state) => state,
      itemSpacing: context.appSpacing.md,
      initialErrorMessage: l10n.errorInvalidMediaLoadFailed,
      emptyMessage: l10n.mediaListInvalidEmpty,
      // loading 用占位媒体渲染真实行，由 [AppSkeletonizer] 灰化。
      skeletonBuilder: (context) {
        final placeholders = invalidMediaPlaceholders();
        return AppSkeletonizer(
          enabled: true,
          child: Column(
            children: [
              for (var index = 0; index < placeholders.length; index++) ...[
                if (index > 0) SizedBox(height: context.appSpacing.md),
                _InvalidMediaRowConsumer(
                  item: placeholders[index],
                  mobile: mobile,
                  selectionMode: false,
                  selected: false,
                  onSelectionGesture: (_) {},
                  onOpenMovieDetail: null,
                  onEnterSelection: () {},
                ),
              ],
            ],
          ),
        );
      },
      initialRetryKey: const Key('invalid-media-initial-retry-button'),
      onReload: () =>
          unawaited(ref.read(invalidMediaProvider.notifier).reload()),
      onLoadMore: () =>
          unawaited(ref.read(invalidMediaProvider.notifier).loadMore()),
      itemBuilder: (context, item, _) => _InvalidMediaRowConsumer(
        item: item,
        mobile: mobile,
        selectionMode: selectionMode,
        selected: selectedIds.contains(item.id),
        onSelectionGesture: (gesture) => onSelectionGesture(item.id, gesture),
        onOpenMovieDetail: onOpenMovieDetail,
        onEnterSelection: () => onEnterSelection(item.id),
      ),
      // 页脚由 PagedLoadMoreFooterSliver 独立渲染。
      showLoadMoreFooter: false,
    );
  }
}

class _InvalidMediaRowConsumer extends ConsumerWidget {
  const _InvalidMediaRowConsumer({
    required this.item,
    required this.mobile,
    required this.selectionMode,
    required this.selected,
    required this.onSelectionGesture,
    required this.onOpenMovieDetail,
    required this.onEnterSelection,
  });

  final InvalidMediaDto item;
  final bool mobile;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<SelectionGesture> onSelectionGesture;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;
  final VoidCallback onEnterSelection;

  Future<void> _handleDelete(
    WidgetRef ref,
    BuildContext context,
    InvalidMediaDto item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.mediaListInvalidDeleteTitle,
      message: l10n.mediaListInvalidDeleteMessage(item.displayTitle(l10n)),
      confirmLabel: l10n.commonDelete,
      danger: true,
      dialogKey: const Key('invalid-media-delete-confirm-dialog'),
      confirmKey: const Key('invalid-media-delete-confirm-button'),
      cancelKey: const Key('invalid-media-delete-cancel-button'),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(invalidMediaProvider.notifier)
          .deleteInvalidMedia(mediaId: item.id);
      if (context.mounted)
        showToast(l10n.mediaListInvalidDeleted, tone: AppToastTone.success);
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaListInvalidDeleteFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref) {
    return openMediaRowActions(
      context,
      ref,
      _toMediaListItem(item),
      mobile: mobile,
      onOpenMovieDetail: onOpenMovieDetail,
      previewWhenNoActions: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(
      invalidMediaProvider.select(
        (asyncState) => asyncState.value?.deletingMediaId,
      ),
    );
    final librariesById = ref.watch(
      mediaLibrariesProvider.select(
        (asyncState) =>
            asyncState.value?.librariesById ?? const <int, MediaLibraryDto>{},
      ),
    );
    final library = item.libraryId == null
        ? null
        : librariesById[item.libraryId];
    final isDeleting = actionState == item.id;
    final mediaItem = _toMediaListItem(item);
    return MediaListItemCard(
      keyPrefix: 'invalid-media',
      item: mediaItem,
      library: library,
      mobile: mobile,
      selected: selected,
      onTap: SelectionInteraction.tap(
        active: selectionMode,
        onGesture: onSelectionGesture,
        onNormalTap: () => unawaited(_openActions(context, ref)),
      ),
      onLongPress: mobile && !selectionMode ? onEnterSelection : null,
      onDelete: selectionMode
          ? null
          : () => unawaited(_handleDelete(ref, context, item)),
      isDeleting: isDeleting,
      canDelete: actionState == null,
      showUpdatedAt: !mobile,
      statusMessage: item.displayInvalidReason(AppLocalizations.of(context)),
    );
  }
}

MediaListItemDto _toMediaListItem(InvalidMediaDto item) {
  final kind = item.videoItemId != null
      ? MediaListItemKind.video
      : item.movieNumber != null
      ? MediaListItemKind.jav
      : MediaListItemKind.unknown;
  return MediaListItemDto(
    id: item.id,
    kind: kind,
    movieNumber: item.movieNumber,
    videoItemId: item.videoItemId,
    title: item.movieTitle,
    coverImage: item.coverImage,
    thinCoverImage: item.thinCoverImage,
    libraryId: item.libraryId,
    libraryName: item.libraryName,
    fileName: item.fileName,
    fileSizeBytes: item.fileSizeBytes,
    durationSeconds: 0,
    valid: false,
    createdAt: null,
    updatedAt: item.updatedAt,
  );
}
