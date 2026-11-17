import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_filter.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 我的切片首页 State：分页段 + 当前筛选。
@immutable
class ClipsOverviewState {
  const ClipsOverviewState({
    this.paged = const PagedListState<MediaClipDto>(),
    this.filter = const ClipsFilter(),
  });

  final PagedListState<MediaClipDto> paged;
  final ClipsFilter filter;

  ClipsOverviewState copyWith({
    PagedListState<MediaClipDto>? paged,
    ClipsFilter? filter,
  }) {
    return ClipsOverviewState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
    );
  }
}
