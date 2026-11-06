import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 「媒体管理」列表的远端数据 State：分页段 + 筛选。
///
/// - [paged]：分页数据（items、currentPage、total、hasMore、loadMore 态）。
/// - [filter]：筛选值对象；UI 改后 Notifier.applyFilterState 触发 reload。
@immutable
class MediaBrowseState {
  MediaBrowseState({
    this.paged = const PagedListState<MediaListItemDto>(),
    this.filter = MediaBrowseFilterState.initial,
  });

  /// 首次 build 前的初始形态；filter 用 [MediaBrowseFilterState.initial]。
  static final MediaBrowseState initial = MediaBrowseState();

  final PagedListState<MediaListItemDto> paged;
  final MediaBrowseFilterState filter;

  MediaBrowseState copyWith({
    PagedListState<MediaListItemDto>? paged,
    MediaBrowseFilterState? filter,
  }) {
    return MediaBrowseState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
    );
  }
}
