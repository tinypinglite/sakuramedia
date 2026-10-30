import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/duplicate_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/multi_version_movies_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/duplicate_media_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/invalid_media_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_management_row_actions.dart';
import 'package:sakuramedia/features/media/presentation/actions/media_video_mutation_report.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_transfer_target_dialog.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_tag_assignment_editor.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/multi_version_movies_section.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/keep_alive_page.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 删除媒体后同步 videos 域缓存的统一入口（共享规则见
/// `media_video_mutation_report.dart`）。
void _reportDeletedPornboxVideos(
  WidgetRef ref,
  Iterable<MediaListItemDto> items,
) {
  reportDeletedVideoItems(
    items,
    ref.read(videoMutationEventsProvider.notifier).reportDeleted,
  );
}

/// 「媒体管理」双端共享内容（桌面 / 移动壳收敛的 content 层）。
///
/// 提供媒体列表、重复媒体、多版本影片和失效媒体管理。
class MediaManagementContent extends HookConsumerWidget {
  const MediaManagementContent({
    super.key,
    required this.keyPrefix,
    required this.rootKey,
    required this.onOpenMovieDetail,
    required this.onOpenVideoCollectionDetail,
    this.mobile = false,
  });

  final String keyPrefix;
  final Key rootKey;
  final void Function(BuildContext context, String movieNumber)
  onOpenMovieDetail;
  final void Function(BuildContext context, int collectionId)
  onOpenVideoCollectionDetail;
  final bool mobile;

  static const int _duplicateTabIndex = 1;
  static const int _versionsTabIndex = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tabTickerProvider = useSingleTickerProvider();
    final tabController = useMemoized(
      () => TabController(length: 4, vsync: tabTickerProvider),
      [tabTickerProvider],
    );
    useEffect(() => tabController.dispose, [tabController]);
    useListenable(tabController);
    final currentTab = tabController.index;
    final duplicateKind = useState(MediaListItemKind.jav);
    final includeVr = useState(false);
    final includeFc2 = useState(false);
    final versionsProvider = multiVersionMoviesProvider(
      includeVr: includeVr.value,
      includeFc2: includeFc2.value,
    );
    final versionsVisited = useRef(false);
    if (currentTab == _versionsTabIndex) versionsVisited.value = true;
    // 首次访问后由管理页持有订阅，切换 Tab 时保留当前筛选的数据和分页。
    if (versionsVisited.value) ref.watch(versionsProvider);
    // 四个 tab 各持一个滚动控制器：TabBarView 的页面会被保活，共用一个控制器
    // 会同时挂到多个滚动视图上。
    final listScrollController = useScrollController();
    final duplicateScrollController = useScrollController();
    final versionsScrollController = useScrollController();
    final invalidScrollController = useScrollController();
    ref.listen(mediaBrowseProvider.select((value) => value.value?.filter), (
      previous,
      next,
    ) {
      if (previous != null &&
          next != null &&
          previous != next &&
          currentTab == 0 &&
          listScrollController.hasClients) {
        listScrollController.jumpTo(0);
      }
    });

    final isDeleting = useState<bool>(false);
    final isTransferring = useState<bool>(false);
    final isResettingThumbnails = useState<bool>(false);
    final deletingMediaId = useState<int?>(null);
    final transferringMediaId = useState<int?>(null);
    final retryingThumbnailMediaId = useState<int?>(null);
    final selectionMode = useState<bool>(false);

    void exitSelectionMode() {
      selectionMode.value = false;
    }

