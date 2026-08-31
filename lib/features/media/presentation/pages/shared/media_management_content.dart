import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_rapid_upload_history_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/rapid_upload_target_library_dialog.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/invalid_media_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/rapid_upload_history_section.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 「媒体管理」双端共享内容（桌面 / 移动壳收敛的 content 层）。
///
/// 平台差异收在壳注入的参数里：
/// - `keyPrefix`：tab / section 等测试 Key 前缀（桌面 `media-management`，
///   移动 `mobile-media-management`），保证两端 Key 不撞；
/// - `rootKey`：页面根 Key（桌面 `desktop-media-management-page`）；
/// - `onOpenMovieDetail`：媒体封面跳影片详情的导航回调（双端路由不同）。
///
/// 内容自持页面级编排（全部 hooks）：
/// - 三 tab（`AppTabBar` variant auto，移动自动切 mobileTop）+ 共享滚动 +
///   切 tab 回顶 + 按 tab 分派 loadMore；
/// - 秒传批次运行态 8s 轮询 Timer（`ref.listen` 动态启停，全部终态后自停）；
/// - 跨 provider 动作：复合刷新 / 秒传创建 / 批量删除（串行 + 汇总 toast）/
///   批次重试。
class MediaManagementContent extends HookConsumerWidget {
  const MediaManagementContent({
    super.key,
    required this.keyPrefix,
    required this.rootKey,
    required this.onOpenMovieDetail,
    this.mobile = false,
  });

  /// 测试 Key 前缀：桌面 `media-management`，移动 `mobile-media-management`。
  final String keyPrefix;

  /// 页面根 Key：桌面 `desktop-media-management-page`，移动 `mobile-media-management-page`。
  final Key rootKey;

  /// 媒体封面点击跳影片详情（JAV 项）；桌面 push 桌面详情、移动 push 移动详情。
  final void Function(BuildContext context, String movieNumber)
  onOpenMovieDetail;

  /// 移动端布局：媒体列表 tab 用流式行卡 + 底部抽屉筛选 + 长按多选。
  final bool mobile;

