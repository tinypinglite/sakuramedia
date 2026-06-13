import 'dart:async';

import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/paged_video_summary_controller.dart';
import 'package:sakuramedia/features/videos/presentation/person_selection_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_filter_state.dart';

/// 视频列表页的可缓存状态：分页控制器 + 排序状态 + 标签/人物选择器 + 关键词。
///
/// 标签选择器直接复用 catalog 的 [TagSelectionController]（视频与影片共享 Tag），
/// 人物选择器为视频域专属的 [PersonSelectionController]。任一「已选项」变化时由页面
/// 调用 [reloadVideos] 重新拉取列表（搜索词变化只影响各自面板、不触发列表重载）。
class VideoListPageStateEntry implements AppPageStateEntry {
  VideoListPageStateEntry({
    required VideosApi videosApi,
    required TagsApi tagsApi,
    required PersonsApi personsApi,
  }) {
    tagSelection = TagSelectionController(tagsApi: tagsApi, popularLimit: 30);
    personSelection = PersonSelectionController(personsApi: personsApi);
    controller = PagedVideoSummaryController(
      fetchPage: (page, pageSize) => videosApi.getVideos(
        page: page,
        pageSize: pageSize,
        query: query,
        tagIds: tagSelection.selectedTagIds,
        personIds: personSelection.selectedPersonIds,
        sort: filterState.sortExpression,
      ),
      pageSize: 24,
    );
    unawaited(tagSelection.load());
    unawaited(personSelection.load());
    controller.attachScrollListener();
    controller.initialize();
  }

  late final PagedVideoSummaryController controller;
  late final TagSelectionController tagSelection;
  late final PersonSelectionController personSelection;
  VideoFilterState filterState = VideoFilterState.initial;
  String query = '';

  /// 应用一次筛选/排序/关键词变化：回到顶部并重载列表。
  void reloadVideos() {
    if (controller.scrollController.hasClients) {
      controller.scrollController.jumpTo(0);
    }
    unawaited(controller.reload());
  }

  @override
  void dispose() {
    controller.dispose();
    tagSelection.dispose();
    personSelection.dispose();
  }
}
