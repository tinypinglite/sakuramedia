import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_state.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 切片合集列表加载态占位合集：用真实 [ClipCollectionDto] 撑起真实卡片布局，
/// 文案取 [BoneMock]（骨架化后只是骨块宽度），封面为 `null` 不触发网络请求。
List<ClipCollectionDto> clipCollectionPlaceholders({int count = 6}) {
  return List<ClipCollectionDto>.generate(
    count,
    (index) => ClipCollectionDto(
      id: -1 - index,
      name: BoneMock.words(2),
      description: '',
      clipCount: 0,
      coverImage: null,
      createdAt: null,
      updatedAt: null,
    ),
    growable: false,
  );
}

/// 切片合集详情加载态占位：合集元信息 + [clipCount] 条切片，供详情页在
/// loading 分支渲染与真实内容同形的骨架。
ClipCollectionDetailState clipCollectionDetailPlaceholder({int clipCount = 6}) {
  return ClipCollectionDetailState(
    collection: ClipCollectionDto(
      id: -1,
      name: BoneMock.words(2),
      description: '',
      clipCount: clipCount,
      coverImage: null,
      createdAt: null,
      updatedAt: null,
    ),
    clips: clipPlaceholders(count: clipCount),
  );
}