    return AppPageRefreshScope(
      onRefresh: () => _refreshAll(
        ref,
        currentTab: currentTab,
        duplicateKind: duplicateKind.value,
        versionsProvider: versionsProvider,
      ),
      child: Column(
        key: rootKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTabBar(
            controller: tabController,
            tabs: [
              Tab(key: Key('$keyPrefix-tab-list'), text: l10n.mediaListTabList),
              Tab(
                key: Key('$keyPrefix-tab-duplicates'),
                text: l10n.mediaListTabDuplicates,
              ),
              Tab(
                key: Key('$keyPrefix-tab-versions'),
                text: l10n.mediaListTabVersions,
              ),
              Tab(
                key: Key('$keyPrefix-tab-maintenance'),
                text: l10n.mediaListTabInvalid,
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          Expanded(
            // TabBarView 支持左右滑动切换 tab；页面用 AppKeepAlive 保活，
            // 各 tab 的滚动位置与页内状态在本次访问内保留。
            child: TabBarView(
              key: Key('$keyPrefix-tab-view'),
              controller: tabController,
              children: [
                AppPagedLoadMoreScope(
                  enabled: currentTab == 0,
                  canLoadMore: () =>
                      ref
                          .read(mediaBrowseProvider)
                          .value
                          ?.paged
                          .canAutoLoadMore ??
                      false,
                  onLoadMore: () =>
                      ref.read(mediaBrowseProvider.notifier).loadMore(),
                  child: AppKeepAlive(
                    child: MediaListSection(
                      scrollController: listScrollController,
                      isDeleting: isDeleting.value,
                      isTransferring: isTransferring.value,
                      isResettingThumbnails: isResettingThumbnails.value,
                      onBatchDelete: () => _openBatchDeleteDialog(
                        context,
                        ref,
                        isDeleting,
                        selectionMode,
                      ),
                      onBatchTransfer: () => _openBatchTransferDialog(
                        context,
                        ref,
                        isTransferring,
                        selectionMode,
                      ),
                      onBatchResetThumbnails: () =>
                          _openBatchThumbnailResetDialog(
                            context,
                            ref,
                            isResettingThumbnails,
                            selectionMode,
                          ),
                      onRefresh: () => _refreshAll(
                        ref,
                        currentTab: currentTab,
                        duplicateKind: duplicateKind.value,
                        versionsProvider: versionsProvider,
                      ),
                      onOpenMovieDetail: onOpenMovieDetail,
                      keyPrefix: keyPrefix,
                      mobile: mobile,
                      selectionMode: selectionMode.value,
                      onEnterSelection: () => selectionMode.value = true,
                      onExitSelection: exitSelectionMode,
                      onDeleteItem: (item) => _openSingleDeleteDialog(
                        context,
                        ref,
                        item,
                        deletingMediaId,
                      ),
                      deletingItemId: deletingMediaId,
                      onTransferItem: (item) => _submitTransfer(
                        context,
                        ref,
                        mediaIds: [item.id],
                        isTransferring: isTransferring,
                        transferringMediaId: transferringMediaId,
                      ),
                      transferringItemId: transferringMediaId,
                      onRetryThumbnails: (item) => _handleItemThumbnailAction(
                        context,
                        ref,
                        item,
                        isResettingThumbnails,
                        retryingThumbnailMediaId,
                      ),
                      retryingThumbnailMediaId: retryingThumbnailMediaId,
                      onOpenRowActions: (item) => _openMediaRowActions(
                        context,
                        ref,
                        item,
                        isResettingThumbnails: isResettingThumbnails,
                        retryingThumbnailMediaId: retryingThumbnailMediaId,
                        isTransferring: isTransferring,
                        transferringMediaId: transferringMediaId,
                        deletingMediaId: deletingMediaId,
                      ),
                      onEditTags: (item) =>
                          _editMediaTags(context, ref, item, mobile: mobile),
                    ),
                  ),
                ),
                AppPagedLoadMoreScope(
                  enabled: currentTab == _duplicateTabIndex,
                  canLoadMore: () =>
                      ref
                          .read(duplicateMediaProvider(duplicateKind.value))
                          .value
                          ?.canAutoLoadMore ??
                      false,
                  onLoadMore: () => ref
                      .read(
                        duplicateMediaProvider(duplicateKind.value).notifier,
                      )
                      .loadMore(),
                  child: AppKeepAlive(
                    child: DuplicateMediaSection(
                      key: Key('$keyPrefix-duplicate-media-section'),
                      scrollController: duplicateScrollController,
                      kind: duplicateKind.value,
                      onKindChanged: (next) {
                        if (duplicateKind.value == next) return;
                        duplicateKind.value = next;
                        if (duplicateScrollController.hasClients) {
                          duplicateScrollController.jumpTo(0);
                        }
                      },
                      keyPrefix: keyPrefix,
                      mobile: mobile,
                      onRefresh: () => _refreshAll(
                        ref,
                        currentTab: currentTab,
                        duplicateKind: duplicateKind.value,
                        versionsProvider: versionsProvider,
                      ),
                      onOpenMovieDetail: onOpenMovieDetail,
                      onOpenVideoCollectionDetail: onOpenVideoCollectionDetail,
                    ),
                  ),
                ),
                AppPagedLoadMoreScope(
                  enabled: currentTab == _versionsTabIndex,
                  canLoadMore: () =>
                      ref.read(versionsProvider).value?.canAutoLoadMore ??
                      false,
                  onLoadMore: () =>
                      ref.read(versionsProvider.notifier).loadMore(),
                  child: AppKeepAlive(
                    child: MultiVersionMoviesSection(
                      includeVr: includeVr,
                      includeFc2: includeFc2,
                      scrollController: versionsScrollController,
                      keyPrefix: keyPrefix,
                      mobile: mobile,
                      onOpenMovieDetail: onOpenMovieDetail,
                    ),
                  ),
                ),
                AppPagedLoadMoreScope(
                  enabled: currentTab == 3,
                  canLoadMore: () =>
                      ref
                          .read(invalidMediaProvider)
                          .value
                          ?.paged
                          .canAutoLoadMore ??
                      false,
                  onLoadMore: () =>
                      ref.read(invalidMediaProvider.notifier).loadMore(),
                  child: AppKeepAlive(
                    child: InvalidMediaSection(
                      key: Key('$keyPrefix-invalid-media-section'),
                      scrollController: invalidScrollController,
                      mobile: mobile,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll(
    WidgetRef ref, {
    required int currentTab,
    required MediaListItemKind duplicateKind,
    required MultiVersionMoviesProvider versionsProvider,
  }) async {
    final refreshes = <Future<String?>>[
      ref.read(mediaBrowseProvider.notifier).refresh(),
      ref.read(invalidMediaProvider.notifier).refresh(),
      ref.read(mediaLibrariesProvider.notifier).refresh(),
    ];
    if (currentTab == _duplicateTabIndex) {
      refreshes.add(
        ref.read(duplicateMediaProvider(duplicateKind).notifier).refresh(),
      );
    }
    if (currentTab == _versionsTabIndex) {
      refreshes.add(ref.read(versionsProvider.notifier).refresh());
    }
    final results = await Future.wait<String?>(refreshes);
    for (final message in results) {
      if (message != null) showToast(message);
    }
  }

  Future<void> _openBatchDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> isDeleting,
    ValueNotifier<bool> selectionMode,
  ) async {
    if (isDeleting.value) return;
    final l10n = AppLocalizations.of(context);
    final browseState = ref.read(mediaBrowseProvider).value;
    if (browseState == null) return;
    final selectedIds = browseState.selectedIds.toList(growable: false);
    if (selectedIds.isEmpty) return;

    final confirmed = await showAppConfirmDialog(
      context,
      dialogKey: const Key('media-management-batch-delete-dialog'),
      confirmKey: const Key('media-management-batch-delete-confirm-button'),
      cancelKey: const Key('media-management-batch-delete-cancel-button'),
      title: l10n.mediaListBatchDeleteTitle,
      message: l10n.mediaListBatchDeleteMessage(selectedIds.length),
      confirmLabel: l10n.commonDelete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;

    isDeleting.value = true;
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.mediaDelete,
      ids: selectedIds,
    );
    if (!context.mounted) {
      return;
    }
    isDeleting.value = false;
    if (submitted) {
      ref.read(mediaBrowseProvider.notifier).clearSelection();
      selectionMode.value = false;
    }
  }

  Future<void> _openSingleDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    MediaListItemDto item,
    ValueNotifier<int?> deletingMediaId,
  ) async {
    if (deletingMediaId.value != null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      dialogKey: Key('media-management-delete-dialog-${item.id}'),
      confirmKey: Key('media-management-delete-confirm-${item.id}'),
      cancelKey: Key('media-management-delete-cancel-${item.id}'),
      title: l10n.mediaListDeleteTitle,
      message: l10n.mediaListDeleteMessage(item.fileName),
      confirmLabel: l10n.commonDelete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;

    deletingMediaId.value = item.id;
    try {
      await ref.read(mediaApiProvider).deleteMedia(mediaId: item.id);
      ref.read(mediaBrowseProvider.notifier).removeItemsByIds([item.id]);
      _reportDeletedPornboxVideos(ref, [item]);
      if (context.mounted) showToast(l10n.mediaListDeleteSuccess);
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaListDeleteFailed,
            l10n: l10n,
          ),
        );
      }
    } finally {
      if (context.mounted && deletingMediaId.value == item.id) {
        deletingMediaId.value = null;
      }
    }
  }

  Future<void> _openBatchTransferDialog(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> isTransferring,
    ValueNotifier<bool> selectionMode,
  ) async {
    final browseState = ref.read(mediaBrowseProvider).value;
    if (browseState == null || browseState.selectedIds.isEmpty) return;
    await _submitTransfer(
      context,
      ref,
      mediaIds: browseState.selectedIds.toList(growable: false),
      isTransferring: isTransferring,
      selectionMode: selectionMode,
    );
  }

  /// 单条与批量共用的迁移：取候选 → 选目标库 → 提交任务。
  ///
  /// [selectionMode] 仅批量入口传入（成功后退出移动端多选态）；
  /// [transferringMediaId] 仅单项入口传入（标记对应卡片 loading）。
  Future<void> _submitTransfer(
    BuildContext context,
    WidgetRef ref, {
    required List<int> mediaIds,
    required ValueNotifier<bool> isTransferring,
    ValueNotifier<bool>? selectionMode,
    ValueNotifier<int?>? transferringMediaId,
  }) async {
    if (isTransferring.value || mediaIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    isTransferring.value = true;
    transferringMediaId?.value = mediaIds.first;
    try {
      final mediaApi = ref.read(mediaApiProvider);
      final candidates = await mediaApi.getMediaTransferCandidates(
        mediaIds: mediaIds,
      );
      if (!context.mounted) return;
      isTransferring.value = false;
      // 选目标库期间不显示卡片 loading，避免转圈一直转。
      transferringMediaId?.value = null;
      if (candidates.targets.isEmpty) {
        showToast(l10n.mediaListTransferNoTarget);
        return;
      }
      final targetLibraryId = await showMediaTransferTargetDialog(
        context,
        selectedCount: mediaIds.length,
        candidates: candidates,
      );
      if (targetLibraryId == null || !context.mounted) return;
      isTransferring.value = true;
      transferringMediaId?.value = mediaIds.first;
      final accepted = await mediaApi.createMediaTransfer(
        mediaIds: mediaIds,
        targetLibraryId: targetLibraryId,
      );
      ref.read(mediaBrowseProvider.notifier).clearSelection();
      selectionMode?.value = false;
      showToast(l10n.mediaListTransferSubmitted(accepted.taskRunId));
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaListTransferSubmitFailed,
            l10n: l10n,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        isTransferring.value = false;
        transferringMediaId?.value = null;
      }
    }
  }

  Future<void> _openBatchThumbnailResetDialog(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> isResettingThumbnails,
    ValueNotifier<bool> selectionMode,
  ) async {
    if (isResettingThumbnails.value) return;
    final l10n = AppLocalizations.of(context);
    final browseState = ref.read(mediaBrowseProvider).value;
    if (browseState == null || browseState.selectedIds.isEmpty) return;
    final selectedIds = browseState.selectedIds.toList(growable: false);
    // 「已完成」筛选下的同一入口是破坏性的重新生成：删除已有缩略图后再生成。
    final force =
        browseState.filter.thumbnailGenerationState ==
        MediaBrowseThumbnailGenerationFilter.succeeded;

    final confirmed = await showAppConfirmDialog(
      context,
      dialogKey: const Key('media-management-batch-reset-thumbnails-dialog'),
      confirmKey: const Key(
        'media-management-batch-reset-thumbnails-confirm-button',
      ),
      cancelKey: const Key(
        'media-management-batch-reset-thumbnails-cancel-button',
      ),
      title: force
          ? l10n.mediaListThumbnailRegenerateTitle
          : l10n.mediaListThumbnailRetryTitle,
      message: force
          ? l10n.mediaListThumbnailBatchRegenerateMessage(selectedIds.length)
          : l10n.mediaListThumbnailBatchRetryMessage(selectedIds.length),
      confirmLabel: force
          ? l10n.mediaListThumbnailRegenerateConfirm
          : l10n.commonRetry,
    );
    if (!confirmed || !context.mounted) return;

    await _resetThumbnails(
      context,
      ref,
      mediaIds: selectedIds,
      isResettingThumbnails: isResettingThumbnails,
      selectionMode: selectionMode,
      force: force,
    );
  }

  /// 单项缩略图操作分发：失败态直接重试（保持原行为）；已完成态先确认再删除重生成。
  Future<void> _handleItemThumbnailAction(
    BuildContext context,
    WidgetRef ref,
    MediaListItemDto item,
    ValueNotifier<bool> isResettingThumbnails,
    ValueNotifier<int?> retryingThumbnailMediaId,
  ) async {
    final force =
        item.thumbnailGenerationState ==
        MediaThumbnailGenerationState.succeeded;
    if (force) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showAppConfirmDialog(
        context,
        dialogKey: const Key(
          'media-management-single-regenerate-thumbnails-dialog',
        ),
        confirmKey: const Key(
          'media-management-single-regenerate-thumbnails-confirm-button',
        ),
        cancelKey: const Key(
          'media-management-single-regenerate-thumbnails-cancel-button',
        ),
        title: l10n.mediaListThumbnailRegenerateTitle,
        message: l10n.mediaListThumbnailSingleRegenerateMessage,
        confirmLabel: l10n.mediaListThumbnailRegenerateConfirm,
      );
      if (!confirmed || !context.mounted) return;
    }
    await _resetThumbnails(
      context,
      ref,
      mediaIds: [item.id],
      isResettingThumbnails: isResettingThumbnails,
      retryingThumbnailMediaId: retryingThumbnailMediaId,
      force: force,
    );
  }

  /// 移动端卡片「更多」：先弹带中文标签的底部操作表，再把动作派发到现有实现。
  ///
  /// 桌面端不用：行内平铺图标 + hover tooltip 已经自解释。
  Future<void> _openMediaRowActions(
    BuildContext context,
    WidgetRef ref,
    MediaListItemDto item, {
    required ValueNotifier<bool> isResettingThumbnails,
    required ValueNotifier<int?> retryingThumbnailMediaId,
    required ValueNotifier<bool> isTransferring,
    required ValueNotifier<int?> transferringMediaId,
    required ValueNotifier<int?> deletingMediaId,
  }) async {
    final state = item.thumbnailGenerationState;
    final l10n = AppLocalizations.of(context);
    final retryLabel = switch (state) {
      MediaThumbnailGenerationState.terminal =>
        l10n.mediaListActionRetryThumbnails,
      MediaThumbnailGenerationState.succeeded =>
        l10n.mediaListActionRegenerateThumbnails,
      _ => null,
    };
    final action = await showMediaManagementRowActions(
      context: context,
      title: item.displayHeading(l10n),
      titleSubtitle: item.displaySubtitle,
      retryThumbnailsLabel: retryLabel,
      retryThumbnailsSubtitle: switch (state) {
        MediaThumbnailGenerationState.terminal =>
          l10n.mediaListRowActionRetrySubtitle,
        MediaThumbnailGenerationState.succeeded =>
          l10n.mediaListRowActionRegenerateSubtitle,
        _ => null,
      },
      showEditTags: item.isJav,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case MediaManagementRowAction.editTags:
        await _editMediaTags(context, ref, item, mobile: true);
      case MediaManagementRowAction.retryThumbnails:
        await _handleItemThumbnailAction(
          context,
          ref,
          item,
          isResettingThumbnails,
          retryingThumbnailMediaId,
        );
      case MediaManagementRowAction.transfer:
        await _submitTransfer(
          context,
          ref,
          mediaIds: [item.id],
          isTransferring: isTransferring,
          transferringMediaId: transferringMediaId,
        );
      case MediaManagementRowAction.delete:
        await _openSingleDeleteDialog(context, ref, item, deletingMediaId);
    }
  }

  Future<void> _editMediaTags(
    BuildContext context,
    WidgetRef ref,
    MediaListItemDto item, {
    required bool mobile,
  }) async {
    if (!item.isJav) return;
    final assignment = await showMediaTagAssignmentEditor(
      context,
      mediaId: item.id,
      mobile: mobile,
    );
    if (assignment == null || !context.mounted) return;
    ref
        .read(mediaBrowseProvider.notifier)
        .applyTagAssignment(
          mediaId: item.id,
          tags: assignment.tags,
          isManuallyManaged: assignment.isManuallyManaged,
        );
    showToast(AppLocalizations.of(context).mediaTagsAssignmentSaved);
  }

  /// 批量与单项共用的缩略图重置：置忙、重置、清选、刷新，并按结果提示。
  ///
  /// [selectionMode] 仅批量入口传入（成功后退出移动端多选态）；
  /// [retryingThumbnailMediaId] 仅单项入口传入（标记对应卡片 loading）。
  Future<void> _resetThumbnails(
    BuildContext context,
    WidgetRef ref, {
    required List<int> mediaIds,
    required ValueNotifier<bool> isResettingThumbnails,
    ValueNotifier<bool>? selectionMode,
    ValueNotifier<int?>? retryingThumbnailMediaId,
    bool force = false,
  }) async {
    if (isResettingThumbnails.value) return;
    final l10n = AppLocalizations.of(context);
    isResettingThumbnails.value = true;
    retryingThumbnailMediaId?.value = mediaIds.first;
    try {
      final resetCount = await ref
          .read(mediaApiProvider)
          .resetMediaThumbnails(mediaIds: mediaIds, force: force);
      if (!context.mounted) return;
      ref.read(mediaBrowseProvider.notifier).clearSelection();
      selectionMode?.value = false;
      final refreshMessage = await ref
          .read(mediaBrowseProvider.notifier)
          .refresh();
      if (!context.mounted) return;
      if (refreshMessage != null) {
        showToast(
          l10n.mediaListThumbnailResetRefreshFailed(resetCount, refreshMessage),
        );
      } else if (resetCount == 0) {
        showToast(
          force
              ? l10n.mediaListThumbnailNothingToRegenerate
              : l10n.mediaListThumbnailNothingToRetry,
        );
      } else if (force) {
        showToast(l10n.mediaListThumbnailRegenerateSubmitted(resetCount));
      } else {
        showToast(l10n.mediaListThumbnailRetrySubmitted(resetCount));
      }
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: force
                ? l10n.mediaListThumbnailRegenerateFailed
                : l10n.mediaListThumbnailRetryFailed,
            l10n: l10n,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        retryingThumbnailMediaId?.value = null;
        isResettingThumbnails.value = false;
      }
    }
  }
}
