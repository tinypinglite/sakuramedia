import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/duplicate_media_group_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'duplicate_media_provider.g.dart';

/// 重复媒体分组列表：JAV / PornBox 各自缓存一份分页结果。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class DuplicateMedia extends _$DuplicateMedia
    with
        PagedAsyncNotifierMixin<
          PagedListState<DuplicateMediaGroupDto>,
          DuplicateMediaGroupDto
        > {
  @override
  int get pageSize => 20;

  @override
  String get initialLoadErrorText => '重复媒体加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多重复媒体失败，请点击重试';

  @override
  PagedListState<DuplicateMediaGroupDto> pagedOf(
    PagedListState<DuplicateMediaGroupDto> state,
  ) => state;

  @override
  PagedListState<DuplicateMediaGroupDto> applyPaged(
    PagedListState<DuplicateMediaGroupDto> state,
    PagedListState<DuplicateMediaGroupDto> paged,
  ) => paged;

  @override
  Future<PaginatedResponseDto<DuplicateMediaGroupDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(mediaApiProvider)
      .getDuplicateMediaGroups(kind: kind.name, page: page, pageSize: pageSize);

  @override
  Future<PagedListState<DuplicateMediaGroupDto>> build(
    MediaListItemKind kind,
  ) async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    return loadInitialPage();
  }

  /// 删除成功后就地收紧重复组：剩余至少 2 项则保留组，否则移除整个组。
  Future<void> deleteDuplicateMedia({required int mediaId}) async {
    final current = state.value;
    if (current == null) {
      throw StateError('duplicate media deletion requires loaded state');
    }

    await ref.read(mediaApiProvider).deleteMedia(mediaId: mediaId);
    if (isDisposed) return;

    final now = state.value ?? current;
    final groupIndex = now.items.indexWhere(
      (group) => group.mediaItems.any((item) => item.id == mediaId),
    );
    if (groupIndex < 0) return;

    final group = now.items[groupIndex];
    final remainingItems = group.mediaItems
        .where((item) => item.id != mediaId)
        .toList(growable: false);
    final nextItems = List<DuplicateMediaGroupDto>.of(now.items);
    if (remainingItems.length < 2) {
      nextItems.removeAt(groupIndex);
      final nextTotal = (now.total - 1).clamp(0, 1 << 30).toInt();
      state = AsyncData(
        now.copyWith(
          items: List<DuplicateMediaGroupDto>.unmodifiable(nextItems),
          total: nextTotal,
          hasMore: nextItems.length < nextTotal,
        ),
      );
      return;
    }

    nextItems[groupIndex] = group.copyWith(
      mediaCount: remainingItems.length,
      mediaItems: remainingItems,
    );
    state = AsyncData(
      now.copyWith(items: List<DuplicateMediaGroupDto>.unmodifiable(nextItems)),
    );
  }
}
