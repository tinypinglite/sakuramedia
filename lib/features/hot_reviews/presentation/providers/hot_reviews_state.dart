import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 热评页 State：分页段 + 当前周期筛选。
@immutable
class HotReviewsState {
  const HotReviewsState({
    this.paged = const PagedListState<HotReviewListItemDto>(),
    this.period = HotReviewPeriod.weekly,
  });

  final PagedListState<HotReviewListItemDto> paged;
  final HotReviewPeriod period;

  HotReviewsState copyWith({
    PagedListState<HotReviewListItemDto>? paged,
    HotReviewPeriod? period,
  }) {
    return HotReviewsState(
      paged: paged ?? this.paged,
      period: period ?? this.period,
    );
  }
}
