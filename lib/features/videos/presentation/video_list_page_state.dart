import 'dart:async';

import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/paged_video_summary_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/video_mutation_change_notifier.dart';

/// 视频列表页的可缓存状态：分页控制器 + 排序状态。
///
/// 排序变化时由页面调用 [reloadVideos] 重新拉取列表；并监听全局
/// [VideoMutationChangeNotifier]，在别处删除视频时把对应项就地移除，保持跨页一致。
class VideoListPageStateEntry implements AppPageStateEntry {
  VideoListPageStateEntry({
    required VideosApi videosApi,
    required this.mutationNotifier,
  }) {
    controller = PagedVideoSummaryController(
      fetchPage: (page, pageSize) => videosApi.getVideos(
        page: page,
        pageSize: pageSize,
        sort: filterState.sortExpression,
      ),
      pageSize: 24,
    );
    mutationNotifier.addListener(_onMutation);
    controller.attachScrollListener();
    controller.initialize();
  }

  final VideoMutationChangeNotifier mutationNotifier;
  late final PagedVideoSummaryController controller;
  VideoFilterState filterState = VideoFilterState.initial;

  void _onMutation() {
    final change = mutationNotifier.lastChange;
    if (change == null) {
      return;
    }
    // 视频被删除（无论在哪个页面触发）→ 从本地分页列表精准移除。
    // 合集归属变化不影响视频网格本身，忽略（横滑区由页面层另行刷新）。
    if (change.kind == VideoMutationKind.deleted) {
      controller.removeItem(change.videoId);
    }
  }

  /// 应用一次筛选/排序/关键词变化：回到顶部并重载列表。
  void reloadVideos() {
    if (controller.scrollController.hasClients) {
      controller.scrollController.jumpTo(0);
    }
    unawaited(controller.reload());
  }

  @override
  void dispose() {
    mutationNotifier.removeListener(_onMutation);
    controller.dispose();
  }
}
