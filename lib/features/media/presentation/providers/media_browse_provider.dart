import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'media_browse_provider.g.dart';

/// 「媒体管理」列表控制器（Riverpod）：分页拉取全局 `/media`，持有筛选与多选。
///
/// 筛选状态遵循项目主流约定：值对象 [MediaBrowseFilterState] 由 State 持有，
/// `fetchPage` 从共享筛选 mixin 的 [activeFilter] 读取参数；UI 改筛选时先同步
/// 写入 State 并清多选，再防抖刷新第一页。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class MediaBrowse extends _$MediaBrowse
    with
        PagedAsyncNotifierMixin<MediaBrowseState, MediaListItemDto>,
        FilterablePagedAsyncNotifierMixin<
          MediaBrowseState,
          MediaListItemDto,
          MediaBrowseFilterState
        > {
  @override
  MediaBrowseFilterState get initialFilter => MediaBrowseFilterState.initial;

  @override
  int get pageSize => 30;

  @override
  String get initialLoadErrorText => '媒体列表加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多媒体失败，请点击重试';

  @override
  PagedListState<MediaListItemDto> pagedOf(MediaBrowseState s) => s.paged;

  @override
  MediaBrowseState applyPaged(
    MediaBrowseState s,
    PagedListState<MediaListItemDto> paged,
  ) => s.copyWith(paged: paged);

  @override
  Future<PaginatedResponseDto<MediaListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    final filter = activeFilter;
    return ref
        .read(mediaApiProvider)
        .getMediaList(
          page: page,
          pageSize: pageSize,
          kind: mediaBrowseKindWire(filter.kind),
          libraryId: filter.libraryId,
          thumbnailGenerationState: filter.thumbnailGenerationState?.apiValue,
          sort: filter.sortWire,
        );
  }

  @override
  Future<MediaBrowseState> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return MediaBrowseState(paged: paged, filter: activeFilter);
  }

  @override
  MediaBrowseState applyFilterToState(
    MediaBrowseState state,
    MediaBrowseFilterState filter,
  ) => state.copyWith(filter: filter, selectedIds: const <int>{});

  void toggleSelection(int id) {
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.selectedIds);
    if (!next.remove(id)) next.add(id);
    state = AsyncData(current.copyWith(selectedIds: next));
  }

  void setSelected(int id, bool selected) {
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.selectedIds);
    final changed = selected ? next.add(id) : next.remove(id);
    if (changed) {
      state = AsyncData(current.copyWith(selectedIds: next));
    }
  }

  /// 全选 / 取消全选**当前已加载**的条目（非叠加所有页）。
  ///
  /// 已全选时再点即清空当前页，对应工具条「全选本页 ↔ 取消全选本页」同一按钮。
  void toggleSelectAllLoaded() {
    final current = state.value;
    if (current == null) return;
    final loadedIds = current.paged.items.map((item) => item.id).toList();
    if (loadedIds.isEmpty) {
      return;
    }
    final allSelected = current.allLoadedSelected;
    final next = Set<int>.of(current.selectedIds);
    if (allSelected) {
      next.removeAll(loadedIds);
    } else {
      next.addAll(loadedIds);
    }
    state = AsyncData(current.copyWith(selectedIds: next));
  }

  void clearSelection() {
    final current = state.value;
    if (current == null || current.selectedIds.isEmpty) return;
    state = AsyncData(current.copyWith(selectedIds: const <int>{}));
  }

  /// 删除成功后，把已从服务端移除的条目从本地列表移除。
  ///
  /// - 已在列表中的：移除条目 + 同步扣减 total + `hasMore` 重算；
  /// - 只在多选集合里的（当前列表看不到）：仅剔除多选。
  void removeItemsByIds(Iterable<int> ids) {
    final current = state.value;
    if (current == null) return;
    final targets = ids.toSet();
    if (targets.isEmpty) return;

    final beforeLength = current.paged.items.length;
    final nextItems = current.paged.items
        .where((item) => !targets.contains(item.id))
        .toList(growable: false);
    final removed = beforeLength - nextItems.length;

    final nextSelected = Set<int>.of(current.selectedIds)..removeAll(targets);
    final selectionChanged = nextSelected.length != current.selectedIds.length;

    if (removed <= 0) {
      if (selectionChanged) {
        state = AsyncData(current.copyWith(selectedIds: nextSelected));
      }
      return;
    }

    final nextTotal = (current.paged.total - removed).clamp(0, 1 << 30);
    final nextPaged = current.paged.copyWith(
      items: List<MediaListItemDto>.unmodifiable(nextItems),
      total: nextTotal.toInt(),
      hasMore: nextItems.length < nextTotal,
    );
    state = AsyncData(
      current.copyWith(paged: nextPaged, selectedIds: nextSelected),
    );
  }
}
