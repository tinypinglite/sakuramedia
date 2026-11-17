import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';

@immutable
class VideoSummaryState {
  const VideoSummaryState({required this.paged, required this.filter});

  final PagedListState<VideoItemListItemDto> paged;
  final VideoFilterState filter;

  VideoSummaryState copyWith({
    PagedListState<VideoItemListItemDto>? paged,
    VideoFilterState? filter,
  }) {
    return VideoSummaryState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
    );
  }
}
