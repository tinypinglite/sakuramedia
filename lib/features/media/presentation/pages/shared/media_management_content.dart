import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/invalid_media_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_section.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 「媒体管理」双端共享内容（桌面 / 移动壳收敛的 content 层）。
///
/// 当前后端支持媒体列表、失效媒体列表和媒体删除，因此页面只保留这两个
/// tab；Provider 专属上传和有效性复查入口不在页面中暴露。
class MediaManagementContent extends HookConsumerWidget {
  const MediaManagementContent({
    super.key,
    required this.keyPrefix,
    required this.rootKey,
    required this.onOpenMovieDetail,
    this.mobile = false,
  });

  final String keyPrefix;
  final Key rootKey;
  final void Function(BuildContext context, String movieNumber)
  onOpenMovieDetail;
  final bool mobile;

  static const int _maintenanceTabIndex = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: 2);
    useListenable(tabController);
    final currentTab = tabController.index;
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () {
        if (currentTab == _maintenanceTabIndex) {
          unawaited(ref.read(invalidMediaProvider.notifier).loadMore());
        } else {
          unawaited(ref.read(mediaBrowseProvider.notifier).loadMore());
        }
      },
      enabled: true,
      keys: [currentTab],
    );
    ref.listen(mediaBrowseProvider.select((value) => value.value?.filter), (
      previous,
      next,
    ) {
      if (previous != null &&
          next != null &&
          previous != next &&
          currentTab == 0 &&
          scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    });

    useEffect(() {
      void onTabChanged() {
        if (tabController.indexIsChanging) return;
        if (scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
      }

      tabController.addListener(onTabChanged);
      return () => tabController.removeListener(onTabChanged);
    }, [tabController, scrollController]);

    final isDeleting = useState<bool>(false);
    final selectionMode = useState<bool>(false);

    void exitSelectionMode() {
      selectionMode.value = false;
    }

    return AppPageRefreshScope(
      onRefresh: () => _refreshAll(ref),
      child: Column(
        key: rootKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTabBar(
            controller: tabController,
            tabs: [
              Tab(key: Key('$keyPrefix-tab-list'), text: '媒体列表'),
              Tab(key: Key('$keyPrefix-tab-maintenance'), text: '失效媒体'),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          Expanded(
            child: switch (currentTab) {
              _maintenanceTabIndex => InvalidMediaSection(
                key: Key('$keyPrefix-invalid-media-section'),
                scrollController: scrollController,
              ),
              _ => MediaListSection(
                scrollController: scrollController,
                isDeleting: isDeleting.value,
                onBatchDelete: () => _openBatchDeleteDialog(
                  context,
                  ref,
                  isDeleting,
                  selectionMode,
                ),
                onRefresh: () => _refreshAll(ref),
                onOpenMovieDetail: onOpenMovieDetail,
                keyPrefix: keyPrefix,
                mobile: mobile,
                selectionMode: selectionMode.value,
                onEnterSelection: () => selectionMode.value = true,
                onExitSelection: exitSelectionMode,
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    final results = await Future.wait<String?>([
      ref.read(mediaBrowseProvider.notifier).refresh(),
      ref.read(invalidMediaProvider.notifier).refresh(),
      ref.read(mediaLibrariesProvider.notifier).refresh(),
    ]);
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
    final browseState = ref.read(mediaBrowseProvider).value;
    if (browseState == null) return;
    final selectedIds = browseState.selectedIds.toList(growable: false);
    if (selectedIds.isEmpty) return;

    final confirmed = await showAppConfirmDialog(
      context,
      dialogKey: const Key('media-management-batch-delete-dialog'),
      confirmKey: const Key('media-management-batch-delete-confirm-button'),
      cancelKey: const Key('media-management-batch-delete-cancel-button'),
      title: '批量删除媒体',
      message: '将删除已选 ${selectedIds.length} 项媒体及其对应文件，且不可恢复。请确认要继续吗？',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed || !context.mounted) return;

    isDeleting.value = true;
    final okIds = <int>[];
    final failedIds = <int>[];
    Object? firstError;
    try {
      final mediaApi = ref.read(mediaApiProvider);
      for (final mediaId in selectedIds) {
        try {
          await mediaApi.deleteMedia(mediaId: mediaId);
          okIds.add(mediaId);
        } catch (error) {
          failedIds.add(mediaId);
          firstError ??= error;
        }
      }
    } finally {
      if (context.mounted) {
        isDeleting.value = false;
      }
    }

    if (okIds.isNotEmpty) {
      ref.read(mediaBrowseProvider.notifier).removeItemsByIds(okIds);
      if (mobile && context.mounted) {
        selectionMode.value = false;
      }
    }
    if (!context.mounted) return;
    if (failedIds.isEmpty) {
      showToast('已删除 ${okIds.length} 项媒体');
    } else {
      final errorMessage = firstError == null
          ? '未知错误'
          : apiErrorMessage(firstError, fallback: '批量删除失败');
      showToast('已删除 ${okIds.length} 项，${failedIds.length} 项失败：$errorMessage');
      unawaited(ref.read(mediaBrowseProvider.notifier).refresh());
    }
  }
}
