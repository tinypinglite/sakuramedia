import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_sort.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 视频合集详情 State：合集元信息 + 有序成员 + 当前排序。
@immutable
class VideoCollectionDetailState {
  const VideoCollectionDetailState({
    required this.collection,
    required this.items,
    this.sort = VideoCollectionSort.manual,
    this.filterUpdate = const FilterUpdateState.idle(),
  });

  final VideoCollectionDto collection;
  final List<VideoCollectionItemDto> items;
  final VideoCollectionSort sort;
  final FilterUpdateState filterUpdate;

  bool get isEmpty => items.isEmpty;

  VideoCollectionDetailState copyWith({
    VideoCollectionDto? collection,
    List<VideoCollectionItemDto>? items,
    VideoCollectionSort? sort,
    FilterUpdateState? filterUpdate,
  }) {
    return VideoCollectionDetailState(
      collection: collection ?? this.collection,
      items: items ?? this.items,
      sort: sort ?? this.sort,
      filterUpdate: filterUpdate ?? this.filterUpdate,
    );
  }
}
