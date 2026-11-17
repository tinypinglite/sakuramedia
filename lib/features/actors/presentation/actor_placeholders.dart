import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_filter_options_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 女优相关加载态占位数据：真实 DTO + [BoneMock] 文案，
/// 供 `AppSkeletonizer` 渲染与真实卡片同形的静态骨架。
List<ActorListItemDto> actorListItemPlaceholders({int count = 8}) {
  return List<ActorListItemDto>.generate(
    count,
    (index) => ActorListItemDto(
      id: -1 - index,
      name: BoneMock.words(2),
      aliasName: '',
      profileImage: null,
      isSubscribed: false,
    ),
    growable: false,
  );
}

/// 女优详情加载态占位：详情头 + 影片网格同形渲染，由 `AppSkeletonizer` 灰化。
ActorDetailDto actorDetailPlaceholder() {
  return ActorDetailDto(summary: actorListItemPlaceholders(count: 1).single);
}

/// 资料筛选（年龄 / 身高 / 罩杯）加载态占位。
///
/// 切换订阅 / 性别筛选会换一个 options family 实例，加载期间用这份占位数据渲染
/// 同样的滑块与药丸，避免整块内容塌陷成一行加载文案造成闪烁。
ActorFilterOptionsDto actorFilterOptionsPlaceholder() {
  return const ActorFilterOptionsDto(
    age: ActorFilterRangeDto(min: 20, max: 40, populatedCount: 6),
    heightCm: ActorFilterRangeDto(min: 150, max: 175, populatedCount: 6),
    cups: <ActorCupFilterOptionDto>[
      ActorCupFilterOptionDto(value: 'A', count: 12),
      ActorCupFilterOptionDto(value: 'B', count: 12),
      ActorCupFilterOptionDto(value: 'C', count: 12),
      ActorCupFilterOptionDto(value: 'D', count: 12),
      ActorCupFilterOptionDto(value: 'E', count: 12),
      ActorCupFilterOptionDto(value: 'F', count: 12),
    ],
  );
}
