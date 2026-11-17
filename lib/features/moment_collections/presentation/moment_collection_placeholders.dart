import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_detail_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 时刻合集列表加载态占位合集：用真实 [MomentCollectionDto] 撑起真实卡片布局，
/// 文案取 [BoneMock]，封面为 `null` 不触发网络请求。
List<MomentCollectionDto> momentCollectionPlaceholders({int count = 6}) {
  return List<MomentCollectionDto>.generate(
    count,
    (index) => MomentCollectionDto(
      id: -1 - index,
      name: BoneMock.words(2),
      description: '',
      pointCount: 0,
      coverImage: null,
      createdAt: null,
      updatedAt: null,
    ),
    growable: false,
  );
}

/// 时刻合集详情加载态占位：合集元信息 + [pointCount] 条时刻，供详情页在
/// loading 分支渲染与真实内容同形的骨架。
MomentCollectionDetailState momentCollectionDetailPlaceholder({
  int pointCount = 6,
}) {
  return MomentCollectionDetailState(
    collection: MomentCollectionDto(
      id: -1,
      name: BoneMock.words(2),
      description: '',
      pointCount: pointCount,
      coverImage: null,
      createdAt: null,
      updatedAt: null,
    ),
    points: List<MomentCollectionPointDto>.generate(
      pointCount,
      (index) => MomentCollectionPointDto(
        pointId: -1 - index,
        mediaId: 100 + index,
        movieNumber: 'ABC-000',
        videoItemId: null,
        thumbnailId: 0,
        offsetSeconds: 30,
        image: null,
        position: index,
      ),
      growable: false,
    ),
  );
}
