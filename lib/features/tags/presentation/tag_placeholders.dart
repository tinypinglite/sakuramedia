import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 标签选择器加载态占位数据：真实 DTO + [BoneMock] 文案，
/// 供 `AppSkeletonizer` 渲染与真实药丸同形的静态骨架。
List<TagListItemDto> tagListItemPlaceholders({int count = 10}) {
  return List<TagListItemDto>.generate(
    count,
    (index) => TagListItemDto(
      tagId: -1 - index,
      name: BoneMock.words(1),
      movieCount: 12,
    ),
    growable: false,
  );
}
