import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'invalid_media_provider.g.dart';

/// 「媒体维护」失效媒体列表（Riverpod）。删除成功后从列表移除并扣减 total。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class InvalidMedia extends _$InvalidMedia
    with PagedAsyncNotifierMixin<InvalidMediaState, InvalidMediaDto> {
  @override
  int get pageSize => 20;

  @override
  String get initialLoadErrorText => '失效媒体加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多失效媒体失败，请点击重试';

  @override
  PagedListState<InvalidMediaDto> pagedOf(InvalidMediaState s) => s.paged;

  @override
  InvalidMediaState applyPaged(
    InvalidMediaState s,
    PagedListState<InvalidMediaDto> paged,
  ) => s.copyWith(paged: paged);

  @override
  Future<PaginatedResponseDto<InvalidMediaDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(mediaApiProvider)
      .getInvalidMedia(page: page, pageSize: pageSize);

  @override
  Future<InvalidMediaState> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return InvalidMediaState(paged: paged);
  }

  Future<void> deleteInvalidMedia({required int mediaId}) async {
    final current = state.value;
    if (current == null) {
      throw StateError('media deletion requires loaded state');
    }
    if (current.deletingMediaId != null) {
      throw StateError('media deletion already running');
    }
    state = AsyncData(current.copyWith(deletingMediaId: mediaId));
    try {
      await ref.read(mediaApiProvider).deleteMedia(mediaId: mediaId);
      if (isDisposed) return;
      final now = state.value;
      if (now == null) return;
      state = AsyncData(_withMediaRemoved(now, mediaId));
    } catch (error) {
      if (!isDisposed) {
        final now = state.value;
        if (now != null) {
          state = AsyncData(now.copyWith(deletingMediaId: null));
        }
      }
      rethrow;
    } finally {
      final now = state.value;
      if (!isDisposed && now != null && now.deletingMediaId == mediaId) {
        state = AsyncData(now.copyWith(deletingMediaId: null));
      }
    }
  }

  InvalidMediaState _withMediaRemoved(InvalidMediaState current, int mediaId) {
    final beforeLength = current.paged.items.length;
    final nextItems = current.paged.items
        .where((item) => item.id != mediaId)
        .toList(growable: false);
    final removed = beforeLength - nextItems.length;
    final nextTotal = removed > 0 && current.paged.total > 0
        ? (current.paged.total - removed).clamp(0, 1 << 30).toInt()
        : current.paged.total;
    final nextPaged = current.paged.copyWith(
      items: List<InvalidMediaDto>.unmodifiable(nextItems),
      total: nextTotal,
      hasMore: nextItems.length < nextTotal,
    );
    return current.copyWith(paged: nextPaged, deletingMediaId: null);
  }
}
