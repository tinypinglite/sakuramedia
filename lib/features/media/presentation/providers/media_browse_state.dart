import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 「媒体管理」列表的完整 State：分页段 + 筛选 + 多选。
///
/// - [paged]：分页数据（items、currentPage、total、hasMore、loadMore 态）。
/// - [filter]：筛选值对象；UI 改后 Notifier.applyFilterState 触发 reload。
/// - [selectedIds]：多选集合；reload 会清空、`removeItemsByIds` 会同步剔除。
@immutable
class MediaBrowseState {
  MediaBrowseState({
    this.paged = const PagedListState<MediaListItemDto>(),
    this.filter = MediaBrowseFilterState.initial,
    Set<int> selectedIds = const <int>{},
  }) : selectedIds = Set<int>.unmodifiable(selectedIds);

  /// 首次 build 前的初始形态；filter 用 [MediaBrowseFilterState.initial]。
  static final MediaBrowseState initial = MediaBrowseState();

  final PagedListState<MediaListItemDto> paged;
  final MediaBrowseFilterState filter;
  final Set<int> selectedIds;

  int get selectionCount => selectedIds.length;

  bool isSelected(int id) => selectedIds.contains(id);

  /// 当前已加载页中「可批量操作」的条目是否已全部选中。
  ///
  /// 供「全选本页 ↔ 取消全选本页」同一个按钮切换语义使用；白名单与
  /// [isBulkSelectableRapidUploadStatus] 一致（`in_progress` / `unknown` 不参与）。
  bool get allLoadedSelected {
    var hasSelectable = false;
    for (final item in paged.items) {
      if (!isBulkSelectableRapidUploadStatus(item.lastRapidUploadStatus)) {
        continue;
      }
      hasSelectable = true;
      if (!selectedIds.contains(item.id)) {
        return false;
      }
    }
    return hasSelectable;
  }

  MediaBrowseState copyWith({
    PagedListState<MediaListItemDto>? paged,
    MediaBrowseFilterState? filter,
    Set<int>? selectedIds,
  }) {
    return MediaBrowseState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}
