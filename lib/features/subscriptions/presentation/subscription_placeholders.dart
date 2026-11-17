import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 订阅列表加载态占位数据：真实 DTO + [BoneMock] 文案，状态取中性的
/// 「待查」避免渲染下载/导入进度，供 `AppSkeletonizer` 渲染真实行。
List<MovieSubscriptionListItemDto> movieSubscriptionListItemPlaceholders({
  int count = 6,
}) {
  return List<MovieSubscriptionListItemDto>.generate(
    count,
    (index) => MovieSubscriptionListItemDto(
      movieId: -1 - index,
      movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
      title: BoneMock.words(3),
      status: MovieSubscriptionStatus.pending,
      coverImage: null,
      attemptCount: 0,
      attemptLimit: 3,
    ),
    growable: false,
  );
}
