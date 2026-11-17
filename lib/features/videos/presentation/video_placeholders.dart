import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_state.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 视频合集列表加载态占位合集：真实 [VideoCollectionDto] + [BoneMock] 文案，
/// 封面为 `null` 不触发网络请求。
List<VideoCollectionDto> videoCollectionPlaceholders({int count = 6}) {
  return List<VideoCollectionDto>.generate(
    count,
    (index) => VideoCollectionDto(
      id: -1 - index,
      name: BoneMock.words(2),
      itemCount: 3,
    ),
    growable: false,
  );
}

/// 视频合集详情加载态占位：合集元信息 + [itemCount] 条视频。
/// 封面给 16:9 像素尺寸，让瀑布流骨架与真实封面比例一致。
VideoCollectionDetailState videoCollectionDetailPlaceholder({
  int itemCount = 6,
}) {
  return VideoCollectionDetailState(
    collection: VideoCollectionDto(
      id: -1,
      name: BoneMock.words(2),
      description: BoneMock.words(8),
      itemCount: itemCount,
    ),
    items: List<VideoCollectionItemDto>.generate(
      itemCount,
      (index) => VideoCollectionItemDto(
        position: index,
        video: _videoPlaceholder(index),
      ),
      growable: false,
    ),
  );
}

/// 视频瀑布流（PornBox / 视频列表）加载态占位视频：封面 16:9，
/// 标题用 [BoneMock]，保证 tile 高宽比与真实网格一致。
List<VideoItemListItemDto> videoSummaryPlaceholders({int count = 8}) {
  return List<VideoItemListItemDto>.generate(
    count,
    _videoPlaceholder,
    growable: false,
  );
}

VideoItemListItemDto _videoPlaceholder(int index) {
  return VideoItemListItemDto(
    id: -1 - index,
    title: BoneMock.words(3),
    mediaCount: 3,
    canPlay: false,
    coverWidth: 1920,
    coverHeight: 1080,
    durationSeconds: 1800,
    releaseDate: DateTime(2026, 1, 1),
  );
}
