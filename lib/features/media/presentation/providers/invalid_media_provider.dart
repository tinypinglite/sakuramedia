import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/presentation/actions/media_video_mutation_report.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';

part 'invalid_media_provider.g.dart';

/// 「媒体维护」失效媒体列表（Riverpod）。删除成功后从列表移除并扣减 total。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class InvalidMedia extends _$InvalidMedia
    with PagedAsyncNotifierMixin<InvalidMediaState, InvalidMediaDto> {
  @override
  int get pageSize => 20;

  @override
  String get initialLoadErrorText =>
      ref.read(appLocalizationsProvider).errorInvalidMediaLoadFailed;

  @override
  String get loadMoreErrorText =>
      ref.read(appLocalizationsProvider).errorLoadMoreInvalidMediaFailed;

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
    final items = current.paged.items;
    final deletedIndex = items.indexWhere((item) => item.id == mediaId);
    final videoItemId = deletedIndex >= 0
        ? items[deletedIndex].videoItemId
        : null;
    state = AsyncData(current.copyWith(deletingMediaId: mediaId));
    try {
      await ref.read(mediaApiProvider).deleteMedia(mediaId: mediaId);
      if (isDisposed) return;
      // 非 JAV 媒体删除会同步删除视频条目并级联清理合集成员，通知 videos 域就地补丁。
      reportDeletedVideoItem(
        videoItemId,
        ref.read(videoMutationEventsProvider.notifier).reportDeleted,
      );
      final now = state.value;
      if (now == null) return;
      state = AsyncData(_withMediaRemoved(now, mediaId));
      await refresh();
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
    invalidateInFlightLoadMore();
    var paged = current.paged;
    if (paged.isLoadingMore || paged.loadMoreErrorMessage != null) {
      paged = paged.copyWith(isLoadingMore: false, loadMoreErrorMessage: null);
    }
    final beforeLength = paged.items.length;
    final nextItems = paged.items
        .where((item) => item.id != mediaId)
        .toList(growable: false);
    final removed = beforeLength - nextItems.length;
    final nextTotal = removed > 0 && paged.total > 0
        ? (paged.total - removed).clamp(0, 1 << 30).toInt()
        : paged.total;
    final nextPaged = paged.copyWith(
      items: List<InvalidMediaDto>.unmodifiable(nextItems),
      total: nextTotal,
      hasMore: nextItems.length < nextTotal,
    );
    return current.copyWith(paged: nextPaged, deletingMediaId: null);
  }
}
