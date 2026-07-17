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
import 'package:sakuramedia/features/media/presentation/providers/media_rapid_upload_history_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/rapid_upload_target_library_dialog.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/rapid_upload_history_section.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 「媒体管理」桌面页（Riverpod）：
/// - 顶部 `AppTabBar` 两栏：媒体列表 / 秒传批次；
/// - 媒体列表 tab：[MediaListSection]（Riverpod Consumer；含筛选头 + 列表 + 秒传）；
/// - 秒传批次 tab：[RapidUploadHistorySection]（Riverpod Consumer）；
/// - Timer 8s 轮询 running 批次，全部终态后自停。
///
/// 挂在系统设置左侧「媒体管理」tab 下，是姊妹页 `DesktopMediaMaintenancePage` 的邻居。
class DesktopMediaManagementPage extends HookConsumerWidget {
  const DesktopMediaManagementPage({super.key, this.active = true});

  /// 作为系统设置页 tab 嵌入时用于懒加载：仅在 tab 激活后才 watch provider 触发请求。
  final bool active;

  static const int _batchTabIndex = 1;
  static const Duration _runningBatchPollInterval = Duration(seconds: 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 页面级 view 生命周期对象：全部走 hooks。
    final tabController = useTabController(initialLength: 2);
    // useListenable 触发 rebuild，读取 tabController.index 让 body 分派。
    useListenable(tabController);
    final currentTab = tabController.index;
    final isBatchTab = currentTab == _batchTabIndex;

    // 单一共享 ScrollController：AppPageFrame 用；滚到底按当前 tab 分派 loadMore，
    // 避免两个分页 provider 同时监听同一 scroll 互相打架。
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () {
        if (isBatchTab) {
          unawaited(
            ref.read(mediaRapidUploadHistoryProvider.notifier).loadMore(),
          );
        } else {
          unawaited(ref.read(mediaBrowseProvider.notifier).loadMore());
        }
      },
      enabled: active,
      // isBatchTab 改变时重绑 listener 让最新闭包生效（虽然 useRef 已保证最新，
      // 但把 tab 加入 keys 更贴合 hook 心智模型）。
      keys: [isBatchTab],
    );

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
    useEffect(() => () => batchPollTimer.value?.cancel(), const <Object?>[]);
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

    // active 懒加载：非 active 时只挂骨架，不 watch provider（不触发 build）。
    if (!active) {
      return AppPageFrame(
        title: '',
        scrollController: scrollController,
        child: const SizedBox.shrink(
          key: Key('desktop-media-management-page-inactive'),
        ),
      );
    }

    final spacing = context.appSpacing;
    return AppPageFrame(
      title: '',
      scrollController: scrollController,
      child: Column(
        key: const Key('desktop-media-management-page'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTabBar(
            controller: tabController,
            tabs: const [
              Tab(
                key: Key('media-management-tab-list'),
                text: '媒体列表',
              ),
              Tab(
                key: Key('media-management-tab-batches'),
                text: '秒传批次',
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          if (isBatchTab)
            RapidUploadHistorySection(
              retryingBatchId: retryingBatchId.value,
              onRetry: (batch) =>
                  _retryBatch(context, ref, batch, retryingBatchId),
            )
          else
            MediaListSection(
              isTriggering: isTriggeringUpload.value,
              isDeleting: isBatchDeleting.value,
              onRapidUpload: () => _openRapidUploadDialog(
                context,
                ref,
                isTriggeringUpload,
              ),
              onBatchDelete: () => _openBatchDeleteDialog(
                context,
                ref,
                isBatchDeleting,
              ),
              // 复合刷新：媒体列表 + 秒传批次 + 媒体库。
              onRefresh: () => _refreshAll(ref),
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
  ) async {
    final browseState = ref.read(mediaBrowseProvider).value;
    if (browseState == null) return;
    final selectedIds = browseState.selectedIds.toList(growable: false);
    if (selectedIds.isEmpty) return;

    final librariesState = ref.read(mediaLibrariesProvider).value ??
        MediaLibrariesState.empty;
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
      message: '将删除已选 ${selectedIds.length} 项媒体，本地文件/115 云端文件会被删除，'
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

    if (failedIds.isEmpty) {
      showToast('已删除 ${okIds.length} 项媒体');
    } else {
      final errorMessage = firstError == null
          ? '未知错误'
          : apiErrorMessage(firstError, fallback: '批量删除失败');
      showToast(
        '已删除 ${okIds.length} 项，${failedIds.length} 项失败：$errorMessage',
      );
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
