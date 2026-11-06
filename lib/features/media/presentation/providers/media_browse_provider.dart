import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'media_browse_provider.g.dart';

/// 「媒体管理」列表控制器（Riverpod）：分页拉取全局 `/media`，持有筛选。
///
/// 筛选状态遵循项目主流约定：值对象 [MediaBrowseFilterState] 由 State 持有，
/// `fetchPage` 从共享筛选 mixin 的 [activeFilter] 读取参数；UI 改筛选时先同步
/// 写入 State 并退出多选，再防抖刷新第一页。
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
  String get initialLoadErrorText =>
      ref.read(appLocalizationsProvider).errorMediaListLoadFailed;

  @override
  String get loadMoreErrorText =>
      ref.read(appLocalizationsProvider).errorLoadMoreMediaFailed;

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
          search: filter.trimmedSearch,
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
  ) => state.copyWith(filter: filter);

  /// 删除成功后，把已从服务端移除的条目从本地列表移除。
  ///
  /// - 已在列表中的：移除条目 + 同步扣减 total + `hasMore` 重算。
  void removeItemsByIds(Iterable<int> ids) {
    var current = state.value;
    if (current == null) return;
    final targets = ids.toSet();
    if (targets.isEmpty) return;
    invalidateInFlightLoadMore();
    if (current.paged.isLoadingMore ||
        current.paged.loadMoreErrorMessage != null) {
      current = current.copyWith(
        paged: current.paged.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: null,
        ),
      );
      state = AsyncData(current);
    }

    final beforeLength = current.paged.items.length;
    final nextItems = current.paged.items
        .where((item) => !targets.contains(item.id))
        .toList(growable: false);
    final removed = beforeLength - nextItems.length;

    if (removed <= 0) return;

    final nextTotal = (current.paged.total - removed).clamp(0, 1 << 30);
    final nextPaged = current.paged.copyWith(
      items: List<MediaListItemDto>.unmodifiable(nextItems),
      total: nextTotal.toInt(),
      hasMore: nextItems.length < nextTotal,
    );
    state = AsyncData(current.copyWith(paged: nextPaged));
  }

  Future<void> deleteMediaFile(MediaListItemDto item) async {
    await ref.read(mediaApiProvider).deleteMedia(mediaId: item.id);
    if (isDisposed) return;
    removeItemsByIds([item.id]);
    await refresh();
  }

  void applyTagAssignment({
    required int mediaId,
    required List<MediaTagRefDto> tags,
    required bool isManuallyManaged,
  }) {
    final current = state.value;
    if (current == null) return;
    final index = current.paged.items.indexWhere((item) => item.id == mediaId);
    if (index < 0) return;
    final items = List<MediaListItemDto>.from(current.paged.items);
    final item = items[index];
    items[index] = MediaListItemDto(
      id: item.id,
      kind: item.kind,
      movieNumber: item.movieNumber,
      videoItemId: item.videoItemId,
      title: item.title,
      coverImage: item.coverImage,
      thinCoverImage: item.thinCoverImage,
      libraryId: item.libraryId,
      libraryName: item.libraryName,
      fileName: item.fileName,
      fileSizeBytes: item.fileSizeBytes,
      durationSeconds: item.durationSeconds,
      resolution: item.resolution,
      technicalInfo: item.technicalInfo,
      valid: item.valid,
      heat: item.heat,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      thumbnailGenerationState: item.thumbnailGenerationState,
      thumbnailLastErrorCode: item.thumbnailLastErrorCode,
      collections: item.collections,
      tags: List<MediaTagRefDto>.unmodifiable(tags),
      isMediaTagsManuallyManaged: isManuallyManaged,
    );
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          items: List<MediaListItemDto>.unmodifiable(items),
        ),
      ),
    );
  }
}
