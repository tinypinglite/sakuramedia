import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/multi_version_movie_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'multi_version_movies_provider.g.dart';

@Riverpod(retry: kNoAsyncNotifierRetry)
class MultiVersionMovies extends _$MultiVersionMovies
    with
        PagedAsyncNotifierMixin<
          PagedListState<MultiVersionMovieDto>,
          MultiVersionMovieDto
        > {
  @override
  int get pageSize => 20;
  @override
  String get initialLoadErrorText =>
      ref.read(appLocalizationsProvider).errorMultiVersionMovieLoadFailed;
  @override
  String get loadMoreErrorText =>
      ref.read(appLocalizationsProvider).errorLoadMoreMoviesFailed;
  @override
  PagedListState<MultiVersionMovieDto> pagedOf(
    PagedListState<MultiVersionMovieDto> state,
  ) => state;
  @override
  PagedListState<MultiVersionMovieDto> applyPaged(
    PagedListState<MultiVersionMovieDto> state,
    PagedListState<MultiVersionMovieDto> paged,
  ) => paged;
  @override
  Future<PaginatedResponseDto<MultiVersionMovieDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(mediaApiProvider)
      .getMultiVersionMovies(
        page: page,
        pageSize: pageSize,
        includeVr: includeVr,
        includeFc2: includeFc2,
        includeProcessed: includeProcessed,
      );
  @override
  Future<PagedListState<MultiVersionMovieDto>> build({
    bool includeVr = false,
    bool includeFc2 = false,
    bool includeProcessed = false,
  }) async {
    attachDisposeGuard();
    invalidateOnSignOut(ref);
    return loadInitialPage();
  }

  Future<String?>? _refreshRequest;
  bool _deleting = false;
  bool _processing = false;

  @override
  Future<String?> refresh() async {
    if (_deleting || _processing) return null;
    if (_refreshRequest != null) return _refreshRequest;
    _refreshRequest = super.refresh();
    try {
      return await _refreshRequest;
    } finally {
      _refreshRequest = null;
    }
  }

  Future<void> deleteVersion(MediaListItemDto item) async {
    if (_processing) return;
    // 切换 Tab 时也要等删除结果完成跨页同步。
    final link = ref.keepAlive();
    _deleting = true;
    try {
      // 先收完旧刷新，避免其在删除后回写过期列表。
      await _refreshRequest;
      if (isDisposed) return;
      await ref.read(mediaApiProvider).deleteMedia(mediaId: item.id);
      if (isDisposed) return;
      _applyDeletedMedia(item);
      await super.refresh();
      final movieNumber = item.movieNumber;
      if (!isDisposed &&
          movieNumber != null &&
          ref.exists(movieDetailProvider(movieNumber))) {
        await ref
            .read(movieDetailProvider(movieNumber).notifier)
            .refresh()
            .catchError((Object _) {
              // 删除已成功，详情刷新失败不应提示删除失败。
            });
      }
    } finally {
      _deleting = false;
      link.close();
    }
  }

  Future<void> markProcessed(MultiVersionMovieDto group) async {
    if (_processing || _deleting) return;
    final link = ref.keepAlive();
    _processing = true;
    try {
      await _refreshRequest;
      if (isDisposed) return;
      try {
        await ref
            .read(mediaApiProvider)
            .markMultiVersionProcessed(
              movieNumber: group.movieNumber,
              mediaIds: group.mediaItems.map((item) => item.id).toList(),
            );
      } on ApiException catch (error) {
        if (!isDisposed && error.error?.code == 'multi_version_changed') {
          await super.refresh();
        }
        rethrow;
      }
      if (isDisposed) return;
      _applyProcessedState(group, processed: true);
    } finally {
      _processing = false;
      link.close();
    }
  }

  Future<void> clearProcessed(MultiVersionMovieDto group) async {
    if (_processing || _deleting) return;
    final link = ref.keepAlive();
    _processing = true;
    try {
      await _refreshRequest;
      if (isDisposed) return;
      await ref
          .read(mediaApiProvider)
          .clearMultiVersionProcessed(movieNumber: group.movieNumber);
      if (isDisposed) return;
      _applyProcessedState(group, processed: false);
    } finally {
      _processing = false;
      link.close();
    }
  }

  void _applyProcessedState(
    MultiVersionMovieDto group, {
    required bool processed,
  }) {
    final current = state.value;
    if (current == null || isDisposed) return;
    invalidateInFlightLoadMore();
    var paged = pagedOf(current);
    if (!includeProcessed && processed) {
      paged = paged.removeWhere(
        (item) => item.movieNumber == group.movieNumber,
      );
    } else {
      paged = paged.patchWhere(
        (item) => item.movieNumber == group.movieNumber,
        (item) => item.copyWith(isProcessed: processed),
      );
    }
    if (paged.isLoadingMore) {
      paged = paged.copyWith(isLoadingMore: false);
    }
    state = AsyncData(applyPaged(current, paged));
  }

  void _applyDeletedMedia(MediaListItemDto item) {
    final current = state.value;
    if (current == null || isDisposed) return;
    invalidateInFlightLoadMore();
    var paged = pagedOf(current);
    if (paged.isLoadingMore || paged.loadMoreErrorMessage != null) {
      paged = paged.copyWith(isLoadingMore: false, loadMoreErrorMessage: null);
    }
    final groupIndex = paged.items.indexWhere(
      (group) => group.mediaItems.any((media) => media.id == item.id),
    );
    if (groupIndex < 0) {
      state = AsyncData(applyPaged(current, paged));
      return;
    }
    final group = paged.items[groupIndex];
    final remainingItems = group.mediaItems
        .where((media) => media.id != item.id)
        .toList(growable: false);
    if (remainingItems.length < 2) {
      paged = paged.removeWhere(
        (candidate) => candidate.movieNumber == group.movieNumber,
      );
    } else {
      final nextItems = List<MultiVersionMovieDto>.of(paged.items);
      nextItems[groupIndex] = group.copyWith(
        mediaCount: remainingItems.length,
        mediaItems: remainingItems,
        isProcessed: false,
      );
      paged = paged.copyWith(
        items: List<MultiVersionMovieDto>.unmodifiable(nextItems),
      );
    }
    state = AsyncData(applyPaged(current, paged));
  }
}
