import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'media_browse_provider.g.dart';

Duration? noMediaBrowseRetry(int retryCount, Object error) => null;

/// 「媒体管理」列表控制器（Riverpod）：分页拉取全局 `/media`，持有筛选与多选。
///
/// 筛选状态遵循项目主流约定：值对象 [MediaBrowseFilterState] 由 State 持有，
/// `fetchPage` 通过内部 [_activeFilter] 字段读取拼参数。UI 改完调 [applyFilterState]
/// 才 reload。多选独立于 filter，reload 会清空。
///
/// 迁移前对应：`MediaBrowseController extends PagedLoadController<MediaListItemDto>`。
@Riverpod(keepAlive: true, retry: noMediaBrowseRetry)
class MediaBrowse extends _$MediaBrowse
    with PagedAsyncNotifierMixin<MediaBrowseState, MediaListItemDto> {
  /// fetchPage 读取的筛选源。放在 Notifier 字段而不是 `state.value.filter`，
  /// 原因：`reload` 会先把 state 切成 `AsyncLoading`（state.value == null），
  /// 此时 fetchPage 若从 state 读会拿到 null → 默认筛选。用字段避免这个竞争。
  MediaBrowseFilterState _activeFilter = MediaBrowseFilterState.initial;

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
    final filter = _activeFilter;
    return ref
        .read(mediaApiProvider)
        .getMediaList(
          page: page,
          pageSize: pageSize,
          kind: mediaBrowseKindWire(filter.kind),
          libraryId: filter.libraryId,
          sort: filter.sortWire,
        );
  }

  @override
  Future<MediaBrowseState> build() async {
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return MediaBrowseState(paged: paged, filter: _activeFilter);
  }

  /// 应用新筛选状态；未变则短路。变化则清多选并强制 reload。
  Future<void> applyFilterState(MediaBrowseFilterState next) async {
    if (_activeFilter == next) return;
    _activeFilter = next;
    await reload(
      updateBaseState: (s) => s.copyWith(
        filter: next,
        selectedIds: const <int>{},
      ),
    );
  }

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

  /// 选中当前已加载页面里的全部（非叠加所有页）。
  void selectAllLoaded() {
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.selectedIds);
    var changed = false;
    for (final item in current.paged.items) {
      if (next.add(item.id)) changed = true;
    }
    if (changed) {
      state = AsyncData(current.copyWith(selectedIds: next));
    }
  }

  void clearSelection() {
    final current = state.value;
    if (current == null || current.selectedIds.isEmpty) return;
    state = AsyncData(current.copyWith(selectedIds: const <int>{}));
  }

  /// 秒传触发成功后，把已进入批次的条目从本地列表移除。
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
    final selectionChanged =
        nextSelected.length != current.selectedIds.length;

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
