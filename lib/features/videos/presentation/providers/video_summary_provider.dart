import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

part 'video_summary_provider.g.dart';

/// 桌面 / 移动 PornBox 共用的缓存分页列表。
///
/// provider 默认 autoDispose；页面在初始化时把 [cacheLink] 交给
/// `RiverpodPageCache`，复刻旧缓存 entry 的 LRU 生命周期。排序、分页与删除
/// 补丁均在这里收敛，View 仅保留滚动、多选和动作弹窗等瞬态状态。
@Riverpod(retry: kNoAsyncNotifierRetry)
class VideoSummary extends _$VideoSummary
    with
        PagedAsyncNotifierMixin<VideoSummaryState, VideoItemListItemDto>,
        FilterablePagedAsyncNotifierMixin<
          VideoSummaryState,
          VideoItemListItemDto,
          VideoFilterState
        > {
  KeepAliveLink? _cacheLink;

  KeepAliveLink? get cacheLink => _cacheLink;

  @override
  int get pageSize => 24;

  @override
  String get initialLoadErrorText => '视频列表加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多失败，请点击重试';

  @override
  VideoFilterState get initialFilter => VideoFilterState.initial;

  @override
  PagedListState<VideoItemListItemDto> pagedOf(VideoSummaryState state) =>
      state.paged;

  @override
  VideoSummaryState applyPaged(
    VideoSummaryState state,
    PagedListState<VideoItemListItemDto> paged,
  ) => state.copyWith(paged: paged);

  @override
  VideoSummaryState applyFilterToState(
    VideoSummaryState state,
    VideoFilterState filter,
  ) => state.copyWith(filter: filter);

  @override
  Future<VideoSummaryState> build(VideoSummaryScope scope) async {
    _cacheLink ??= ref.keepAlive();
    attachDisposeGuard();
    ref.listen(videoMutationEventsProvider, (_, next) {
      final change = next.value;
      if (change?.kind == VideoMutationKind.deleted) {
        _removeDeletedVideo(change!.videoId);
      }
    });
    final paged = await loadInitialPage();
    return VideoSummaryState(paged: paged, filter: activeFilter);
  }

  @override
  Future<PaginatedResponseDto<VideoItemListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    return ref
        .read(videosApiProvider)
        .getVideos(
          page: page,
          pageSize: pageSize,
          sort: activeFilter.sortExpression,
        );
  }

  Future<void> applyFilter(VideoFilterState filter) {
    return applyFilterState(filter);
  }

  void _removeDeletedVideo(int videoId) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final paged = current.paged.removeWhere((video) => video.id == videoId);
    if (identical(paged, current.paged)) {
      return;
    }
    state = AsyncData(current.copyWith(paged: paged));
  }
}