  static const int _maintenanceTabIndex = 1;
  static const int _batchTabIndex = 2;
  static const Duration _runningBatchPollInterval = Duration(seconds: 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 页面级 view 生命周期对象：全部走 hooks。
    final tabController = useTabController(initialLength: 3);
    // useListenable 触发 rebuild，读取 tabController.index 让 body 分派。
    useListenable(tabController);
    final currentTab = tabController.index;

    // 单一共享 ScrollController：AppPageFrame 用；滚到底按当前 tab 分派 loadMore，
    // 避免多个分页 provider 同时监听同一 scroll 互相打架。
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () {
        switch (currentTab) {
          case _batchTabIndex:
            unawaited(
              ref.read(mediaRapidUploadHistoryProvider.notifier).loadMore(),
            );
          case _maintenanceTabIndex:
            unawaited(ref.read(invalidMediaProvider.notifier).loadMore());
          default:
            unawaited(ref.read(mediaBrowseProvider.notifier).loadMore());
        }
      },
      enabled: true,
      // currentTab 改变时重绑 listener 让最新闭包生效（虽然 useRef 已保证最新，
      // 但把 tab 加入 keys 更贴合 hook 心智模型）。
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

    // 切 tab 时回到顶部，避免新 tab 沿用上一个的滚动位置误触发 loadMore。
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

    // 秒传批次运行态轮询：Timer 完全归页面（不入 Notifier）。
    // 用 ref.listen 观察批次数据变化，动态启停 Timer。
    final batchPollTimer = useRef<Timer?>(null);
    useEffect(
      () =>
          () => batchPollTimer.value?.cancel(),
      const <Object?>[],
    );
    ref.listen(mediaRapidUploadHistoryProvider, (previous, next) {
      final items = next.value?.items ?? const [];
      final hasRunning = items.any((batch) => batch.state.isRunning);
      final timer = batchPollTimer.value;
      if (hasRunning) {
        if (timer == null || !timer.isActive) {
          batchPollTimer.value = Timer.periodic(_runningBatchPollInterval, (_) {
            _pollRunningBatches(ref);
          });
        }
      } else {
        timer?.cancel();
        batchPollTimer.value = null;
      }
    });

    // 秒传触发中标记（页面级——秒传是页面编排的跨 provider 动作）
    final isTriggeringUpload = useState<bool>(false);
    // 批量删除进行中标记（页面级——串行循环 + 汇总 toast 由页面编排）
    final isBatchDeleting = useState<bool>(false);
    final retryingBatchId = useState<int?>(null);
    // 移动端多选态：长按行进入、退出/操作完成后清空并退出。
    final selectionMode = useState<bool>(false);

    void exitSelectionMode() {
      selectionMode.value = false;
    }

    final spacing = context.appSpacing;
    // 顶栏刷新按钮与 Cmd/Ctrl+R 都触发 _refreshAll（媒体列表 + 秒传批次 + 媒体库）。
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
              Tab(key: Key('$keyPrefix-tab-maintenance'), text: '失效巡检'),
              Tab(key: Key('$keyPrefix-tab-batches'), text: '115秒传记录'),
            ],
          ),
          SizedBox(height: spacing.lg),
          Expanded(
            child: switch (currentTab) {
              _batchTabIndex => RapidUploadHistorySection(
                scrollController: scrollController,
                retryingBatchId: retryingBatchId.value,
                onRetry: (batch) =>
                    _retryBatch(context, ref, batch, retryingBatchId),
              ),
              _maintenanceTabIndex => InvalidMediaSection(
                key: Key('$keyPrefix-invalid-media-section'),
                scrollController: scrollController,
              ),
              _ => MediaListSection(
                scrollController: scrollController,
                isTriggering: isTriggeringUpload.value,
                isDeleting: isBatchDeleting.value,
                onRapidUpload: () => _openRapidUploadDialog(
                  context,
                  ref,
                  isTriggeringUpload,
                  selectionMode,
                ),
                onBatchDelete: () => _openBatchDeleteDialog(
                  context,
                  ref,
                  isBatchDeleting,
                  selectionMode,
                ),
                // 复合刷新：媒体列表 + 失效巡检 + 秒传批次 + 媒体库。
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

  static void _pollRunningBatches(WidgetRef ref) {
    final items =
        ref.read(mediaRapidUploadHistoryProvider).value?.items ?? const [];
    for (final batch in items) {
      if (!batch.state.isRunning) continue;
      unawaited(_refreshBatchSilently(ref, batch.id));
    }
  }

  static Future<void> _refreshBatchSilently(WidgetRef ref, int batchId) async {
    try {
      await ref
          .read(mediaRapidUploadHistoryProvider.notifier)
          .refreshBatch(batchId);
    } catch (_) {
      // 静默：周期轮询失败不打扰。
    }
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    final results = await Future.wait<String?>([
      ref.read(mediaBrowseProvider.notifier).refresh(),
      ref.read(invalidMediaProvider.notifier).refresh(),
      ref.read(mediaRapidUploadHistoryProvider.notifier).refresh(),
      ref.read(mediaLibrariesProvider.notifier).refresh(),
    ]);
    for (final message in results) {
      if (message != null) showToast(message);
    }
  }

  Future<void> _openRapidUploadDialog(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> isTriggering,
    ValueNotifier<bool> selectionMode,
  ) async {
    final browseState = ref.read(mediaBrowseProvider).value;
    if (browseState == null) return;
    final selectedIds = browseState.selectedIds.toList(growable: false);
    if (selectedIds.isEmpty) return;

    final librariesState =
        ref.read(mediaLibrariesProvider).value ?? MediaLibrariesState.empty;
    final target = await showRapidUploadTargetLibraryDialog(
      context,
      selectedCount: selectedIds.length,
      libraries: librariesState.cloud115Libraries,
    );
    if (target == null || !context.mounted) return;

    isTriggering.value = true;
    try {
      final response = await ref
          .read(mediaApiProvider)
          .createMediaRapidUpload(
            mediaIds: selectedIds,
            targetLibraryId: target.id,
          );
      if (!context.mounted) return;
      ref.read(mediaBrowseProvider.notifier).removeItemsByIds(selectedIds);
      if (mobile) {
        selectionMode.value = false;
      }
      unawaited(_refreshBatchSilently(ref, response.batchId));
      showToast('已创建秒传批次 #${response.batchId}，共 ${selectedIds.length} 项');
    } catch (error) {
      if (context.mounted) {
        showToast(apiErrorMessage(error, fallback: '创建秒传批次失败'));
      }
    } finally {
      if (context.mounted) {
        isTriggering.value = false;
      }
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
      message:
          '将删除已选 ${selectedIds.length} 项媒体，本地文件/115 云端文件会被删除，'
          '且不可恢复。请确认要继续吗？',
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
    }
    if (!context.mounted) return;
    // 部分成功：成功项已从列表与选中集合剔除；移动端直接退出多选态，避免底部
    // 操作条停留在「已选 N 项」的残留上下文。refresh() 只替换 paged、不清空
    // 选中集合，因此全失败时会保留多选态与选中项，用户可直接原地重试。
    if (mobile && okIds.isNotEmpty) {
      selectionMode.value = false;
    }

    if (failedIds.isEmpty) {
      showToast('已删除 ${okIds.length} 项媒体');
    } else {
      final errorMessage = firstError == null
          ? '未知错误'
          : apiErrorMessage(firstError, fallback: '批量删除失败');
      showToast('已删除 ${okIds.length} 项，${failedIds.length} 项失败：$errorMessage');
      // 半失败：拉服务端真实态兜底，避免前端与后端偏差。
      unawaited(ref.read(mediaBrowseProvider.notifier).refresh());
    }
  }

  Future<void> _retryBatch(
    BuildContext context,
    WidgetRef ref,
    MediaRapidUploadBatchListItemDto batch,
    ValueNotifier<int?> retryingBatchId,
  ) async {
    if (retryingBatchId.value != null) return;
    retryingBatchId.value = batch.id;
    try {
      final response = await ref
          .read(mediaApiProvider)
          .retryMediaRapidUpload(batchId: batch.id);
      if (!context.mounted) return;
      unawaited(_refreshBatchSilently(ref, response.batchId));
      showToast('已创建重试批次 #${response.batchId}');
    } catch (error) {
      if (context.mounted) {
        showToast(apiErrorMessage(error, fallback: '重试秒传批次失败'));
      }
    } finally {
      if (context.mounted) {
        retryingBatchId.value = null;
      }
    }
  }
}
