import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 时刻页 State：分页段 + 排序/内容类型双维筛选。
@immutable
class MomentsState {
  const MomentsState({
    this.paged = const PagedListState<MomentListItem>(),
    this.filter = MomentsFilter.initial,
  });

  final PagedListState<MomentListItem> paged;
  final MomentsFilter filter;

  MomentsState copyWith({
    PagedListState<MomentListItem>? paged,
    MomentsFilter? filter,
  }) {
    return MomentsState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
    );
  }
}
